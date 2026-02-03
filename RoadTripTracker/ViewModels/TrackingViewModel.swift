import SwiftUI
import Combine
import MapKit

enum LocationTrackingMode {
    case none           // Обычный режим - камера не следует
    case centered       // Зафиксировано на пользователе (первое нажатие)
    case follow         // Режим следования (второе нажатие)
    
    /// SF Symbol иконка для текущего состояния
    var iconName: String {
        switch self {
        case .none:
            return "location"
        case .centered:
            return "location.fill"
        case .follow:
            return "location.north.line.fill"
        }
    }
    
    /// Цвет иконки
    var iconColor: Color {
        switch self {
        case .none:
            return .secondary
        case .centered, .follow:
            return .blue
        }
    }
    
    /// Активна ли кнопка (неактивна только в режиме none)
    var isActive: Bool {
        self != .none
    }
}

final class TrackingViewModel: ObservableObject {
    @Published var speed: Double = 0 // km/h
    @Published var altitude: Double = 0 // meters
    @Published var distance: Double = 0 // km
    @Published var duration: String = "00:00"
    @Published var isRecording = false
    @Published var routeCoordinates: [CLLocationCoordinate2D] = [] // Для обратной совместимости
    @Published var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @Published var locationMode: LocationTrackingMode = .none
    @Published var heading: Double = 0 // raw degrees from device
    @Published var mapHeading: Double = 0 // raw map camera rotation
    @Published var userCoordinate: CLLocationCoordinate2D? // current user position for map marker
    @Published var showLocationAlert = false
    
    // Новая архитектура
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var trackManager: SmoothTrackManager
    let tripManager: TripManager
    
    // Для обратной совместимости
    let locationService: LocationService
    
    // Computed property for backward compatibility
    var isFollowingUser: Bool {
        locationMode == .follow
    }
    
    /// Проверяет, доступна ли геолокация для отслеживания
    var isLocationTrackingEnabled: Bool {
        let hasLocation = locationManager.currentLocation != nil
        return hasLocation
    }
    
    // Track if camera update is programmatic (not user interaction)
    private var isProgrammaticCameraUpdate = false
    private var programmaticUpdateWorkItem: DispatchWorkItem?
    
    // Сохранение текущего zoom пользователя
    private var savedCameraDistance: Double = 1000 // метры, значение по умолчанию

    // Continuous (unwrapped) angles — never jump across 360/0 boundary
    @Published var continuousHeading: Double = 0
    @Published var continuousMapHeading: Double = 0
    private var lastRawHeading: Double = 0
    private var lastRawMapHeading: Double = 0
    private var headingInitialized = false
    private var mapHeadingInitialized = false

    private var cancellables = Set<AnyCancellable>()
    private var timer: AnyCancellable?

    init() {
        // Создаём LocationService для обратной совместимости
        self.locationService = LocationService()
        
        // Инициализируем новую архитектуру
        let manager = LocationManager()
        self.locationManager = manager
        self.trackManager = SmoothTrackManager()
        self.tripManager = TripManager(locationManager: manager)
        
        setupBindings()
    }

    func requestLocationPermission() {
        locationService.requestPermission()
        // Always start location + heading so arrow is visible immediately
        locationService.startPassiveUpdates()
        // Также запускаем новый LocationManager
        locationManager.startRealGPS()
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    func toggleLocationMode() {
        // Проверка доступности геолокации
        guard isLocationTrackingEnabled else {
            showLocationAlert = true
            return
        }
        
        // Cancel any pending reset of the flag
        programmaticUpdateWorkItem?.cancel()
        
        switch locationMode {
        case .none:
            // Первое нажатие - центрируем на пользователе
            locationMode = .centered
            isProgrammaticCameraUpdate = true
            centerCameraOnUser()
            
        case .centered:
            // Второе нажатие - включаем режим следования
            locationMode = .follow
            isProgrammaticCameraUpdate = true
            // Камера уже центрирована, просто включаем автоматическое следование
            
        case .follow:
            // Третье нажатие - выключаем режим следования
            locationMode = .none
            isProgrammaticCameraUpdate = false
        }
    }
    
    private func centerCameraOnUser() {
        if let loc = locationManager.currentLocation {
            withAnimation(.easeInOut(duration: 0.3)) {
                cameraPosition = .camera(MapCamera(
                    centerCoordinate: loc.coordinate,
                    distance: savedCameraDistance,
                    heading: heading,
                    pitch: 0
                ))
            }
        } else if let loc = locationService.currentLocation {
            withAnimation(.easeInOut(duration: 0.3)) {
                cameraPosition = .camera(MapCamera(
                    centerCoordinate: loc.coordinate,
                    distance: savedCameraDistance,
                    heading: heading,
                    pitch: 0
                ))
            }
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                cameraPosition = .userLocation(fallback: .automatic)
            }
        }
    }
    
