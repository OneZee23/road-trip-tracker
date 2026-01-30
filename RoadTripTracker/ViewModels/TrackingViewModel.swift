import SwiftUI
import Combine
import MapKit

final class TrackingViewModel: ObservableObject {
    @Published var speed: Double = 0 // km/h
    @Published var altitude: Double = 0 // meters
    @Published var distance: Double = 0 // km
    @Published var duration: String = "00:00"
    @Published var isRecording = false
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @Published var isFollowingUser = true
    @Published var heading: Double = 0 // raw degrees from device
    @Published var mapHeading: Double = 0 // raw map camera rotation
    @Published var userCoordinate: CLLocationCoordinate2D? // always-updated position for arrow

    // Continuous (unwrapped) angles — never jump across 360/0 boundary
    @Published var continuousHeading: Double = 0
    @Published var continuousMapHeading: Double = 0
    private var lastRawHeading: Double = 0
    private var lastRawMapHeading: Double = 0
    private var headingInitialized = false
    private var mapHeadingInitialized = false

    var compassHeading: Double {
        isFollowingUser ? continuousHeading : continuousMapHeading
    }

    let locationService: LocationService
    let tripManager: TripManager
    private var cancellables = Set<AnyCancellable>()
    private var timer: AnyCancellable?

    init() {
        self.locationService = LocationService()
        self.tripManager = TripManager(locationService: locationService)
        setupBindings()
    }

    func requestLocationPermission() {
        locationService.requestPermission()
        // Always start location + heading so arrow is visible immediately
        locationService.startPassiveUpdates()
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func centerOnUser() {
        isFollowingUser = true
        if let loc = locationService.currentLocation {
            withAnimation(.easeInOut(duration: 0.4)) {
                cameraPosition = .camera(MapCamera(
                    centerCoordinate: loc.coordinate,
                    distance: 1000,
                    heading: heading,
                    pitch: 0
                ))
            }
        } else {
            withAnimation(.easeInOut(duration: 0.4)) {
                cameraPosition = .userLocation(fallback: .automatic)
            }
        }
    }

    func resetMapNorth() {
        isFollowingUser = true
        withAnimation(.easeInOut(duration: 0.4)) {
            if let loc = locationService.currentLocation {
                cameraPosition = .camera(MapCamera(
                    centerCoordinate: loc.coordinate,
                    distance: 1000,
                    heading: 0,
                    pitch: 0
                ))
            }
        }
        let turns = round(continuousMapHeading / 360)
        continuousMapHeading = turns * 360
    }

    func updateMapHeading(_ rawHeading: Double) {
        if !mapHeadingInitialized {
            continuousMapHeading = rawHeading
            lastRawMapHeading = rawHeading
            mapHeadingInitialized = true
            return
        }
        var delta = rawHeading - lastRawMapHeading
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        continuousMapHeading += delta
        lastRawMapHeading = rawHeading
        mapHeading = rawHeading
    }

    private func updateHeading(_ rawHeading: Double) {
        if !headingInitialized {
            continuousHeading = rawHeading
            lastRawHeading = rawHeading
            headingInitialized = true
            return
        }
        var delta = rawHeading - lastRawHeading
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        continuousHeading += delta
        lastRawHeading = rawHeading
        heading = rawHeading
    }

    private func startRecording() {
        routeCoordinates = []
        tripManager.startTrip()
        isRecording = true
        isFollowingUser = true

        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateDuration()
            }
    }

    private func stopRecording() {
        tripManager.stopTrip()
        isRecording = false
        timer?.cancel()
        timer = nil
    }

    private func setupBindings() {
        locationService.$currentSpeed
            .receive(on: DispatchQueue.main)
            .map { $0 * 3.6 }
            .assign(to: &$speed)

        locationService.$currentAltitude
            .receive(on: DispatchQueue.main)
            .assign(to: &$altitude)

        locationService.$currentHeading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] raw in
                self?.updateHeading(raw)
            }
            .store(in: &cancellables)

        tripManager.$activeTrip
            .receive(on: DispatchQueue.main)
            .compactMap { $0?.distanceKm }
            .assign(to: &$distance)

        locationService.locationSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                guard let self else { return }

                // Always update arrow position
                withAnimation(.easeOut(duration: 0.8)) {
                    self.userCoordinate = location.coordinate
                }

                if self.isRecording {
                    self.routeCoordinates.append(location.coordinate)
                }

                // Smooth camera follow
                if self.isFollowingUser {
                    withAnimation(.easeOut(duration: 0.8)) {
                        self.cameraPosition = .camera(MapCamera(
                            centerCoordinate: location.coordinate,
                            distance: 1000,
                            heading: self.heading,
                            pitch: 0
                        ))
                    }
                }
            }
            .store(in: &cancellables)

        tripManager.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
    }

    private func updateDuration() {
        guard let trip = tripManager.activeTrip else {
            duration = "00:00"
            return
        }
        duration = trip.formattedDuration
    }
}
