import Foundation
import Darwin

/// What a cleanup actually did.
struct CleanReport {
    var deletedCount = 0
    var trashedCount = 0
    var skippedCount = 0
    var failedCount = 0
    /// Bytes removed for good. This space is free right away.
    var freedBytes: Int64 = 0
    /// Bytes moved to the Trash. This space only comes back when the Trash is emptied.
    var trashedBytes: Int64 = 0
    /// How much the disk's free space really changed, measured before and after.
    var diskFreeChange: Int64 = 0
    var wasDryRun = false
    var wasCancelled = false

    mutating func add(_ other: CleanReport) {
        deletedCount += other.deletedCount
        trashedCount += other.trashedCount
        skippedCount += other.skippedCount
        failedCount += other.failedCount
        freedBytes += other.freedBytes
        trashedBytes += other.trashedBytes
    }
}

/// One file to delete, as plain values that are safe to hand to background threads.
private struct CleanJob {
    let url: URL
    let path: String
    let name: String
    let size: Int64
    let permanent: Bool
    let leftover: Bool
}

private struct JobResult {
    var status: ScanItemStatus = .ready
    var note: String? = nil
}

/// Progress shared between the deleting threads and the UI.
private final class CleanTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var done = 0
    private var lastName = ""
    private var cancelled = false

    func tick(_ name: String) {
        lock.lock()
        done += 1
        lastName = name
        lock.unlock()
    }

    var snapshot: (done: Int, name: String) {
        lock.lock()
        defer { lock.unlock() }
        return (done, lastName)
    }

    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}

/// Deletes files fast.
///
/// Why the old version needed "1h" for 3 GB: after every 25 files the deleting thread stopped and
/// waited for the main thread to redraw the whole results list (130,000 rows' worth of totals),
/// so deleting was limited by the UI. Now:
/// - 4 threads delete in parallel and never wait for the UI,
/// - the UI reads a progress counter a few times a second,
/// - the list is updated once, at the end.
@MainActor
final class CleanerService: ObservableObject {
    @Published var isCleaning: Bool = false
    @Published var progress: Double = 0.0
    @Published var estimatedTimeRemaining: TimeInterval = 0
    @Published var filesProcessed: Int = 0
    @Published var totalFiles: Int = 0
    @Published var currentFileName: String = ""

    private var tracker: CleanTracker?
    private var progressTimer: Timer?

