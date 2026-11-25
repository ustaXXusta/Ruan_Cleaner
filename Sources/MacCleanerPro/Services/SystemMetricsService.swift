import Foundation
import SwiftUI
import IOKit.ps
import Darwin

/// Live system numbers for the sidebar. All values are real readings
/// (the old version showed random numbers for CPU, disk I/O and network).
@MainActor
final class SystemMetricsService: ObservableObject {
    @Published var metrics: [SystemMetric] = []
    private var timer: Timer?

    // Previous readings, used to turn counters into rates.
    private var lastCPUTicks: (busy: UInt64, total: UInt64)?
    private var lastNetwork: (received: UInt64, sent: UInt64, time: Date)?

    init() {
        metrics = SystemMetricType.allCases.map { type in
            SystemMetric(type: type, value: "…", detail: "Reading", percentage: 0.0, status: .unknown)
        }
    }

    func startMonitoring() {
        guard timer == nil else { return }   // the view's onAppear used to start a second timer
        updateMetrics()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMetrics()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    private func updateMetrics() {
        metrics = [
            getBatteryMetric(),
            getCPUMetric(),
            getRAMMetric(),
            getStorageMetric(),
            getNetworkMetric(),
            getThermalMetric()
        ]
    }

    // MARK: - Battery

    private func getBatteryMetric() -> SystemMetric {
        let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] ?? []

        guard let source = sources.first,
              let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
              let current = info[kIOPSCurrentCapacityKey] as? Int,
              let maxCapacity = info[kIOPSMaxCapacityKey] as? Int, maxCapacity > 0 else {
            return SystemMetric(type: .battery, value: "AC", detail: "No battery", percentage: 1.0, status: .good)
        }

        let capacity = Int(Double(current) / Double(maxCapacity) * 100)
        let charging = info[kIOPSIsChargingKey] as? Bool ?? false
        let onAC = (info[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue

        var status: MetricStatus = .good
        if capacity < 50 { status = .warning }
        if capacity < 20 { status = .critical }

        return SystemMetric(
            type: .battery,
            value: "\(capacity)%",
            detail: charging ? "Charging" : (onAC ? "On power adapter" : "On battery"),
            percentage: Double(capacity) / 100.0,
            status: status
        )
    }

    // MARK: - CPU

    private func readCPUTicks() -> (busy: UInt64, total: UInt64)? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        let user = UInt64(info.cpu_ticks.0)
        let system = UInt64(info.cpu_ticks.1)
        let idle = UInt64(info.cpu_ticks.2)
        let nice = UInt64(info.cpu_ticks.3)
        return (user + system + nice, user + system + idle + nice)
    }

    private func getCPUMetric() -> SystemMetric {
        guard let now = readCPUTicks() else {
            return SystemMetric(type: .cpu, value: "—", detail: "Unavailable", percentage: 0, status: .unknown)
        }
        defer { lastCPUTicks = now }
        guard let last = lastCPUTicks, now.total > last.total else {
            return SystemMetric(type: .cpu, value: "…", detail: "Measuring", percentage: 0, status: .unknown)
        }

        let load = Double(now.busy - last.busy) / Double(now.total - last.total)
        let cores = ProcessInfo.processInfo.activeProcessorCount
        return SystemMetric(
            type: .cpu,
            value: "\(Int(load * 100))%",
            detail: "\(cores) cores",
            percentage: load,
            status: load < 0.7 ? .good : (load < 0.9 ? .warning : .critical)
        )
    }

    // MARK: - Memory

    private func getRAMMetric() -> SystemMetric {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return SystemMetric(type: .ram, value: "—", detail: "Unavailable", percentage: 0, status: .unknown)
        }

        let pageSize = UInt64(vm_kernel_page_size)
        // Roughly what Activity Monitor calls "Memory Used": app memory + wired + compressed.
        let appMemory = UInt64(stats.internal_page_count) &- UInt64(stats.purgeable_count)
        let used = (appMemory + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)) * pageSize
        let physical = ProcessInfo.processInfo.physicalMemory
        let fraction = min(Double(used) / Double(physical), 1.0)

