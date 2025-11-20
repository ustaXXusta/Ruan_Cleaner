import SwiftUI

struct MatrixScanAnimation: View {
    @State private var animationPhase: CGFloat = 0
    @State private var particles: [MatrixParticle] = []
    @State private var timer: Timer?
    let isScanning: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Scanning lines
                ForEach(0..<3, id: \.self) { index in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    FuturisticTheme.softRed.opacity(0),
                                    FuturisticTheme.softRed.opacity(0.2),
                                    FuturisticTheme.softRed.opacity(0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 3)
                        .offset(y: (animationPhase + CGFloat(index) * 0.33).truncatingRemainder(dividingBy: 1) * geometry.size.height - geometry.size.height / 2)
                        .blur(radius: 2)
                }
                
                // Matrix particles
                ForEach(particles) { particle in
                    Text(particle.character)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(FuturisticTheme.softRed.opacity(particle.opacity))
                        .position(x: particle.x, y: particle.y)
                        .blur(radius: 0.5)
                }
            }
            .onChange(of: isScanning) { newValue in
                if newValue {
                    startAnimation(in: geometry.size)
                } else {
                    stopAnimation()
                }
            }
            .onAppear {
                if isScanning {
                    startAnimation(in: geometry.size)
                }
            }
            .onDisappear {
                stopAnimation()
            }
        }
    }
    
    private func startAnimation(in size: CGSize) {
        // Generate particles
        particles = (0..<25).map { _ in
            MatrixParticle(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: -50...size.height),
                character: ["0", "1", "█", "▓", "░", "01", "10"].randomElement()!,
                opacity: Double.random(in: 0.2...0.6)
            )
        }
        
        // Animate scanning lines
        withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
            animationPhase = 1
        }
        
        // Animate particles
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            guard isScanning else { return }
            
            particles = particles.map { particle in
                var newParticle = particle
                newParticle.y += 3
                if newParticle.y > size.height + 50 {
                    newParticle.y = -50
                    newParticle.x = CGFloat.random(in: 0...size.width)
                    newParticle.opacity = Double.random(in: 0.2...0.6)
                }
                return newParticle
            }
        }
    }
    
    private func stopAnimation() {
        timer?.invalidate()
        timer = nil
        animationPhase = 0
        particles = []
    }
}

struct MatrixParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    let character: String
    var opacity: Double
}
