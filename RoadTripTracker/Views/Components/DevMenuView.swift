import SwiftUI
import CoreLocation

struct DevMenuView: View {
    @ObservedObject var viewModel: TrackingViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                // Developer Mode Section
                Section {
                    Toggle("Developer Mode", isOn: Binding(
                        get: { viewModel.locationManager.isDeveloperMode },
                        set: { newValue in
                            // Можно переключать только когда не записываем
                            if !viewModel.isRecording {
                                viewModel.locationManager.isDeveloperMode = newValue
                            }
                        }
                    ))
                    .disabled(viewModel.isRecording)
                    
                    if viewModel.isRecording {
                        Text("Остановите запись для изменения режима")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if viewModel.locationManager.isDeveloperMode {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Dev-режим активен")
                                .foregroundStyle(.green)
                        }
                        .font(.subheadline)
                    }
                } header: {
                    Text("Developer Mode")
                } footer: {
                            VStack(alignment: .leading, spacing: 4) {
                        Text("В dev-режиме:")
                        Text("• Джойстик управляет виртуальной позицией")
                        Text("• Реальный GPS отключается при записи")
                        Text("• Начальная точка = текущая GPS позиция")
                        Text("• Джойстик появляется при начале записи")
                    }
                    .font(.caption)
                }
                
                // Location Info Section
                Section("Current Location") {
                    if let location = viewModel.locationManager.currentLocation {
                        LocationInfoRow(
                            title: "Latitude",
                            value: String(format: "%.6f", location.coordinate.latitude),
                            icon: "mappin"
                        )
                        LocationInfoRow(
                            title: "Longitude",
                            value: String(format: "%.6f", location.coordinate.longitude),
                            icon: "mappin"
                        )
                        LocationInfoRow(
                            title: "Speed",
                            value: String(format: "%.1f km/h", location.speed * 3.6),
                            icon: "speedometer"
                        )
                        LocationInfoRow(
                            title: "Course",
                            value: String(format: "%.1f°", location.course),
                            icon: "arrow.up"
                        )
                        LocationInfoRow(
                            title: "Accuracy",
                            value: String(format: "%.1f m", location.horizontalAccuracy),
                            icon: "target"
                        )
                        LocationInfoRow(
                            title: "Mode",
                            value: viewModel.locationManager.mode == .simulated ? "Simulated" : "Real GPS",
                            icon: viewModel.locationManager.mode == .simulated ? "gamecontroller" : "location.fill"
                        )
                    } else {
                        Label("No location available", systemImage: "location.slash")
                            .foregroundStyle(.secondary)
                    }
                }
                
                // Tracking Info Section
                Section("Tracking Status") {
                    LocationInfoRow(
                        title: "Recording",
                        value: viewModel.isRecording ? "Active" : "Inactive",
                        icon: viewModel.isRecording ? "record.circle.fill" : "record.circle",
                        valueColor: viewModel.isRecording ? .red : .secondary
                    )
                    
                    if viewModel.isRecording {
                        LocationInfoRow(
                            title: "Distance",
                            value: String(format: "%.2f km", viewModel.distance),
                            icon: "ruler"
                        )
                        LocationInfoRow(
                            title: "Duration",
                            value: viewModel.duration,
                            icon: "clock"
                        )
                        LocationInfoRow(
                            title: "Track Points",
                            value: "\(viewModel.trackManager.confirmedPoints.count + (viewModel.trackManager.animatedHeadPosition != nil ? 1 : 0))",
                            icon: "point.topleft.down.curvedto.point.bottomright.up"
                        )
                        LocationInfoRow(
                            title: "Smooth Points",
                            value: "\(viewModel.trackManager.smoothDisplayPoints.count)",
                            icon: "waveform.path"
                        )
                    }
                }
                
                // Speed & Stats Section
                Section("Current Stats") {
                    LocationInfoRow(
                        title: "Current Speed",
                        value: String(format: "%.1f km/h", viewModel.speed),
                        icon: "gauge"
                    )
                    LocationInfoRow(
                        title: "Altitude",
                        value: String(format: "%.0f m", viewModel.altitude),
                        icon: "mountain.2"
                    )
                    LocationInfoRow(
                        title: "Heading",
                        value: String(format: "%.1f°", viewModel.heading),
                        icon: "compass"
                    )
                }
                
