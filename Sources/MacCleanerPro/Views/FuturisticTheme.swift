import SwiftUI

struct FuturisticTheme {
    // RUAN Dark Theme - Red focused
    static let darkBackground = Color(red: 0.12, green: 0.12, blue: 0.14) // #1E1E24
    static let darkerBackground = Color(red: 0.08, green: 0.08, blue: 0.10) // #141416
    static let softRed = Color(red: 0.95, green: 0.26, blue: 0.35) // #F24259
    static let glowRed = Color(red: 1.0, green: 0.2, blue: 0.3).opacity(0.6)
    static let darkRed = Color(red: 0.7, green: 0.15, blue: 0.25)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.7, green: 0.7, blue: 0.75)
    static let textTertiary = Color(red: 0.5, green: 0.5, blue: 0.55)

    // Gradients - Red only
    static let redGradient = LinearGradient(
        colors: [softRed, darkRed],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let subtleRedGradient = LinearGradient(
        colors: [softRed.opacity(0.8), darkRed.opacity(0.6)],
        startPoint: .top,
        endPoint: .bottom
    )
}

/// Main button style. Text stays on one line and shrinks a little instead of turning into "CLEANI...".
struct PremiumButtonStyle: ButtonStyle {
    var color: Color
    var isGlowing: Bool = false
    var isPrimary: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        PremiumButtonBody(configuration: configuration, color: color, isGlowing: isGlowing, isPrimary: isPrimary)
    }
}

/// Separate view so hover state actually works (@State inside a ButtonStyle doesn't).
private struct PremiumButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let color: Color
    let isGlowing: Bool
    let isPrimary: Bool

    @Environment(\.isEnabled) private var isEnabled
    @State private var isHovered = false

    var body: some View {
        let radius: CGFloat = isPrimary ? 12 : 10

        configuration.label
            .font(.system(size: isPrimary ? 16 : 15, weight: .bold, design: .rounded))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundColor(.white)
            .padding(.horizontal, isPrimary ? 22 : 18)
            .padding(.vertical, isPrimary ? 14 : 12)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(color.opacity(configuration.isPressed ? 0.75 : (isHovered ? 0.9 : 1.0)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(Color.white.opacity(isHovered ? 0.18 : 0.08), lineWidth: 1)
            )
            .shadow(color: isGlowing && isEnabled ? color.opacity(0.4) : .clear, radius: 10)
            .opacity(isEnabled ? 1 : 0.55)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onHover { isHovered = $0 }
    }
}
