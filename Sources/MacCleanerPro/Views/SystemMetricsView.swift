import SwiftUI

struct SystemMetricsView: View {
    @StateObject private var metricsService = SystemMetricsService()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("SYSTEM PERFORMANCE")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(FuturisticTheme.textPrimary)
                    .kerning(1.5)
                Spacer()
            }
            .padding()
            .background(Color.clear)
            
            GlitchDivider(height: 1)
            
            // Metrics Grid
            ScrollView {
                LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 110, maximum: 150), spacing: 8)
            ], spacing: 8) {
                ForEach(metricsService.metrics) { metric in
                    MetricCard(metric: metric)
                }
            }
            .padding(10)
            }
            .background(Color.clear)
        }
        .onAppear {
            metricsService.startMonitoring()
        }
        .onDisappear {
            metricsService.stopMonitoring()
        }
    }
}

struct MetricCard: View {
    let metric: SystemMetric
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                // Icon
                Image(systemName: metric.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(metric.status.color)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    // Value
                    if metric.type == .network {
                        // Special formatting for network
                        let parts = metric.value.split(separator: " ")
                        if parts.count >= 4 {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(parts[0] + " " + parts[1]) // Down
                                Text(parts[2] + " " + parts[3]) // Up
                            }
                            .font(.system(size: 9, weight: .bold, design: .monospaced)) // Reduced size
                            .foregroundColor(.white)
                        } else {
                            Text(metric.value)
                                .font(.system(size: 9, weight: .bold, design: .monospaced)) // Reduced size
                                .foregroundColor(.white)
                        }
                    } else {
                        Text(metric.value)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }
                    
                    // Label
                    Text(metric.type.rawValue.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(FuturisticTheme.textSecondary)
                        .lineLimit(1)
                    
                    // Detail
                    Text(metric.detail)
                        .font(.system(size: 9))
                        .foregroundColor(FuturisticTheme.textTertiary)
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 4)
            
            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 3)
                    
                    Rectangle()
                        .fill(metric.status.color)
                        .frame(width: geo.size.width * CGFloat(metric.percentage), height: 3)
                }
                .cornerRadius(1.5)
            }
            .frame(height: 3)
        }
        .padding(10)
        .background(FuturisticTheme.darkBackground.opacity(0.3))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.05), lineWidth: 1)
        )
    }
}
