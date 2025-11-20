import SwiftUI

struct MatrixRainView: View {
    @State private var characters: [MatrixCharacter] = []
    let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Black background
                Color.black
                
                // City Background (Bottom Layer)
                Image("city_wireframe")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(0.7) // Increased opacity as requested
                    .blendMode(.screen)
                
                // Matrix Rain (Top Layer)
                ForEach(characters) { char in
                    Text(char.value)
                        .font(.system(size: char.size, weight: .bold, design: .monospaced))
                        .foregroundColor(char.color)
                        .position(x: char.x, y: char.y)
                        .opacity(char.opacity)
                }
            }
            .onReceive(timer) { _ in
                updateRain(in: geometry.size)
            }
            .onAppear {
                initializeRain(in: geometry.size)
            }
        }
        .drawingGroup() // Optimize rendering
        .ignoresSafeArea()
    }
    
    private func initializeRain(in size: CGSize) {
        // Create initial drops
        for _ in 0..<100 {
            addCharacter(in: size)
        }
    }
    
    private func updateRain(in size: CGSize) {
        // Move existing characters down
        for i in characters.indices {
            characters[i].y += characters[i].speed
            
            // Fade out at bottom
            if characters[i].y > size.height {
                characters[i].y = -20
                characters[i].x = CGFloat.random(in: 0...size.width)
                characters[i].value = randomMatrixChar()
            }
            
            // Randomly change character
            if Double.random(in: 0...1) < 0.05 {
                characters[i].value = randomMatrixChar()
            }
        }
        
        // Occasionally add new drops if count is low
        if characters.count < 150 && Double.random(in: 0...1) < 0.3 {
            addCharacter(in: size)
        }
    }
    
    private func addCharacter(in size: CGSize) {
        let char = MatrixCharacter(
            id: UUID(),
            x: CGFloat.random(in: 0...size.width),
            y: CGFloat.random(in: -size.height...0),
            size: CGFloat.random(in: 10...20),
            speed: CGFloat.random(in: 5...15),
            value: randomMatrixChar(),
            color: FuturisticTheme.softRed, // Changed to Red
            opacity: Double.random(in: 0.3...1.0)
        )
        characters.append(char)
    }
    
    private func randomMatrixChar() -> String {
        let chars = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        return String(chars.randomElement() ?? "0")
    }
}

struct MatrixCharacter: Identifiable {
    let id: UUID
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let speed: CGFloat
    var value: String
    var color: Color
    var opacity: Double
}

// Extension for Matrix Green color if not already defined
extension FuturisticTheme {
    static let matrixGreen = Color(red: 0.0, green: 1.0, blue: 0.4)
}
