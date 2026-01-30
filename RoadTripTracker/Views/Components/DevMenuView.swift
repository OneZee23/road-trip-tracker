import SwiftUI
import CoreLocation

struct DevMenuView: View {
    @ObservedObject var locationService: LocationService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Location Simulation") {
                    Toggle("Simulate Location", isOn: Binding(
                        get: { locationService.isSimulating },
                        set: { newValue in
                            if newValue {
                                locationService.startSimulation()
                            } else {
                                locationService.stopSimulation()
                            }
                        }
                    ))

                    if locationService.isSimulating {
                        Toggle("Show Joystick on Map", isOn: Binding(
                            get: { locationService.showJoystickOverlay },
                            set: { locationService.showJoystickOverlay = $0 }
                        ))

                        if let loc = locationService.currentLocation {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Lat: \(loc.coordinate.latitude, specifier: "%.5f")")
                                Text("Lng: \(loc.coordinate.longitude, specifier: "%.5f")")
                                Text("Speed: \(loc.speed * 3.6, specifier: "%.0f") km/h")
                            }
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Info") {
                    LabeledContent("Auth Status", value: authStatusText)
                    LabeledContent("Tracking", value: locationService.isTracking ? "Active" : "Inactive")
                }
            }
            .navigationTitle("Dev Menu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var authStatusText: String {
        switch locationService.authorizationStatus {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "When In Use"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Joystick (used on map overlay too)

struct JoystickView: View {
    let onDirectionChange: (CGVector) -> Void
    var radius: CGFloat = 70

    @State private var dragOffset: CGSize = .zero

    var body: some View {
        ZStack {
            // Base
            Circle()
                .fill(Color(.systemGray5).opacity(0.6))
                .frame(width: radius * 2, height: radius * 2)

            // Direction hints
            VStack {
                Image(systemName: "chevron.up").offset(y: -8)
                Spacer()
                Image(systemName: "chevron.down").offset(y: 8)
            }
            .font(.caption2)
            .foregroundStyle(.secondary.opacity(0.4))
            .frame(height: radius * 2 - 20)

            HStack {
                Image(systemName: "chevron.left").offset(x: -8)
                Spacer()
                Image(systemName: "chevron.right").offset(x: 8)
            }
            .font(.caption2)
            .foregroundStyle(.secondary.opacity(0.4))
            .frame(width: radius * 2 - 20)

            // Thumb
            Circle()
                .fill(.blue)
                .frame(width: 44, height: 44)
                .shadow(color: .blue.opacity(0.3), radius: 8)
                .offset(dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let vector = CGSize(
                                width: value.translation.width,
                                height: value.translation.height
                            )
                            let distance = sqrt(vector.width * vector.width + vector.height * vector.height)
                            if distance <= radius {
                                dragOffset = vector
                            } else {
                                let scale = radius / distance
                                dragOffset = CGSize(width: vector.width * scale, height: vector.height * scale)
                            }
                            let nx = dragOffset.width / radius
                            let ny = -dragOffset.height / radius
                            onDirectionChange(CGVector(dx: nx, dy: ny))
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.3)) {
                                dragOffset = .zero
                            }
                            onDirectionChange(.zero)
                        }
                )
        }
    }
}
