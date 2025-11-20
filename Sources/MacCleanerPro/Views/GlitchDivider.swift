import SwiftUI

struct GlitchDivider: View {
    @State private var offset1: CGFloat = 0
    @State private var offset2: CGFloat = 0
    @State private var offset3: CGFloat = 0
    @State private var opacity1: Double = 1.0
    @State private var opacity2: Double = 0.7
    @State private var opacity3: Double = 0.5
    
    var height: CGFloat = 2
    var isVertical: Bool = false
    
    var body: some View {
        ZStack {
            if isVertical {
                // Vertical glitch divider
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(FuturisticTheme.softRed.opacity(opacity1))
                        .frame(width: height)
                        .offset(x: offset1)
                    
                    Rectangle()
                        .fill(FuturisticTheme.softRed.opacity(opacity2))
                        .frame(width: height * 0.8)
                        .offset(x: offset2)
                    
                    Rectangle()
                        .fill(FuturisticTheme.glowRed.opacity(opacity3))
                        .frame(width: height * 0.6)
                        .offset(x: offset3)
                }
                .frame(width: height)
            } else {
                // Horizontal glitch divider
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(FuturisticTheme.softRed.opacity(opacity1))
                        .frame(height: height)
                        .offset(y: offset1)
                    
                    Rectangle()
                        .fill(FuturisticTheme.softRed.opacity(opacity2))
                        .frame(height: height * 0.8)
                        .offset(y: offset2)
                    
                    Rectangle()
                        .fill(FuturisticTheme.glowRed.opacity(opacity3))
                        .frame(height: height * 0.6)
                        .offset(y: offset3)
                }
                .frame(height: height)
            }
        }
        .shadow(color: FuturisticTheme.softRed.opacity(0.5), radius: 4)
        .onAppear {
            startGlitchAnimation()
        }
    }
    
    private func startGlitchAnimation() {
        // Random glitch offsets
        let glitchDuration = 0.15
        let pauseDuration = 2.0
        
        func animateGlitch() {
            // Glitch effect
            withAnimation(.easeInOut(duration: glitchDuration)) {
                offset1 = CGFloat.random(in: -2...2)
                offset2 = CGFloat.random(in: -3...3)
                offset3 = CGFloat.random(in: -1.5...1.5)
                opacity1 = Double.random(in: 0.7...1.0)
                opacity2 = Double.random(in: 0.5...0.9)
                opacity3 = Double.random(in: 0.3...0.7)
            }
            
            // Reset after glitch
            DispatchQueue.main.asyncAfter(deadline: .now() + glitchDuration) {
                withAnimation(.easeInOut(duration: glitchDuration)) {
                    offset1 = 0
                    offset2 = 0
                    offset3 = 0
                    opacity1 = 1.0
                    opacity2 = 0.7
                    opacity3 = 0.5
                }
                
                // Schedule next glitch
                DispatchQueue.main.asyncAfter(deadline: .now() + pauseDuration) {
                    animateGlitch()
                }
            }
        }
        
        // Start with a random delay
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 0.5...2.0)) {
            animateGlitch()
        }
    }
}
