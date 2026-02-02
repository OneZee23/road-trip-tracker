import SwiftUI
import MapKit

struct TrackingView: View {
    @EnvironmentObject var viewModel: TrackingViewModel
    @State private var showDevMenu = false

    var body: some View {
        ZStack {
            // Fullscreen map
            Map(position: $viewModel.cameraPosition) {
                // User position marker using native UserAnnotation
                UserAnnotation()
                
                if viewModel.routeCoordinates.count > 1 {
                    MapPolyline(coordinates: viewModel.routeCoordinates)
                        .stroke(.blue, lineWidth: 4)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls { }
            .ignoresSafeArea()
            .onMapCameraChange(frequency: .continuous) { context in
                viewModel.handleMapCameraChange(context)
            }

            // UI overlays
            VStack(spacing: 0) {
                // Top bar
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
                    
                    // Location tracking button — top right corner
                    LocationTrackingButton(
                        mode: viewModel.locationMode,
                        isEnabled: viewModel.isLocationTrackingEnabled,
                        action: { viewModel.toggleLocationMode() }
                    )
                    .padding(.trailing, 16)
                }
                .padding(.top, 56)

                Spacer()

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
        .alert("Геолокация недоступна", isPresented: $viewModel.showLocationAlert) {
            Button("Настройки") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Для использования отслеживания геолокации необходимо разрешить доступ к геолокации в настройках приложения.")
        }
    }
}


#Preview {
    TrackingView()
        .environmentObject(TrackingViewModel())
        .preferredColorScheme(.dark)
}
