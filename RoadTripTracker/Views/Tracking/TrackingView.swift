import SwiftUI
import MapKit

struct TrackingView: View {
    @EnvironmentObject var viewModel: TrackingViewModel
    @State private var showDevMenu = false

    var body: some View {
        ZStack {
            // Fullscreen map
            Map(position: $viewModel.cameraPosition) {
                // Always show custom arrow with heading direction
                if let coord = viewModel.userCoordinate {
                    Annotation("", coordinate: coord, anchor: .center) {
                        UserArrow(
                            heading: viewModel.heading,
                            mapHeading: viewModel.mapHeading
                        )
                    }
                }

                if viewModel.routeCoordinates.count > 1 {
                    MapPolyline(coordinates: viewModel.routeCoordinates)
                        .stroke(.blue, lineWidth: 4)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls { }
            .ignoresSafeArea()
            .onMapCameraChange(frequency: .continuous) { context in
                viewModel.isFollowingUser = false
                viewModel.updateMapHeading(context.camera.heading)
            }

            // UI overlays
            VStack(spacing: 0) {
                // Top bar — dev button
                HStack {
                    Button(action: { showDevMenu = true }) {
                        Image(systemName: "wrench.and.screwdriver")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(.leading, 12)

                    Spacer()
                }
                .padding(.top, 56)

                Spacer()

                // Controls row above HUD
                HStack(alignment: .bottom) {
                    CompassButton(heading: viewModel.compassHeading) {
                        viewModel.resetMapNorth()
                    }
                    .padding(.leading, 16)

                    Spacer()

                    Button(action: { viewModel.centerOnUser() }) {
                        Image(systemName: viewModel.isFollowingUser ? "location.fill" : "location")
                            .font(.body.weight(.medium))
                            .foregroundStyle(viewModel.isFollowingUser ? .blue : .primary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.trailing, 16)
                }
                .padding(.bottom, 8)

                TrackingHUD(
                    speed: viewModel.speed,
                    altitude: viewModel.altitude,
                    distance: viewModel.distance,
                    duration: viewModel.duration,
                    isRecording: viewModel.isRecording,
                    onToggleRecording: { viewModel.toggleRecording() }
                )
            }

            // Joystick overlay for simulation — bottom-left above tab bar
            if viewModel.locationService.showJoystickOverlay {
                VStack {
                    Spacer()
                    HStack {
                        JoystickView(
                            onDirectionChange: { direction in
                                viewModel.locationService.updateJoystick(direction)
                            },
                            radius: 55
                        )
                        .padding(.leading, 16)
                        .padding(.bottom, 200) // above HUD + tab bar

                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            viewModel.requestLocationPermission()
        }
        .sheet(isPresented: $showDevMenu) {
            DevMenuView(locationService: viewModel.locationService)
        }
    }
}

// MARK: - Custom arrow for simulation mode

private struct UserArrow: View {
    let heading: Double
    let mapHeading: Double

    private var rotation: Double {
        heading - mapHeading
    }

    var body: some View {
        ZStack {
            // Direction cone
            DirectionCone()
                .fill(.blue.opacity(0.25))
                .frame(width: 48, height: 48)
                .rotationEffect(.degrees(rotation - 90))

            // Center dot
            Circle()
                .fill(.blue)
                .frame(width: 18, height: 18)
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .shadow(color: .blue.opacity(0.4), radius: 6)

            // Arrow tip showing direction
            Image(systemName: "arrowtriangle.up.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .offset(y: -20)
                .rotationEffect(.degrees(rotation))
        }
        .animation(.easeOut(duration: 0.2), value: rotation)
    }
}

// MARK: - Compass button with continuous rotation (no jumps)

private struct CompassButton: View {
    let heading: Double // continuous (unwrapped) angle
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)

                VStack(spacing: 0) {
                    CompassTriangle()
                        .fill(.red)
                        .frame(width: 8, height: 10)
                    CompassTriangle()
                        .fill(.white)
                        .frame(width: 8, height: 10)
                        .rotationEffect(.degrees(180))
                }
                .rotationEffect(.degrees(-heading))

                Text("N")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.red)
                    .offset(y: -16)
                    .rotationEffect(.degrees(-heading))
            }
            .animation(.easeOut(duration: 0.15), value: heading)
        }
    }
}

private struct CompassTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct DirectionCone: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = rect.width / 2
        path.move(to: center)
        path.addArc(center: center, radius: radius,
                    startAngle: .degrees(-25), endAngle: .degrees(25),
                    clockwise: false)
        path.closeSubpath()
        return path
    }
}

#Preview {
    TrackingView()
        .environmentObject(TrackingViewModel())
        .preferredColorScheme(.dark)
}
