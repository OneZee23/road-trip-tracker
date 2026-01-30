import Foundation
import CoreLocation

struct Trip: Identifiable {
    let id: UUID
    var startDate: Date
    var endDate: Date?
    var distance: Double // meters
    var maxSpeed: Double // m/s
    var averageSpeed: Double // m/s
    var trackPoints: [TrackPoint]

    var isActive: Bool {
        endDate == nil
    }

    var duration: TimeInterval {
        let end = endDate ?? Date()
        return end.timeIntervalSince(startDate)
    }

    var distanceKm: Double {
        distance / 1000.0
    }

    var maxSpeedKmh: Double {
        maxSpeed * 3.6
    }

    var averageSpeedKmh: Double {
        averageSpeed * 3.6
    }

    var formattedDuration: String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    init(id: UUID = UUID(), startDate: Date = Date(), endDate: Date? = nil,
         distance: Double = 0, maxSpeed: Double = 0, averageSpeed: Double = 0,
         trackPoints: [TrackPoint] = []) {
        self.id = id
        self.startDate = startDate
        self.endDate = endDate
        self.distance = distance
        self.maxSpeed = maxSpeed
        self.averageSpeed = averageSpeed
        self.trackPoints = trackPoints
    }
}
