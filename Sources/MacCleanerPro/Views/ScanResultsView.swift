import SwiftUI

struct ScanResultsView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var selectedCategory: CleanupCategory?

    var body: some View {
        ZStack {
            // Background: matrix rain only (city image removed)
            MatrixRainView(intensity: 0.25)

            VStack(spacing: 0) {
                // TOP PROGRESS BAR - Always visible when cleaning
                if appModel.cleanerService.isCleaning {
                    CleaningProgressView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                HStack(spacing: 0) {
                    // Sidebar Column (Categories + Metrics)
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            CategoriesSidebar(selectedCategory: $selectedCategory)
                                .frame(height: geo.size.height * 0.5)

                            GlitchDivider(height: 2)

                            SystemMetricsView()
                                .frame(height: geo.size.height * 0.5)
                        }
                    }
                    .frame(width: 300)
                    .background(Color.black.opacity(0.4))

                    GlitchDivider(height: 1, isVertical: true)

                    GroupedFileListView(selectedCategory: selectedCategory)
                }
            }
        }
        .navigationTitle("")
        .onAppear {
            if selectedCategory == nil, let first = appModel.scanResults.first {
                selectedCategory = first.category
            }
        }
    }
}

struct CleaningProgressView: View {
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                        .frame(height: 6)

                    Rectangle()
                        .fill(FuturisticTheme.softRed)
                        .frame(width: geometry.size.width * appModel.cleanerService.progress, height: 6)
                        .animation(.linear(duration: 0.1), value: appModel.cleanerService.progress)
                }
            }
            .frame(height: 6)

            HStack(spacing: 12) {
                Text("\(Int(appModel.cleanerService.progress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(FuturisticTheme.softRed)

                if appModel.cleanerService.estimatedTimeRemaining > 0 {
                    Text("ETA: \(appModel.cleanerService.formatTimeRemaining(appModel.cleanerService.estimatedTimeRemaining))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(FuturisticTheme.textSecondary)
                }

                Text(appModel.cleanerService.currentFileName)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundColor(FuturisticTheme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Text("\(appModel.cleanerService.filesProcessed) / \(appModel.cleanerService.totalFiles)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(FuturisticTheme.textTertiary)

                Button("STOP") {
                    appModel.cleanerService.cancelCleaning()
                }
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(FuturisticTheme.softRed)
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))
        }
    }
}

