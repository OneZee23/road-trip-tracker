import Foundation
import CoreLocation
import Combine

enum TrackingMode {
    case real       // Реальный GPS
    case simulated  // Dev-режим с джойстиком
}

/// Менеджер режимов отслеживания (GPS/Симуляция)
class LocationManager: ObservableObject {
    // Публичный интерфейс — единый для обоих режимов
    @Published private(set) var currentLocation: LocationUpdate?
    @Published private(set) var isTracking = false
    
    // Текущий режим
    @Published private(set) var mode: TrackingMode = .real
    @Published var isDeveloperMode: Bool = false
    
    // Провайдеры
    private var realGPS = RealGPSProvider()
    private var simulatedProvider: SimulatedLocationProvider?
    
    // Подписки
    private var cancellables = Set<AnyCancellable>()
    private var activeProviderCancellable: AnyCancellable?
    
    // Джойстик (только для dev-режима)
    var joystickInput: CGPoint = .zero {
        didSet {
            simulatedProvider?.joystickInput = joystickInput
        }
    }
    
    init() {
        // Всегда слушаем реальный GPS для получения начальной позиции
        realGPS.locationPublisher
            .sink { [weak self] update in
                // Обновляем только если не в режиме симуляции
                if self?.mode == .real {
                    self?.currentLocation = update
                }
            }
            .store(in: &cancellables)
    }
    
    /// Запустить реальный GPS (для получения начальной позиции)
    func startRealGPS() {
        realGPS.start()
    }
    
    /// Остановить реальный GPS
    func stopRealGPS() {
        realGPS.stop()
    }
    
    /// Начать запись трека
    func startTracking() {
        if isDeveloperMode {
            startSimulatedTracking()
        } else {
            startRealTracking()
        }
        isTracking = true
    }
    
    /// Остановить запись трека
    func stopTracking() {
        activeProviderCancellable?.cancel()
        activeProviderCancellable = nil
        
        if mode == .simulated {
            simulatedProvider?.stop()
            simulatedProvider = nil
        }
        
        mode = .real
        isTracking = false
    }
    
    private func startRealTracking() {
        mode = .real
        realGPS.start()
        
        activeProviderCancellable = realGPS.locationPublisher
            .sink { [weak self] update in
                self?.currentLocation = update
            }
    }
    
    private func startSimulatedTracking() {
        mode = .simulated
        
        // Берём текущую реальную позицию как стартовую
        let startCoordinate = currentLocation?.coordinate ?? CLLocationCoordinate2D(
            latitude: 45.0355, // fallback: Краснодар
            longitude: 38.9753
        )
        
        // Создаём симулированный провайдер
        let provider = SimulatedLocationProvider(startingFrom: startCoordinate)
        simulatedProvider = provider
        
        // Подписываемся на обновления симуляции
        activeProviderCancellable = provider.locationPublisher
            .sink { [weak self] update in
                self?.currentLocation = update
            }
        
        provider.start()
        
        // Останавливаем реальный GPS для экономии батареи
        realGPS.stop()
    }
}