        return SystemMetric(
            type: .ram,
            value: "\(Int(fraction * 100))%",
            detail: String(format: "%.1f / %.0f GB", Double(used) / 1_073_741_824, Double(physical) / 1_073_741_824),
            percentage: fraction,
            status: fraction < 0.7 ? .good : (fraction < 0.9 ? .warning : .critical)
        )
    }

    // MARK: - Storage

    private func getStorageMetric() -> SystemMetric {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
        let total = Int64(values?.volumeTotalCapacity ?? 0)
        // Same "available" number Finder shows (includes purgeable space macOS can clear itself).
        let available = values?.volumeAvailableCapacityForImportantUsage ?? 0

        guard total > 0 else {
            return SystemMetric(type: .storage, value: "—", detail: "Unavailable", percentage: 0, status: .unknown)
        }
        let usedFraction = Double(total - available) / Double(total)
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file

        return SystemMetric(
            type: .storage,
            value: "\(Int(usedFraction * 100))% used",
            detail: "\(formatter.string(fromByteCount: available)) free",
            percentage: usedFraction,
            status: usedFraction < 0.8 ? .good : (usedFraction < 0.95 ? .warning : .critical)
        )
    }

    // MARK: - Network

    private func readNetworkBytes() -> (received: UInt64, sent: UInt64) {
        var received: UInt64 = 0
        var sent: UInt64 = 0
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0, let first = addresses else { return (0, 0) }
        defer { freeifaddrs(addresses) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let pointer = cursor {
            let entry = pointer.pointee
            if let address = entry.ifa_addr, address.pointee.sa_family == UInt8(AF_LINK),
               let data = entry.ifa_data {
                let name = String(cString: entry.ifa_name)
                if !name.hasPrefix("lo") {
                    let counters = data.assumingMemoryBound(to: if_data.self).pointee
                    received += UInt64(counters.ifi_ibytes)
                    sent += UInt64(counters.ifi_obytes)
                }
            }
            cursor = entry.ifa_next
        }
        return (received, sent)
    }

    private func formatRate(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1_048_576 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1_048_576)
        }
        return String(format: "%.0f KB/s", bytesPerSecond / 1024)
    }

    private func getNetworkMetric() -> SystemMetric {
        let now = readNetworkBytes()
        let time = Date()
        defer { lastNetwork = (now.received, now.sent, time) }

        guard let last = lastNetwork else {
            return SystemMetric(type: .network, value: "…", detail: "Measuring", percentage: 0, status: .unknown)
        }
        let seconds = max(time.timeIntervalSince(last.time), 0.1)
        // Counters can wrap or reset (interface reconnects); treat that as zero.
        let down = now.received >= last.received ? Double(now.received - last.received) / seconds : 0
        let up = now.sent >= last.sent ? Double(now.sent - last.sent) / seconds : 0

        return SystemMetric(
            type: .network,
            value: "↓\(formatRate(down)) ↑\(formatRate(up))",
            detail: "Live",
            percentage: min((down + up) / (50 * 1_048_576), 1.0),   // bar full at 50 MB/s
            status: .good
        )
    }

    // MARK: - Thermal

    private func getThermalMetric() -> SystemMetric {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:
            return SystemMetric(type: .thermal, value: "Cool", detail: "No throttling", percentage: 0.2, status: .good)
        case .fair:
            return SystemMetric(type: .thermal, value: "Warm", detail: "Light throttling", percentage: 0.5, status: .warning)
        case .serious:
            return SystemMetric(type: .thermal, value: "Hot", detail: "Throttling", percentage: 0.8, status: .warning)
        case .critical:
            return SystemMetric(type: .thermal, value: "Overheating", detail: "Heavy throttling", percentage: 1.0, status: .critical)
        @unknown default:
            return SystemMetric(type: .thermal, value: "Unknown", detail: "", percentage: 0, status: .unknown)
        }
    }
}
