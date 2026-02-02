import Foundation
import CoreLocation
import Combine

final class LocationService: NSObject, ObservableObject {
    @Published var currentLocation: CLLocation?
    @Published var currentSpeed: Double = 0 // m/s
    @Published var currentAltitude: Double = 0
    @Published var currentCourse: Double = -1
    @Published var currentHeading: Double = 0 // degrees from true north
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isTracking = false
    @Published var isSimulating = false
    @Published var showJoystickOverlay = false

    let locationSubject = PassthroughSubject<CLLocation, Never>()

    private let locationManager = CLLocationManager()
    private var kalmanFilter: KalmanFilter?

    private let maxAccuracy: Double = 100.0 // meters - increased from 50 to accept more points
    private let maxSpeedMs: Double = 83.3 // ~300 km/h
    private let minSpeedThreshold: Double = 1.5 // m/s (~5.4 km/h) - speeds below this are considered stationary
    private let maxLocationAge: TimeInterval = 10.0 // seconds - reject locations older than 10 seconds

    // Simulation
    private var simulatedCoordinate: CLLocationCoordinate2D?
    private var simulationTimer: Timer?
    private var joystickDirection: CGVector = .zero // normalized
    private let simulationSpeedMps: Double = 15.0 // ~54 km/h simulated movement

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = kCLDistanceFilterNone // Update on every location change for smooth tracking
        locationManager.activityType = .automotiveNavigation
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.showsBackgroundLocationIndicator = true
        locationManager.headingFilter = 1 // Update every 1 degree for smoother heading
    }

    func requestPermission() {
        locationManager.requestAlwaysAuthorization()
    }

    func startTracking() {
        kalmanFilter = KalmanFilter()
        if !isSimulating {
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        }
        isTracking = true
    }

    func stopTracking() {
        if !isSimulating {
            locationManager.stopUpdatingLocation()
            locationManager.stopUpdatingHeading()
        }
        isTracking = false
        kalmanFilter = nil
    }

    func startHeadingUpdates() {
        locationManager.startUpdatingHeading()
    }

    /// Start passive location updates for display (arrow on map) without recording
    func startPassiveUpdates() {
        if !isSimulating {
            locationManager.startUpdatingLocation()
            locationManager.startUpdatingHeading()
        }
    }

    // MARK: - Simulation

    func startSimulation() {
        // Grab real location BEFORE switching to simulation
        let startCoordinate = currentLocation?.coordinate

        isSimulating = true
        showJoystickOverlay = true
        locationManager.stopUpdatingLocation()

        // Start from real location, fallback to last known or Moscow
        simulatedCoordinate = startCoordinate
            ?? CLLocationCoordinate2D(latitude: 55.7558, longitude: 37.6173)

        simulationTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.tickSimulation()
        }
        // Send initial position
        tickSimulation()
    }

    func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        isSimulating = false
        showJoystickOverlay = false
        simulatedCoordinate = nil
        joystickDirection = .zero
    }

    func updateJoystick(_ direction: CGVector) {
        joystickDirection = direction
    }

    private func tickSimulation() {
        guard var coord = simulatedCoordinate else { return }

        let dt = 0.5
        let metersPerDegreeLat = 111_320.0
        let metersPerDegreeLng = 111_320.0 * cos(coord.latitude * .pi / 180)

        let dx = joystickDirection.dx * simulationSpeedMps * dt
        let dy = joystickDirection.dy * simulationSpeedMps * dt

        coord.longitude += dx / metersPerDegreeLng
        coord.latitude += dy / metersPerDegreeLat
        simulatedCoordinate = coord

        let speed = sqrt(dx * dx + dy * dy) / dt
        let course = atan2(dx, dy) * 180 / .pi
        let normalizedCourse = course >= 0 ? course : course + 360

        // Update heading from joystick direction
        if speed > 0.5 {
            currentHeading = normalizedCourse
        }

        let location = CLLocation(
            coordinate: coord,
            altitude: 150,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            course: normalizedCourse,
            speed: speed,
            timestamp: Date()
        )

        processLocation(location, skipFilter: true)
    }

    // MARK: - Processing

    private func processLocation(_ location: CLLocation, skipFilter: Bool = false) {
        // For real-time tracking, skip Kalman filter to minimize latency
        // Kalman filter can add delay and cause track lag
        // Only use raw location for immediate updates
        let filtered: CLLocation
        if skipFilter {
            filtered = location
        } else {
            // Skip Kalman filter during active tracking to prevent lag
            // The filter is mainly useful for display smoothing, not for track recording
            filtered = location
        }

        // Update @Published properties (must be on main thread for SwiftUI)
        // LocationService is typically created on main thread, so this should be safe
        // But we ensure main thread for safety
        if Thread.isMainThread {
            updateLocationProperties(filtered)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.updateLocationProperties(filtered)
            }
        }
    }
    
    private func updateLocationProperties(_ location: CLLocation) {
        currentLocation = location
        
        // Filter out low speeds (GPS noise when stationary)
        // If speed is below threshold, treat as stationary (0 m/s)
        let rawSpeed = max(0, location.speed)
        currentSpeed = rawSpeed < minSpeedThreshold ? 0 : rawSpeed
        
        currentAltitude = location.altitude
        currentCourse = location.course

        // Send location immediately - no debounce/throttle
        // This will be received on main thread via .receive(on:) in ViewModel
        locationSubject.send(location)
    }

    private func isValidLocation(_ location: CLLocation) -> Bool {
        // Reject invalid accuracy values
        guard location.horizontalAccuracy >= 0 else {
            return false
        }
        
        // Reject locations with very poor accuracy (>100m)
        guard location.horizontalAccuracy <= maxAccuracy else {
            return false
        }
        
        // Reject locations that are too old (stale GPS data)
        let age = -location.timestamp.timeIntervalSinceNow
        guard age < maxLocationAge else {
            return false
        }
        
        // Reject unrealistic speeds
        let speed = max(0, location.speed)
        if speed > maxSpeedMs {
            return false
        }
        
        return true
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !isSimulating else { return }
        
        // DEBUG: Log received locations
        #if DEBUG
        print("📍 Received \(locations.count) locations")
        for (index, loc) in locations.enumerated() {
            let age = -loc.timestamp.timeIntervalSinceNow
            print("  [\(index)] accuracy: \(String(format: "%.1f", loc.horizontalAccuracy))m, age: \(String(format: "%.2f", age))s, speed: \(String(format: "%.1f", loc.speed * 3.6))km/h")
        }
        #endif
        
        // Process ALL locations in the array, not just the last one
        for location in locations {
            guard isValidLocation(location) else { 
                #if DEBUG
                print("  ⚠️ Rejected location: accuracy=\(String(format: "%.1f", location.horizontalAccuracy))m, age=\(String(format: "%.2f", -location.timestamp.timeIntervalSinceNow))s")
                #endif
                continue 
            }
            processLocation(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard !isSimulating else { return }
        let heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        currentHeading = heading
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

// MARK: - Simple Kalman Filter for GPS smoothing
private class KalmanFilter {
    private var lat: Double = 0
    private var lng: Double = 0
    private var variance: Double = -1
    private let minAccuracy: Double = 1.0

    func process(location: CLLocation) -> CLLocation {
        let accuracy = max(location.horizontalAccuracy, minAccuracy)

        if variance < 0 {
            lat = location.coordinate.latitude
            lng = location.coordinate.longitude
            variance = accuracy * accuracy
        } else {
            let k = variance / (variance + accuracy * accuracy)
            lat += k * (location.coordinate.latitude - lat)
            lng += k * (location.coordinate.longitude - lng)
            variance *= (1 - k)
        }

        return CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
            altitude: location.altitude,
            horizontalAccuracy: sqrt(variance),
            verticalAccuracy: location.verticalAccuracy,
            course: location.course,
            speed: location.speed,
            timestamp: location.timestamp
        )
    }
}
