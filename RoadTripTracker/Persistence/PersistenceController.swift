import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext

        let trip = TripEntity(context: viewContext)
        trip.id = UUID()
        trip.startDate = Date().addingTimeInterval(-3600)
        trip.endDate = Date()
        trip.distance = 45200
        trip.maxSpeed = 33.3
        trip.averageSpeed = 12.6

        for i in 0..<10 {
            let point = TrackPointEntity(context: viewContext)
            point.id = UUID()
            point.latitude = 55.7558 + Double(i) * 0.001
            point.longitude = 37.6173 + Double(i) * 0.001
            point.altitude = 150 + Double(i) * 2
            point.speed = Double.random(in: 5...30)
            point.course = Double(i * 36)
            point.horizontalAccuracy = 5.0
            point.timestamp = Date().addingTimeInterval(-3600 + Double(i) * 360)
            point.trip = trip
        }

        try? viewContext.save()
        return controller
    }()

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "RoadTripTracker")
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("CoreData error: \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    func save() {
        let context = container.viewContext
        if context.hasChanges {
            try? context.save()
        }
    }
}