    func handleMapCameraChange(_ context: MapCameraUpdateContext) {
        // Сохраняем текущий zoom пользователя (только если это не программное обновление)
        if !isProgrammaticCameraUpdate {
            savedCameraDistance = context.camera.distance
            // This was a manual user interaction - reset to none mode
            if locationMode != .none {
                locationMode = .none
            }
        }
        // If isProgrammaticCameraUpdate is true, we keep the mode as is
        updateMapHeading(context.camera.heading)
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
        trackManager.reset()
        trackManager.startAnimation()
        tripManager.startTrip()
        isRecording = true
        // Enable following mode when recording starts
        if locationMode == .none {
            locationMode = .follow
            isProgrammaticCameraUpdate = true
        }

        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateDuration()
            }
    }

    private func stopRecording() {
        tripManager.stopTrip()
        trackManager.stopAnimation()
        isRecording = false
        timer?.cancel()
        timer = nil
    }

    private func setupBindings() {
        // Подписка на обновления LocationManager
        locationManager.$currentLocation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] update in
                guard let self = self, let update = update else { return }
                
                // Update user position marker
                self.userCoordinate = update.coordinate
                
                // Update speed and altitude
                self.speed = update.speed * 3.6 // km/h
                self.altitude = 0 // LocationUpdate не содержит altitude, используем 0
                
                // Update heading
                self.updateHeading(update.course)
                
                // Add point to smooth track manager
                if self.isRecording {
                    self.trackManager.addPoint(update.coordinate)
                    // Также обновляем routeCoordinates для обратной совместимости
                    self.routeCoordinates.append(update.coordinate)
                }
                
                // Smooth camera follow - only in follow mode
                if self.locationMode == .follow {
                    // Cancel any pending reset
                    self.programmaticUpdateWorkItem?.cancel()
                    
                    self.isProgrammaticCameraUpdate = true
                    withAnimation(.easeOut(duration: 0.8)) {
                        self.cameraPosition = .camera(MapCamera(
                            centerCoordinate: update.coordinate,
                            distance: self.savedCameraDistance,
                            heading: self.heading,
                            pitch: 0
                        ))
                    }
                    // Reset flag after animation (with buffer for callbacks)
                    let workItem = DispatchWorkItem { [weak self] in
                        guard let self = self else { return }
                        if self.locationMode == .follow {
                            self.isProgrammaticCameraUpdate = false
                        }
                    }
                    self.programmaticUpdateWorkItem = workItem
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: workItem)
                }
            }
            .store(in: &cancellables)
        
        // Также слушаем старый LocationService для обратной совместимости
        locationService.$currentSpeed
            .receive(on: DispatchQueue.main)
            .map { $0 * 3.6 }
            .sink { [weak self] speed in
                // Используем только если LocationManager не дал значение
                if self?.locationManager.currentLocation == nil {
                    self?.speed = speed
                }
            }
            .store(in: &cancellables)

        locationService.$currentAltitude
            .receive(on: DispatchQueue.main)
            .sink { [weak self] altitude in
                if self?.locationManager.currentLocation == nil {
                    self?.altitude = altitude
                }
            }
            .store(in: &cancellables)

        locationService.$currentHeading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] raw in
                if self?.locationManager.currentLocation == nil {
                    self?.updateHeading(raw)
                }
            }
            .store(in: &cancellables)

        tripManager.$activeTrip
            .receive(on: DispatchQueue.main)
            .compactMap { $0?.distanceKm }
            .assign(to: &$distance)

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