    /// Deletes the given items. Only items that are checked and still on disk are touched,
    /// and every one goes through SafetyManager first.
    func clean(items: [ScanItem], dryRun: Bool = false) async -> CleanReport {
        guard !isCleaning else { return CleanReport(wasDryRun: dryRun) }

        // Snapshot of the work list, taken once, so nothing changes under us mid-run.
        let work = items.filter { $0.isSelected && $0.isActive }.sorted { $0.size > $1.size }
        let jobs = work.map {
            CleanJob(url: $0.url, path: $0.path, name: $0.name, size: $0.size,
                     permanent: $0.category.deletesPermanently, leftover: $0.category == .appLeftovers)
        }

        let tracker = CleanTracker()
        self.tracker = tracker
        isCleaning = true
        progress = 0
        filesProcessed = 0
        totalFiles = jobs.count
        estimatedTimeRemaining = 0
        currentFileName = ""

        let startedAt = Date()
        let freeBefore = Self.freeSpace()

        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshProgress(startedAt: startedAt) }
        }

        let outcome: (results: [JobResult], report: CleanReport) = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: CleanerService.run(jobs, dryRun: dryRun, tracker: tracker))
            }
        }

        progressTimer?.invalidate()
        progressTimer = nil

        // Update the list once, with change notifications muted, then announce one change.
        ScanItem.muteChanges = true
        for (index, item) in work.enumerated() where outcome.results[index].status != .ready {
            item.status = outcome.results[index].status
            item.note = outcome.results[index].note
        }
        ScanItem.muteChanges = false
        ScanItem.changed.send()

        var report = outcome.report
        report.wasCancelled = tracker.isCancelled
        if !dryRun {
            // Give APFS a moment to update its counters, then measure the real change.
            try? await Task.sleep(nanoseconds: 400_000_000)
            report.diskFreeChange = Self.freeSpace() - freeBefore
        }

        self.tracker = nil
        filesProcessed = tracker.snapshot.done
        isCleaning = false
        progress = 1.0
        estimatedTimeRemaining = 0
        currentFileName = ""
        return report
    }

    func cancelCleaning() {
        tracker?.cancel()
    }

    private func refreshProgress(startedAt: Date) {
        guard let tracker, totalFiles > 0 else { return }
        let snapshot = tracker.snapshot
        filesProcessed = snapshot.done
        progress = Double(snapshot.done) / Double(totalFiles)
        currentFileName = snapshot.name

        let elapsed = Date().timeIntervalSince(startedAt)
        // Wait for a few hundred files before guessing, or the first slow files skew the estimate.
        if snapshot.done >= 300 && elapsed > 0.5 {
            let rate = Double(snapshot.done) / elapsed
            estimatedTimeRemaining = Double(totalFiles - snapshot.done) / rate
        } else {
            estimatedTimeRemaining = 0
        }
    }

    // MARK: - Background work

    nonisolated private static func run(_ jobs: [CleanJob], dryRun: Bool, tracker: CleanTracker) -> (results: [JobResult], report: CleanReport) {
        let workers = max(1, min(4, jobs.count))
        var results = [JobResult](repeating: JobResult(), count: jobs.count)
        var reports = [CleanReport](repeating: CleanReport(wasDryRun: dryRun), count: workers)

        results.withUnsafeMutableBufferPointer { resultPointer in
            reports.withUnsafeMutableBufferPointer { reportPointer in
                let resultBuffer = resultPointer
                let reportBuffer = reportPointer
                // Each worker takes every 4th file, so big and small files are spread evenly.
                // Workers write to different slots, so no locking is needed.
                DispatchQueue.concurrentPerform(iterations: workers) { worker in
                    var report = CleanReport(wasDryRun: dryRun)
                    var index = worker
                    while index < jobs.count {
                        if tracker.isCancelled { break }
                        let job = jobs[index]
                        resultBuffer[index] = process(job, dryRun: dryRun, report: &report)
                        tracker.tick(job.name)
                        index += workers
                    }
                    reportBuffer[worker] = report
                }
            }
        }

        var total = CleanReport(wasDryRun: dryRun)
        for report in reports { total.add(report) }
        return (results, total)
    }

    nonisolated private static func process(_ job: CleanJob, dryRun: Bool, report: inout CleanReport) -> JobResult {
        // Already gone (apps clear their own caches too): nothing to do, nothing to count.
        var info = stat()
        if lstat(job.path, &info) != 0 {
            return JobResult(status: .deleted, note: "Already removed")
        }

        if let reason = SafetyManager.shared.check(job.url) {
            report.skippedCount += 1
            return JobResult(status: .skipped, note: reason)
        }

        if dryRun {
            report.deletedCount += 1
            report.freedBytes += job.size
            return JobResult(status: .deleted)
        }

        do {
            try remove(job)
        } catch {
            // App containers carry a "deny delete" permission flag (ACL). For a deleted app's
            // leftovers, clear that flag and try once more.
            if job.leftover && clearACLs(job.path) {
                do {
                    try remove(job)
                } catch {
                    report.failedCount += 1
                    return JobResult(status: .error, note: error.localizedDescription)
                }
            } else {
                report.failedCount += 1
                return JobResult(status: .error, note: error.localizedDescription)
            }
        }

        if job.permanent {
            report.deletedCount += 1
            report.freedBytes += job.size
        } else {
            report.trashedCount += 1
            report.trashedBytes += job.size
        }
        return JobResult(status: .deleted)
    }

    nonisolated private static func remove(_ job: CleanJob) throws {
        if job.permanent {
            // Caches/logs/temp are deleted for real; moving them to the Trash frees nothing.
            try FileManager.default.removeItem(at: job.url)
        } else {
            try FileManager.default.trashItem(at: job.url, resultingItemURL: nil)
        }
    }

    /// Runs `chmod -RN` (remove ACLs) on one leftover folder. Returns true if it succeeded.
    nonisolated private static func clearACLs(_ path: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/chmod")
        process.arguments = ["-RN", path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        do {
            try process.run()
        } catch {
            return false
        }
        if finished.wait(timeout: .now() + 15) == .timedOut {
            process.terminate()
            return false
        }
        return process.terminationStatus == 0
    }

    /// Free space on the startup disk, in bytes.
    nonisolated static func freeSpace() -> Int64 {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        return Int64(values?.volumeAvailableCapacity ?? 0)
    }

    func formatTimeRemaining(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else if seconds < 3600 {
            let minutes = Int(seconds / 60)
            let secs = Int(seconds.truncatingRemainder(dividingBy: 60))
            return "\(minutes)m \(secs)s"
        } else {
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }
    }
}