struct CategoriesSidebar: View {
    @EnvironmentObject var appModel: AppModel
    @Binding var selectedCategory: CleanupCategory?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("CATEGORIES")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(FuturisticTheme.textPrimary)
                    .kerning(1.5)
                Spacer()
            }
            .padding()

            GlitchDivider(height: 1)

            ScrollView {
                VStack(spacing: 1) {
                    ForEach(appModel.scanResults) { result in
                        let categoryStats = appModel.stats.category(result.category)
                        let remainingSize = categoryStats.activeSize

                        if remainingSize > 0 {
                            Button(action: {
                                selectedCategory = result.category
                            }) {
                                HStack(spacing: 12) {
                                    Toggle("", isOn: Binding(
                                        get: { categoryStats.allSelected },
                                        set: { result.setSelected($0) }
                                    ))
                                    .toggleStyle(CheckboxToggleStyle())

                                    Image(systemName: result.category.icon)
                                        .foregroundColor(selectedCategory == result.category ? FuturisticTheme.softRed : FuturisticTheme.textSecondary)
                                        .font(.system(size: 16))
                                        .frame(width: 20)

                                    Text(result.category.rawValue)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(selectedCategory == result.category ? .white : FuturisticTheme.textPrimary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)

                                    Spacer()

                                    Text(appModel.formatBytes(remainingSize))
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundColor(selectedCategory == result.category ? FuturisticTheme.softRed : FuturisticTheme.textTertiary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    selectedCategory == result.category ?
                                    FuturisticTheme.darkBackground.opacity(0.8) :
                                    Color.clear
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
        }
    }
}

struct GroupedFileListView: View {
    @EnvironmentObject var appModel: AppModel
    var selectedCategory: CleanupCategory?
    @State private var confirmClean = false
    @State private var cleanSummary = ""

    var body: some View {
        VStack(spacing: 0) {
            if let category = selectedCategory,
               let result = appModel.scanResults.first(where: { $0.category == category }) {

                // Header
                HStack(spacing: 14) {
                    Image(systemName: category.icon)
                        .font(.system(size: 24))
                        .foregroundColor(FuturisticTheme.softRed)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.rawValue.uppercased())
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(FuturisticTheme.textPrimary)
                            .kerning(1.2)

                        let categoryStats = appModel.stats.category(category)
                        Text("\(categoryStats.activeCount) items • \(appModel.formatBytes(categoryStats.activeSize))")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(FuturisticTheme.textSecondary)

                        Text(category.description)
                            .font(.system(size: 10))
                            .foregroundColor(FuturisticTheme.textTertiary)
                            .lineLimit(2)
                    }

                    Spacer()
                }
                .padding(16)
                .background(Color.black.opacity(0.6))

                // Select all
                HStack {
                    Spacer()
                    let allSelected = appModel.stats.category(category).allSelected
                    Button(action: {
                        result.setSelected(!allSelected)
                    }) {
                        Text(allSelected ? "DESELECT ALL" : "SELECT ALL")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(FuturisticTheme.softRed)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.4))

                GlitchDivider(height: 1)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(result.groups) { group in
                            FileGroupView(group: group)
                        }
                    }
                    .padding(.vertical, 10)
                }

            } else {
                VStack(spacing: 15) {
                    Image(systemName: "arrow.left.circle")
                        .font(.system(size: 40))
                        .foregroundColor(FuturisticTheme.textSecondary.opacity(0.3))

                    Text("SELECT CATEGORY")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(FuturisticTheme.textSecondary)
                        .kerning(1.5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Bottom Bar
            GlitchDivider(height: 1)

            HStack(spacing: 20) {
                let selectedSize = appModel.selectedSize

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("SELECTED:")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(FuturisticTheme.textSecondary)

                        Text(appModel.formatBytes(selectedSize))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(FuturisticTheme.softRed)

                        Text("across all categories")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(FuturisticTheme.textTertiary)
                    }

                    if let reportText = appModel.lastReportText() {
                        Text("LAST CLEAN: \(reportText)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(FuturisticTheme.textSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Button(action: {
                    cleanSummary = appModel.cleanupSummary()
                    confirmClean = true
                }) {
                    Text(appModel.cleanerService.isCleaning ? "CLEANING" : "CLEAN SELECTED")
                        .frame(minWidth: 150)
                }
                .buttonStyle(PremiumButtonStyle(color: FuturisticTheme.softRed, isGlowing: true))
                .disabled(appModel.cleanerService.isCleaning || selectedSize == 0)
            }
            .padding(16)
            .background(FuturisticTheme.darkBackground)
        }
        .alert("Clean \(appModel.formatBytes(appModel.selectedSize))?", isPresented: $confirmClean) {
            Button("Clean", role: .destructive) {
                Task { await appModel.performCleanup() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(cleanSummary)
        }
    }
}

struct FileGroupView: View {
    @ObservedObject var group: ScanGroup
    @EnvironmentObject var appModel: AppModel
    var depth: Int = 0

    var body: some View {
        if group.hasActiveItems {
            VStack(spacing: 0) {
                // Group header
                HStack(spacing: 12) {
                    Toggle("", isOn: Binding(
                        get: { group.isAllSelected },
                        set: { group.toggleSelection($0) }
                    ))
                    .toggleStyle(CheckboxToggleStyle())

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            group.isExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: group.subgroups.isEmpty
                                  ? (group.isExpanded ? "folder.fill" : "folder")
                                  : (group.isExpanded ? "square.stack.3d.up.fill" : "square.stack.3d.up"))
                                .foregroundColor(FuturisticTheme.textSecondary)
                                .font(.system(size: 14))

                            Text(group.name)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(FuturisticTheme.textPrimary)
                                .lineLimit(1)

                            Text("\(group.activeCount)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(FuturisticTheme.textTertiary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    Spacer()

                    if group.subgroups.isEmpty {
                        Button(action: {
                            if let firstItem = group.items.first {
                                let folderPath = (firstItem.path as NSString).deletingLastPathComponent
                                let pasteboard = NSPasteboard.general
                                pasteboard.clearContents()
                                pasteboard.setString(folderPath, forType: .string)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                Text("COPY PATH")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundColor(FuturisticTheme.textTertiary)
                            .padding(4)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .help("Copy folder path")
                    }

                    Text(appModel.formatBytes(group.activeSize))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(FuturisticTheme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(FuturisticTheme.darkBackground.opacity(0.5))

                if group.isExpanded {
                    if group.subgroups.isEmpty {
                        LazyVStack(spacing: 1) {
                            ForEach(group.items) { item in
                                if item.isActive {
                                    FileItemView(item: item)
                                }
                            }
                        }
                        .transition(.opacity)
                    } else {
                        // The "small folders" bucket: each small folder as its own collapsible group.
                        LazyVStack(spacing: 6) {
                            ForEach(group.subgroups) { subgroup in
                                // AnyView breaks the recursive type (a group view inside a group view).
                                AnyView(FileGroupView(group: subgroup, depth: depth + 1))
                            }
                        }
                        .padding(.vertical, 6)
                        .transition(.opacity)
                    }
                }
            }
            .background(Color.black.opacity(0.2))
            .cornerRadius(6)
            .padding(.horizontal, depth == 0 ? 10 : 0)
            .padding(.leading, depth == 0 ? 0 : 18)
        }
    }
}

struct FileItemView: View {
    @ObservedObject var item: ScanItem
    @EnvironmentObject var appModel: AppModel

    var body: some View {
        HStack(spacing: 12) {
            Spacer().frame(width: 20)

            if item.status == .skipped {
                Image(systemName: "exclamationmark.shield")
                    .foregroundColor(.yellow)
                    .font(.system(size: 12))
                    .help("Skipped for safety: \(item.note ?? "")")
            } else if item.status == .error {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
                    .help("Couldn't delete: \(item.note ?? "")")
            } else {
                Toggle("", isOn: $item.isSelected)
                    .toggleStyle(CheckboxToggleStyle())
                    .disabled(item.status == .deleted)
            }

            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundColor(item.status == .skipped ? .yellow.opacity(0.4) : FuturisticTheme.softRed.opacity(0.4))
                .font(.system(size: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(item.status == .skipped ? .secondary : FuturisticTheme.textPrimary.opacity(0.9))
                    .strikethrough(item.status == .deleted)
                    .lineLimit(1)

                Text(item.note.map { "\(item.path) — \($0)" } ?? item.path)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(FuturisticTheme.textTertiary.opacity(0.5))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button(action: {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(item.path, forType: .string)
            }) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundColor(FuturisticTheme.textTertiary)
            }
            .buttonStyle(PlainButtonStyle())
            .help("Copy file path")
            .padding(.trailing, 4)

            Text(appModel.formatBytes(item.size))
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(FuturisticTheme.textTertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(item.isSelected ? FuturisticTheme.softRed.opacity(0.05) : Color.clear)
        .opacity(item.status == .deleted ? 0.5 : 1.0)
    }
}

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button(action: {
            configuration.isOn.toggle()
        }) {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? FuturisticTheme.softRed : FuturisticTheme.textTertiary)
                .font(.system(size: 14))
        }
        .buttonStyle(PlainButtonStyle())
    }
}
