import Foundation
import CoreData
import Combine
import CoreLocation

final class TripManager: ObservableObject {
    @Published var activeTrip: Trip?
    @Published var isRecording = false

    private let locationService: LocationService
    private let persistenceController: PersistenceController
    private var cancellables = Set<AnyCancellable>()
    private var activeTripEntity: TripEntity?
    private var lastLocation: CLLocation?

    init(locationService: LocationService, persistenceController: PersistenceController = .shared) {
        self.locationService = locationService
        self.persistenceController = persistenceController

        locationService.locationSubject
            .sink { [weak self] location in
                self?.handleNewLocation(location)
            }
            .store(in: &cancellables)
    }

    func startTrip() {
        let context = persistenceController.container.viewContext
        let entity = TripEntity(context: context)
        entity.id = UUID()
        entity.startDate = Date()
        entity.distance = 0
        entity.maxSpeed = 0
        entity.averageSpeed = 0
        persistenceController.save()

        activeTripEntity = entity
        activeTrip = Trip(
            id: entity.id!,
            startDate: entity.startDate!
        )
        isRecording = true
        lastLocation = nil

        locationService.startTracking()
    }

    func stopTrip() {
        locationService.stopTracking()
        isRecording = false

        guard let entity = activeTripEntity else { return }
        entity.endDate = Date()
        updateEntityStats(entity)
        persistenceController.save()

        activeTrip = nil
        activeTripEntity = nil
        lastLocation = nil
    }

    func fetchTrips() -> [Trip] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<TripEntity> = TripEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)]

        guard let entities = try? context.fetch(request) else { return [] }
        return entities.compactMap { tripFromEntity($0) }
    }

    func deleteTrip(id: UUID) {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<TripEntity> = TripEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        if let entity = try? context.fetch(request).first {
            context.delete(entity)
            persistenceController.save()
        }
    }

    func tripDetail(id: UUID) -> Trip? {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<TripEntity> = TripEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        guard let entity = try? context.fetch(request).first else { return nil }
        return tripFromEntity(entity)
    }

    // MARK: - Private

    private func handleNewLocation(_ location: CLLocation) {
        guard isRecording, let entity = activeTripEntity else { return }

        let context = persistenceController.container.viewContext
        let point = TrackPointEntity(context: context)
        point.id = UUID()
        point.latitude = location.coordinate.latitude
        point.longitude = location.coordinate.longitude
        point.altitude = location.altitude
        point.speed = max(0, location.speed)
        point.course = location.course
        point.horizontalAccuracy = location.horizontalAccuracy
        point.timestamp = location.timestamp
        point.trip = entity

        // Update distance
        if let last = lastLocation {
            let delta = location.distance(from: last)
            if delta < 1000 { // ignore jumps > 1km
                entity.distance += delta
            }
        }
        lastLocation = location

        // Update speeds
        let speed = max(0, location.speed)
        if speed > entity.maxSpeed {
            entity.maxSpeed = speed
        }

        // Calculate average speed from distance/time
        let elapsed = Date().timeIntervalSince(entity.startDate!)
        if elapsed > 0 {
            entity.averageSpeed = entity.distance / elapsed
        }

        // Update published trip immediately
        // This doesn't block track rendering which uses routeCoordinates in ViewModel
        activeTrip = Trip(
            id: entity.id!,
            startDate: entity.startDate!,
            distance: entity.distance,
            maxSpeed: entity.maxSpeed,
            averageSpeed: entity.averageSpeed,
            trackPoints: [] // don't load all points during tracking
        )

        // Save to CoreData asynchronously to avoid blocking location updates
        // Track display uses routeCoordinates, not CoreData, so this doesn't affect rendering
        // viewContext must be used on main thread, so we save asynchronously
        DispatchQueue.main.async { [weak self] in
            self?.persistenceController.save()
        }
    }

    private func updateEntityStats(_ entity: TripEntity) {
        guard let points = entity.trackPoints?.array as? [TrackPointEntity],
              points.count > 1 else { return }

        var totalDistance: Double = 0
        var maxSpeed: Double = 0

        for i in 1..<points.count {
            let prev = CLLocation(latitude: points[i-1].latitude, longitude: points[i-1].longitude)
            let curr = CLLocation(latitude: points[i].latitude, longitude: points[i].longitude)
            totalDistance += curr.distance(from: prev)
            maxSpeed = max(maxSpeed, points[i].speed)
        }

        entity.distance = totalDistance
        entity.maxSpeed = maxSpeed

        if let start = entity.startDate, let end = entity.endDate {
            let elapsed = end.timeIntervalSince(start)
            entity.averageSpeed = elapsed > 0 ? totalDistance / elapsed : 0
        }
    }

    private func tripFromEntity(_ entity: TripEntity) -> Trip? {
        guard let id = entity.id, let startDate = entity.startDate else { return nil }

        let points: [TrackPoint] = (entity.trackPoints?.array as? [TrackPointEntity])?.compactMap { pe in
            guard let pid = pe.id, let ts = pe.timestamp else { return nil }
            return TrackPoint(
                id: pid,
                latitude: pe.latitude,
                longitude: pe.longitude,
                altitude: pe.altitude,
                speed: pe.speed,
                course: pe.course,
                horizontalAccuracy: pe.horizontalAccuracy,
                timestamp: ts
            )
        } ?? []

        return Trip(
            id: id,
            startDate: startDate,
            endDate: entity.endDate,
            distance: entity.distance,
            maxSpeed: entity.maxSpeed,
            averageSpeed: entity.averageSpeed,
            trackPoints: points
        )
    }
}
