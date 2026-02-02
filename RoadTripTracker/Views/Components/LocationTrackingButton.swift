import SwiftUI

struct LocationTrackingButton: View {
    let mode: LocationTrackingMode
    let isEnabled: Bool
    let action: () -> Void
    
    @State private var isAnimating = false
    
    init(
        mode: LocationTrackingMode,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.mode = mode
        self.isEnabled = isEnabled
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            guard isEnabled else { return }
            
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
            action()
        }) {
            Image(systemName: mode.iconName)
                .font(.body.weight(.medium))
                .foregroundStyle(mode.iconColor)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                .opacity(isEnabled ? 1.0 : 0.5)
        }
        .disabled(!isEnabled)
    }
}

#Preview {
    VStack(spacing: 20) {
        LocationTrackingButton(mode: .none, action: {})
        LocationTrackingButton(mode: .centered, action: {})
        LocationTrackingButton(mode: .follow, action: {})
        LocationTrackingButton(mode: .none, isEnabled: false, action: {})
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}

