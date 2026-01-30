import XCTest
@testable import RoadTripTracker

final class RoadTripTrackerTests: XCTestCase {

    func testTripInitialization() {
        let trip = Trip()
        XCTAssertNotNil(trip.id)
        XCTAssertTrue(trip.isActive)
        XCTAssertEqual(trip.distance, 0)
        XCTAssertEqual(trip.maxSpeed, 0)
    }

    func testTripDuration() {
        let start = Date().addingTimeInterval(-3600) // 1 hour ago
        let end = Date()
        let trip = Trip(startDate: start, endDate: end, distance: 50000)
        XCTAssertEqual(trip.duration, 3600, accuracy: 1)
        XCTAssertEqual(trip.distanceKm, 50)
        XCTAssertFalse(trip.isActive)
    }

    func testTrackPointFromLocation() {
        let point = TrackPoint(latitude: 55.7558, longitude: 37.6173, altitude: 150, speed: 16.7)
        XCTAssertEqual(point.latitude, 55.7558)
        XCTAssertEqual(point.longitude, 37.6173)
        XCTAssertEqual(point.speedKmh, 16.7 * 3.6, accuracy: 0.1)
    }

    func testTripFormattedDuration() {
        let start = Date()
        let end = start.addingTimeInterval(5025) // 1h 23m 45s
        let trip = Trip(startDate: start, endDate: end)
        XCTAssertEqual(trip.formattedDuration, "1:23:45")
    }

    func testPersistenceControllerPreview() {
        let controller = PersistenceController.preview
        XCTAssertNotNil(controller.container)
    }
}
