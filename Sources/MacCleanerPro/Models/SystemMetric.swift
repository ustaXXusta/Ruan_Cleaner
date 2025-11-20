import Foundation
import SwiftUI

enum SystemMetricType: String, CaseIterable, Identifiable {
    case battery = "Battery Health"
    case cpu = "CPU Efficiency"
    case ram = "RAM Performance"
    case storage = "Storage I/O"
    case network = "Network Usage"
    case thermal = "Thermal Status"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .battery: return "battery.100"
        case .cpu: return "cpu"
        case .ram: return "memorychip"
        case .storage: return "internaldrive"
        case .network: return "network"
        case .thermal: return "thermometer"
        }
    }
}

enum MetricStatus {
    case good
    case warning
    case critical
    case unknown
    
    var color: Color {
        switch self {
        case .good: return Color(red: 0.95, green: 0.26, blue: 0.35)
        case .warning: return .yellow
        case .critical: return .red
        case .unknown: return .gray
        }
    }
}

struct SystemMetric: Identifiable {
    let id = UUID()
    let type: SystemMetricType
    var value: String
    var detail: String
    var percentage: Double // 0.0 to 1.0
    var status: MetricStatus
}
