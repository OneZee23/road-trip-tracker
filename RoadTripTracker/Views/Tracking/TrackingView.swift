import SwiftUI
import MapKit

struct TrackingView: View {
    @EnvironmentObject var viewModel: TrackingViewModel
    @State private var showDevMenu = false

    @State private var joystickValue: CGPoint = .zero
    
    var body: some View {
        ZStack {
            // Fullscreen map
            Map(position: $viewModel.cameraPosition) {
                // Плавная линия трека
                if viewModel.trackManager.smoothDisplayPoints.count >= 2 {
                    MapPolyline(coordinates: viewModel.trackManager.smoothDisplayPoints)
                        .stroke(.cyan, style: StrokeStyle(
                            lineWidth: 4,
                            lineCap: .round,
                            lineJoin: .round
                        ))
                }
                
                // Маркер позиции
                if viewModel.locationManager.mode == .simulated {
                    // В симуляции показываем кастомный маркер
                    PositionAnnotation(
                        location: viewModel.locationManager.currentLocation,
                        isSimulated: true
                    )
                } else {
                    // В реальном режиме — стандартный
                    UserAnnotation()
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
                    
                    // Индикатор dev-режима
                    if viewModel.locationManager.isDeveloperMode {
                        HStack(spacing: 4) {
                            Image(systemName: "hammer.fill")
                                .font(.caption2)
                            Text("DEV")
                                .font(.system(.caption2, design: .monospaced, weight: .bold))
                        }
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.orange.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(.trailing, 8)
                    }
                    
                    // Переключатель dev-режима (только когда не записываем)
                    if !viewModel.isRecording {
                        Button {
                            viewModel.locationManager.isDeveloperMode.toggle()
                        } label: {
                            Label(
                                viewModel.locationManager.isDeveloperMode ? "Dev ON" : "Dev",
                                systemImage: viewModel.locationManager.isDeveloperMode ? "hammer.fill" : "hammer"
                            )
                            .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .tint(viewModel.locationManager.isDeveloperMode ? .orange : .secondary)
                        .padding(.trailing, 8)
                    }
                    
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
            if viewModel.locationManager.isDeveloperMode && viewModel.isRecording {
                VStack {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            // Индикатор режима симуляции
                            HStack(spacing: 6) {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.caption)
                                Text("SIMULATION")
                                    .font(.system(.caption2, design: .monospaced, weight: .bold))
                            }
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.orange.opacity(0.2))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            // Джойстик
                            JoystickViewNoReturn(value: $joystickValue)
                                .onChange(of: joystickValue) { _, newValue in
                                    viewModel.locationManager.joystickInput = newValue
                                }
                        }
                        .padding(.leading, 16)
                        .padding(.bottom, 200) // above HUD + tab bar

                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            viewModel.requestLocationPermission()
            viewModel.trackManager.startAnimation()
        }
        .onDisappear {
            viewModel.trackManager.stopAnimation()
        }
        .sheet(isPresented: $showDevMenu) {
            DevMenuView(viewModel: viewModel)
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
