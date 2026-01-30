import SwiftUI
import MapKit

struct TripDetailView: View {
    let tripId: UUID
    @ObservedObject var viewModel: TripsViewModel
    @State private var trip: Trip?

    var body: some View {
        ScrollView {
            if let trip {
                VStack(spacing: 20) {
                    // Route map
                    if trip.trackPoints.count > 1 {
                        Map {
                            MapPolyline(coordinates: trip.trackPoints.map(\.coordinate))
                                .stroke(.blue, lineWidth: 4)
                        }
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray5))
                            .frame(height: 200)
                            .overlay {
                                VStack {
                                    Image(systemName: "map")
                                        .font(.largeTitle)
                                    Text("No route data")
                                        .font(.caption)
                                }
                                .foregroundStyle(.secondary)
                            }
                    }

                    // Stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        DetailStatCard(title: "Distance", value: String(format: "%.1f km", trip.distanceKm), icon: "road.lanes")
                        DetailStatCard(title: "Duration", value: trip.formattedDuration, icon: "clock")
                        DetailStatCard(title: "Max Speed", value: String(format: "%.0f km/h", trip.maxSpeedKmh), icon: "speedometer")
                        DetailStatCard(title: "Avg Speed", value: String(format: "%.0f km/h", trip.averageSpeedKmh), icon: "gauge.medium")
                        DetailStatCard(title: "Points", value: "\(trip.trackPoints.count)", icon: "mappin.and.ellipse")
                        DetailStatCard(title: "Start", value: trip.startDate.formatted(date: .omitted, time: .shortened), icon: "play.fill")
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle(trip?.startDate.formatted(date: .abbreviated, time: .omitted) ?? "Trip")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            trip = viewModel.tripDetail(id: tripId)
        }
    }
}

private struct DetailStatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
            Text(value)
                .font(.title3.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
