import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appModel: AppModel
    @ObservedObject private var permissions = PermissionManager.shared
    @State private var confirmClean = false
    @State private var cleanSummary = ""

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            // Everything scales with the column, so nothing spills out on small windows.
            let ringSize = max(160, min(width - 64, height * 0.42, 320))
            let logoWidth = max(140, min(width * 0.62, 300))

            ZStack {
                FuturisticTheme.darkerBackground
                MatrixRainView(intensity: 0.35)

                VStack(spacing: 0) {
                    // Logo
                    VStack(spacing: 10) {
                        if let logo = AppImages.load("ruan_wordmark") {
                            Image(nsImage: logo)
                                .resizable()
                                .interpolation(.high)
                                .aspectRatio(contentMode: .fit)
                                .frame(width: logoWidth)
                        } else {
                            Text("RUAN")
                                .font(.system(size: logoWidth * 0.22, weight: .black))
                                .foregroundColor(FuturisticTheme.softRed)
                        }

                        Text("SYSTEM CLEANER")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(FuturisticTheme.textTertiary)
                            .kerning(3)
                    }
                    .padding(.top, max(28, height * 0.06))

                    Spacer(minLength: 16)

                    StatusRing(size: ringSize)

                    notices
                        .padding(.horizontal, 28)
                        .padding(.top, 14)

                    if let reportText = appModel.lastReportText(), !appModel.isCleaning {
                        Text(reportText)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(FuturisticTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .padding(.horizontal, 28)
                            .padding(.top, 14)
                    }

                    Spacer(minLength: 16)

                    actionButtons
                        .frame(maxWidth: 420)
                        .padding(.horizontal, 28)
                        .padding(.bottom, max(24, height * 0.05))
                }
                .frame(width: width, height: height)
            }
        }
        .alert("Clean \(appModel.formatBytes(appModel.selectedSize))?", isPresented: $confirmClean) {
            Button("Clean", role: .destructive) {
                Task { await appModel.performCleanup() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(cleanSummary)
        }
        .onAppear {
            if !permissions.checkFullDiskAccess() {
                permissions.requestFullDiskAccessIfNeeded()
            }
        }
        // Coming back from System Settings: re-check so the warning disappears right away.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            _ = permissions.checkFullDiskAccess()
        }
    }

    /// Permission warning and categories that had to be skipped.
    @ViewBuilder
    private var notices: some View {
        VStack(spacing: 8) {
            if !permissions.hasFullDiskAccess {
                Button(action: { permissions.openFullDiskAccessSettings() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("Full Disk Access is off: scans are incomplete and can get stuck. Click to turn it on, then restart the app.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(FuturisticTheme.textPrimary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                    .frame(maxWidth: 420)
                    .background(Color.yellow.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.yellow.opacity(0.35), lineWidth: 1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }

            let skipped = appModel.scannerService.skippedCategories
            if !skipped.isEmpty && !appModel.isScanning {
                Text("Skipped (didn't respond): \(skipped.map { $0.rawValue }.joined(separator: ", "))")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.yellow.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 12) {
            if appModel.isScanning {
                Button(action: {}) {
                    HStack(spacing: 8) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.7)
                        Text("SCANNING")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PremiumButtonStyle(color: FuturisticTheme.textSecondary.opacity(0.35)))
                .disabled(true)

            } else if appModel.isCleaning {
                Button(action: { appModel.cleanerService.cancelCleaning() }) {
                    Text("STOP")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PremiumButtonStyle(color: FuturisticTheme.darkRed))

            } else if appModel.totalJunkSize > 0 {
                NavigationLink(destination: ScanResultsView()) {
                    Text("REVIEW")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PremiumButtonStyle(color: FuturisticTheme.darkRed))

                // Asks first, and lists exactly what will be removed from every category.
                Button(action: {
                    cleanSummary = appModel.cleanupSummary()
                    confirmClean = true
                }) {
                    Text("CLEAN")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PremiumButtonStyle(color: FuturisticTheme.softRed, isGlowing: true, isPrimary: true))
                .disabled(appModel.selectedSize == 0)

            } else {
                Button(action: {
                    Task { await appModel.startScan() }
                }) {
                    Text("SCAN")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(PremiumButtonStyle(color: FuturisticTheme.softRed, isGlowing: true, isPrimary: true))
            }
        }
    }
}

/// The big circle: shows scan progress, clean progress, or the result.
private struct StatusRing: View {
    @EnvironmentObject var appModel: AppModel
    let size: CGFloat

    var body: some View {
        let lineWidth = max(10, size * 0.06)
        let bigFont = size * 0.13

        ZStack {
            Circle()
                .fill(FuturisticTheme.darkBackground.opacity(0.92))

            Circle()
                .stroke(FuturisticTheme.softRed.opacity(0.14), lineWidth: lineWidth)
                .padding(lineWidth / 2 + 6)

            if let fraction = activeProgress {
                Circle()
                    .trim(from: 0, to: CGFloat(min(max(fraction, 0.005), 1)))
                    .stroke(FuturisticTheme.redGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(lineWidth / 2 + 6)
                    .animation(.easeOut(duration: 0.25), value: fraction)
            }

            VStack(spacing: size * 0.035) {
                if appModel.isCleaning {
                    let cleaner = appModel.cleanerService
                    Text("\(Int(cleaner.progress * 100))%")
                        .font(.system(size: bigFont, weight: .bold, design: .monospaced))
                        .foregroundColor(FuturisticTheme.softRed)
                    Text("\(cleaner.filesProcessed) / \(cleaner.totalFiles) FILES")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(FuturisticTheme.textSecondary)
                    if cleaner.estimatedTimeRemaining > 0 {
                        Text("ETA \(cleaner.formatTimeRemaining(cleaner.estimatedTimeRemaining))")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(FuturisticTheme.textTertiary)
                    }
                } else if appModel.isScanning {
                    Text(appModel.formatBytes(appModel.scannerService.currentScannedSize))
                        .font(.system(size: bigFont, weight: .bold, design: .monospaced))
                        .foregroundColor(FuturisticTheme.softRed)
                    Text(appModel.scannerService.currentStatus)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(FuturisticTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                } else if appModel.totalJunkSize > 0 {
                    Text(appModel.formatBytes(appModel.totalJunkSize))
                        .font(.system(size: bigFont, weight: .bold, design: .monospaced))
                        .foregroundColor(FuturisticTheme.softRed)
                    Text("DETECTED")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(FuturisticTheme.textSecondary)
                        .kerning(2)
                    Text("\(appModel.formatBytes(appModel.selectedSize)) selected")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(FuturisticTheme.textTertiary)
                    Button(action: { Task { await appModel.startScan() } }) {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                            Text("RESCAN")
                        }
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundColor(FuturisticTheme.textTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(FuturisticTheme.textTertiary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, 4)
                } else {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: size * 0.2))
                        .foregroundColor(FuturisticTheme.softRed.opacity(0.75))
                    Text("READY")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(FuturisticTheme.textSecondary)
                        .kerning(2)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, lineWidth + size * 0.1)
        }
        .frame(width: size, height: size)
    }

    private var activeProgress: Double? {
        if appModel.isCleaning { return appModel.cleanerService.progress }
        if appModel.isScanning { return appModel.scannerService.progress }
        return nil
    }
}
