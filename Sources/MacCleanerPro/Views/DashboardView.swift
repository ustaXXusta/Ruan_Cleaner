import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var glowAnimation: Bool = false
    
    var body: some View {
        ZStack {
            // Background
            FuturisticTheme.darkerBackground
                .ignoresSafeArea()
            
            // Matrix animation - ALWAYS ON (permanent)
            MatrixScanAnimation(isScanning: true)
                .opacity(0.25)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // TOP PROGRESS BAR - Always visible when cleaning
                if appModel.cleanerService.isCleaning {
                    CleaningProgressView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // RUAN Logo Image (from assets)
                VStack(spacing: 12) {
                    if let logoImage = NSImage(contentsOfFile: "/Users/mehmet/Desktop/Ruan Cleaner/assets/Ruan0.png") {
                        Image(nsImage: logoImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 400, height: 160)
                            .shadow(color: FuturisticTheme.softRed.opacity(0.4), radius: 15)
                    } else {
                        // Fallback
                        Text("RUAN")
                            .font(.system(size: 68, weight: .black, design: .default))
                            .foregroundColor(FuturisticTheme.softRed)
                            .shadow(color: FuturisticTheme.softRed.opacity(0.4), radius: 8)
                    }
                    
                    Text("SYSTEM CLEANER")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(FuturisticTheme.textTertiary)
                        .kerning(3)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Status Circle
                ZStack {
                    Circle()
                        .stroke(FuturisticTheme.softRed.opacity(0.12), lineWidth: 2)
                        .frame(width: 340, height: 340)
                        .shadow(color: FuturisticTheme.glowRed, radius: 20)
                    
                    Circle()
                        .fill(FuturisticTheme.darkBackground)
                        .frame(width: 310, height: 310)
                        .overlay(
                            Circle()
                                .stroke(FuturisticTheme.softRed.opacity(0.15), lineWidth: 1)
                        )
                    
                    if appModel.isScanning {
                        Circle()
                            .trim(from: 0.0, to: CGFloat(min(appModel.scannerService.progress, 1.0)))
                            .stroke(
                                FuturisticTheme.redGradient,
                                style: StrokeStyle(lineWidth: 22, lineCap: .round)
                            )
                            .frame(width: 285, height: 285)
                            .rotationEffect(Angle(degrees: -90))
                            .shadow(color: FuturisticTheme.softRed.opacity(0.6), radius: 12)
                            .animation(.easeInOut(duration: 0.3), value: appModel.scannerService.progress)
                    }
                    
                    VStack(spacing: 14) {
                        if appModel.isScanning {
                            Text(appModel.formatBytes(appModel.scannerService.currentScannedSize))
                                .font(.system(size: 42, weight: .bold, design: .monospaced))
                                .foregroundColor(FuturisticTheme.softRed)
                            
                            Text(appModel.scannerService.currentStatus)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(FuturisticTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                                .lineLimit(2)
                        } else if appModel.totalJunkSize > 0 {
                            Text(appModel.formatBytes(appModel.totalJunkSize))
                                .font(.system(size: 42, weight: .bold, design: .monospaced))
                                .foregroundColor(FuturisticTheme.softRed)
                            
                            Text("DETECTED")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(FuturisticTheme.textSecondary)
                                .kerning(2)
                            
                            Button(action: {
                                Task {
                                    await appModel.startScan()
                                }
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 10))
                                    Text("RESCAN")
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                }
                                .foregroundColor(FuturisticTheme.textTertiary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(FuturisticTheme.textTertiary.opacity(0.25), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.top, 8)
                        } else {
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 75))
                                .foregroundColor(FuturisticTheme.softRed.opacity(0.7))
                                .padding(.bottom, 6)
                            
                            Text("READY")
                                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                                .foregroundColor(FuturisticTheme.textSecondary)
                                .kerning(2)
                        }
                    }
                }
                .padding(.vertical, 35)
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 20) {
                    if appModel.isScanning {
                        Button(action: {}) {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("SCANNING")
                            }
                        }
                        .buttonStyle(PremiumButtonStyle(color: FuturisticTheme.textSecondary.opacity(0.35), isPrimary: false))
                        .disabled(true)
                        
                    } else if appModel.totalJunkSize > 0 {
                        NavigationLink(destination: ScanResultsView()) {
                            Text("REVIEW")
                        }
                        .buttonStyle(PremiumButtonStyle(color: FuturisticTheme.darkRed))
                        
                        Button(action: {
                            Task {
                                await appModel.performRealCleanup()
                            }
                        }) {
                            Text(appModel.cleanerService.isCleaning ? "CLEANING..." : "CLEAN")
                        }
                        .buttonStyle(PremiumButtonStyle(color: FuturisticTheme.softRed, isGlowing: true, isPrimary: true))
                        .disabled(appModel.cleanerService.isCleaning)
                        
                    } else {
                        Button(action: {
                            Task {
                                await appModel.startScan()
                            }
                        }) {
                            Text("SCAN")
                        }
                        .buttonStyle(PremiumButtonStyle(color: FuturisticTheme.softRed, isGlowing: true, isPrimary: true))
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            if !PermissionManager.shared.hasFullDiskAccess {
                PermissionManager.shared.requestFullDiskAccessIfNeeded()
            }
            
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                glowAnimation = true
            }
        }
    }
}
