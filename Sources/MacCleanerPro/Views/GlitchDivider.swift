import SwiftUI

/// Thin red divider line.
///
/// The old version restarted an endless glitch-animation loop every time a divider appeared
/// (and never stopped it), with a shadow on each one. Loops piled up the longer the app ran,
/// which was a big part of the lag. This one is static.
struct GlitchDivider: View {
    var height: CGFloat = 2
    var isVertical: Bool = false

    var body: some View {
        Rectangle()
            .fill(FuturisticTheme.softRed.opacity(0.45))
            .frame(width: isVertical ? height : nil, height: isVertical ? nil : height)
    }
}