                // Joystick Info (only in dev mode)
                if viewModel.locationManager.isDeveloperMode {
                    Section("Joystick Control") {
                        let joystick = viewModel.locationManager.joystickInput
                        let magnitude = sqrt(joystick.x * joystick.x + joystick.y * joystick.y)
                        let angle = atan2(joystick.x, joystick.y) * 180 / .pi
                        
                        LocationInfoRow(
                            title: "Input X",
                            value: String(format: "%.2f", joystick.x),
                            icon: "arrow.left.right"
                        )
                        LocationInfoRow(
                            title: "Input Y",
                            value: String(format: "%.2f", joystick.y),
                            icon: "arrow.up.down"
                        )
                        LocationInfoRow(
                            title: "Magnitude",
                            value: String(format: "%.2f", magnitude),
                            icon: "waveform"
                        )
                        LocationInfoRow(
                            title: "Direction",
                            value: String(format: "%.1f°", angle >= 0 ? angle : angle + 360),
                            icon: "arrow.triangle.2.circlepath"
                        )
                        
                        if viewModel.isRecording {
                            Text("Джойстик активен на карте")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Начните запись для активации джойстика")
                                .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                // Legacy Location Service Info
                Section("Legacy Location Service") {
                    LocationInfoRow(
                        title: "Auth Status",
                        value: authStatusText,
                        icon: "lock.shield"
                    )
                    LocationInfoRow(
                        title: "Tracking",
                        value: viewModel.locationService.isTracking ? "Active" : "Inactive",
                        icon: "location.fill"
                    )
                    LocationInfoRow(
                        title: "Simulating",
                        value: viewModel.locationService.isSimulating ? "Yes" : "No",
                        icon: "gamecontroller"
                    )
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
        switch viewModel.locationService.authorizationStatus {
        case .notDetermined: return "Not Determined"
        case .restricted: return "Restricted"
        case .denied: return "Denied"
        case .authorizedAlways: return "Always"
        case .authorizedWhenInUse: return "When In Use"
        @unknown default: return "Unknown"
        }
    }
}

// MARK: - Location Info Row

struct LocationInfoRow: View {
    let title: String
    let value: String
    let icon: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            
            Text(title)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(valueColor)
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

/// Вариант джойстика без автовозврата (для постоянной скорости в симуляции)
struct JoystickViewNoReturn: View {
    @Binding var value: CGPoint // от -1 до 1
    
    let size: CGFloat = 120
    let knobSize: CGFloat = 50
    
    @State private var knobOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            // Фон джойстика с градиентом
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.6), .purple.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            // Направляющие линии
            Path { path in
                path.move(to: CGPoint(x: size/2, y: 10))
                path.addLine(to: CGPoint(x: size/2, y: size - 10))
                path.move(to: CGPoint(x: 10, y: size/2))
                path.addLine(to: CGPoint(x: size - 10, y: size/2))
            }
            .stroke(.white.opacity(0.3), lineWidth: 1.5)
            .frame(width: size, height: size)
            
            // Компасные направления
            VStack(spacing: 0) {
                Text("N")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .offset(y: -size/2 + 15)
                Spacer()
                Text("S")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .offset(y: size/2 - 15)
            }
            .frame(height: size)
            
            HStack(spacing: 0) {
                Text("W")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .offset(x: -size/2 + 15)
                Spacer()
                Text("E")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.6))
                    .offset(x: size/2 - 15)
            }
            .frame(width: size)
            
            // Ручка джойстика с градиентом
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: knobSize, height: knobSize)
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                
                // Индикатор направления
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
            }
            .offset(knobOffset)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let maxOffset = (size - knobSize) / 2
                        
                        // Ограничиваем в пределах круга
                        let vector = CGSize(
                            width: gesture.translation.width,
                            height: gesture.translation.height
                        )
                        let distance = sqrt(vector.width * vector.width + vector.height * vector.height)
                        
                        if distance <= maxOffset {
                            knobOffset = vector
                        } else {
                            let scale = maxOffset / distance
                            knobOffset = CGSize(
                                width: vector.width * scale,
                                height: vector.height * scale
                            )
                        }
                        
                        // Нормализуем значение от -1 до 1
                        value = CGPoint(
                            x: knobOffset.width / maxOffset,
                            y: -knobOffset.height / maxOffset // Инвертируем Y (вверх = положительно)
                        )
                    }
                // НЕ сбрасываем при отпускании — скорость сохраняется
                )
        }
    }
}
