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

// Premium button style with hover effects
struct PremiumButtonStyle: ButtonStyle {
    var color: Color
    var isGlowing: Bool = false
    var isPrimary: Bool = false
    @State private var isHovered: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: isPrimary ? 18 : 16, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, isPrimary ? 50 : 35)
            .padding(.vertical, isPrimary ? 20 : 16)
            .background(
                RoundedRectangle(cornerRadius: isPrimary ? 12 : 10)
                    .fill(color.opacity(configuration.isPressed ? 0.7 : (isHovered ? 0.9 : 1.0)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: isPrimary ? 12 : 10)
                    .stroke(color.opacity(0.5), lineWidth: 1.5)
            )
            .shadow(color: isGlowing ? color.opacity(0.6) : color.opacity(0.3), radius: isGlowing ? 15 : 8)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
