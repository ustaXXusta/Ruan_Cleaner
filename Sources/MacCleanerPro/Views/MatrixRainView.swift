import SwiftUI

/// Matrix rain drawn into a single Canvas.
///
/// The old version animated ~150 separate Text views with a 20 fps timer and rebuilt an array of
/// structs every frame, which made the whole window lag. Here every column's position is worked
/// out from the clock, so there is no per-frame state to update at all.
struct MatrixRainView: View {
    /// Overall strength of the effect (0...1).
    var intensity: Double = 0.6
    var framesPerSecond: Double = 15

    private static let glyphs: [String] = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ".map { String($0) }
    private static let columnWidth: CGFloat = 24

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / framesPerSecond)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let columns = max(Int(size.width / Self.columnWidth), 1)

                for column in 0..<columns {
                    var random = SeededRandom(seed: UInt64(column + 1) &* 0x9E37_79B9_7F4A_7C15)
                    // Leave some columns empty so it doesn't look like a wall of text.
                    if random.next() < 0.35 { continue }

                    let speed = 35 + random.next() * 90                 // points per second
                    let fontSize = CGFloat(10 + random.next() * 7)
                    let trail = 5 + Int(random.next() * 9)
                    let lineHeight = Double(fontSize) * 1.2
                    let span = Double(size.height) + Double(trail) * lineHeight + 120
                    let start = random.next() * span
                    let headY = (time * speed + start).truncatingRemainder(dividingBy: span) - 60
                    let x = (CGFloat(column) + 0.5) * Self.columnWidth

                    for step in 0..<trail {
                        let y = headY - Double(step) * lineHeight
                        if y < -Double(fontSize) || y > Double(size.height) + Double(fontSize) { continue }

                        // Characters flicker a few times per second.
                        let tick = Int(time * 5) &+ column &* 31 &+ step &* 17
                        let glyph = Self.glyphs[Int(UInt(bitPattern: tick &* 2_654_435_761) % UInt(Self.glyphs.count))]

                        let fade = 1 - Double(step) / Double(trail)
                        let color: Color = step == 0
                            ? Color.white.opacity(0.85 * intensity)
                            : FuturisticTheme.softRed.opacity(0.7 * fade * intensity)

                        context.draw(
                            Text(glyph)
                                .font(.system(size: fontSize, weight: .bold, design: .monospaced))
                                .foregroundColor(color),
                            at: CGPoint(x: x, y: CGFloat(y))
                        )
                    }
                }
            }
        }
        .background(Color.black)
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

/// Small deterministic random generator (SplitMix64), so each column keeps its own look.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    /// A number in 0..<1.
    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z = z ^ (z >> 31)
        return Double(z >> 11) / Double(1 << 53)
    }
}
