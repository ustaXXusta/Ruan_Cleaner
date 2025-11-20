import SwiftUI

struct ScanResultsView: View {
    @EnvironmentObject var appModel: AppModel
    @State private var selectedCategory: CleanupCategory?
    
    var body: some View {
        ZStack {
            // Background
            MatrixRainView()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // TOP PROGRESS BAR - Always visible when cleaning
                if appModel.cleanerService.isCleaning {
                    CleaningProgressView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                // Main content
                HStack(spacing: 0) {
                    // Sidebar Column (Categories + Metrics)
                    // Fixed width, non-draggable
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            // Categories (Top 50%)
                            CategoriesSidebar(selectedCategory: $selectedCategory)
                                .frame(height: geo.size.height * 0.5)
                            
                            GlitchDivider(height: 2)
                            
                            // Metrics (Bottom 50%)
                            SystemMetricsView()
                                .frame(height: geo.size.height * 0.5)
                        }
                    }
                    .frame(width: 300) // Fixed width as requested
                    .background(Color.black.opacity(0.4)) // Semi-transparent sidebar
                    
                    GlitchDivider(height: 1, isVertical: true)
                    
                    // Detail View (Full Height)
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
                    // Background
                    Rectangle()
                        .fill(Color(red: 0.15, green: 0.15, blue: 0.15))
                        .frame(height: 6)
                    
                    // Progress fill
                    Rectangle()
                        .fill(FuturisticTheme.softRed)
                        .frame(width: geometry.size.width * appModel.cleanerService.progress, height: 6)
                        .animation(.linear(duration: 0.1), value: appModel.cleanerService.progress)
                }
            }
            .frame(height: 6)
            
            // Progress info bar
            HStack(spacing: 12) {
                Text("\(Int(appModel.cleanerService.progress * 100))%")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(FuturisticTheme.softRed)
                
                if appModel.cleanerService.estimatedTimeRemaining > 0 {
                    Text("ETA: \(appModel.cleanerService.formatTimeRemaining(appModel.cleanerService.estimatedTimeRemaining))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(FuturisticTheme.textSecondary)
                }
                
                Spacer()
                
                Text("\(appModel.cleanerService.filesProcessed) / \(appModel.cleanerService.totalFiles)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(FuturisticTheme.textTertiary)
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
            .background(Color.clear)
            
            GlitchDivider(height: 1)
            
            ScrollView {
                VStack(spacing: 1) {
                    ForEach(appModel.scanResults) { result in
                        // Calculate remaining size dynamically
                        let remainingSize = result.items.filter { $0.status != .deleted }.reduce(0) { $0 + $1.size }
                        
                        if remainingSize > 0 {
                            Button(action: {
                                selectedCategory = result.category
                            }) {
                                HStack(spacing: 12) {
                                    // Category Checkbox
                                    Toggle("", isOn: Binding(
                                        get: { 
                                            // Check if all items in this category are selected
                                            result.items.filter { $0.status != .deleted }.allSatisfy { $0.isSelected }
                                        },
                                        set: { isSelected in
                                            // Select/Deselect all items in this category
                                            for item in result.items {
                                                if item.status != .deleted {
                                                    item.isSelected = isSelected
                                                }
                                            }
                                            // Force UI update
                                            appModel.objectWillChange.send()
                                        }
                                    ))
                                    .toggleStyle(CheckboxToggleStyle())
                                    
                                    Image(systemName: result.category.icon)
                                        .foregroundColor(selectedCategory == result.category ? FuturisticTheme.softRed : FuturisticTheme.textSecondary)
                                        .font(.system(size: 16))
                                        .frame(width: 20)
                                    
                                    Text(result.category.rawValue)
                                        .font(.system(size: 13, weight: .medium, design: .rounded))
                                        .foregroundColor(selectedCategory == result.category ? .white : FuturisticTheme.textPrimary)
                                    
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
            .background(Color.clear)
        }
    }
}

struct GroupedFileListView: View {
    @EnvironmentObject var appModel: AppModel
    var selectedCategory: CleanupCategory?
    
    var body: some View {
        ZStack {
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
                            
                            let activeItems = result.items.filter { $0.status != .deleted }
                            Text("\(activeItems.count) items • \(appModel.formatBytes(activeItems.reduce(0) { $0 + $1.size }))")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(FuturisticTheme.textSecondary)
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.black.opacity(0.6)) // Semi-transparent header
                    
                    // Sub-header with Select All
                    HStack {
                        Spacer()
                        Button(action: {
                            let allSelected = result.items.filter { $0.status != .deleted }.allSatisfy { $0.isSelected }
                            for item in result.items {
                                if item.status != .deleted {
                                    item.isSelected = !allSelected
                                }
                            }
                            appModel.objectWillChange.send()
                        }) {
                            Text(result.items.filter { $0.status != .deleted }.allSatisfy { $0.isSelected } ? "DESELECT ALL" : "SELECT ALL")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(FuturisticTheme.softRed)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.4)) // Semi-transparent subheader
                    
                    GlitchDivider(height: 1)
                    
                    // Grouped List
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(result.groups) { group in
                                FileGroupView(group: group)
                            }
                        }
                        .padding(.vertical, 10)
                    }
                    .background(Color.clear) // Transparent to show city background
                    
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
                    // Summary of selected items
                    let selectedSize = appModel.scanResults.flatMap { $0.items }
                        .filter { $0.isSelected && $0.status != .deleted }
                        .reduce(0) { $0 + $1.size }
                    
                    HStack(spacing: 8) {
                        Text("SELECTED:")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(FuturisticTheme.textSecondary)
                        
                        Text(appModel.formatBytes(selectedSize))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(FuturisticTheme.softRed)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Task {
                            await appModel.performRealCleanup()
                        }
                    }) {
                        Text(appModel.cleanerService.isCleaning ? "CLEANING..." : "CLEAN SELECTED")
                            .font(.system(size: 13, weight: .bold))
                            .frame(minWidth: 140)
                    }
                    .buttonStyle(PremiumButtonStyle(color: FuturisticTheme.softRed, isGlowing: true))
                    .disabled(appModel.cleanerService.isCleaning || selectedSize == 0)
                }
                .padding(16)
                .background(FuturisticTheme.darkBackground)
            }
        }
    }
}

struct FileGroupView: View {
    @ObservedObject var group: ScanGroup
    @EnvironmentObject var appModel: AppModel
    
    var body: some View {
        // Only show group if it has non-deleted items
        if group.items.contains(where: { $0.status != .deleted }) {
            VStack(spacing: 0) {
                // Group Header
                HStack(spacing: 12) {
                    // Checkbox for batch selection (Replaces arrow as primary left element)
                    Toggle("", isOn: Binding(
                        get: { group.isAllSelected },
                        set: { group.toggleSelection($0) }
                    ))
                    .toggleStyle(CheckboxToggleStyle())
                    
                    // Expand/Collapse Trigger (Name + Icon)
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            group.isExpanded.toggle()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: group.isExpanded ? "folder.fill" : "folder")
                                .foregroundColor(FuturisticTheme.textSecondary)
                                .font(.system(size: 14))
                            
                            Text(group.name)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundColor(FuturisticTheme.textPrimary)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    // Copy Path Button
                    Button(action: {
                        // Copy path of the first item's parent folder
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
                    
                    Text(appModel.formatBytes(group.totalSize))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(FuturisticTheme.textSecondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(FuturisticTheme.darkBackground.opacity(0.5))
                
                // Group Items
                if group.isExpanded {
                    LazyVStack(spacing: 1) {
                        ForEach(group.items) { item in
                            if item.status != .deleted {
                                FileItemView(item: item)
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
            .background(Color.black.opacity(0.2))
            .cornerRadius(6)
            .padding(.horizontal, 10)
        }
    }
}

struct FileItemView: View {
    @ObservedObject var item: ScanItem
    @EnvironmentObject var appModel: AppModel
    
    var body: some View {
        HStack(spacing: 12) {
            Spacer().frame(width: 20) // Indent
            
            if item.status == .skipped {
                Image(systemName: "exclamationmark.shield")
                    .foregroundColor(.yellow)
                    .font(.system(size: 12))
                    .help("Skipped for safety")
            } else if item.status == .error {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.red)
                    .font(.system(size: 12))
                    .help("Error deleting file")
            } else {
                Toggle("", isOn: $item.isSelected)
                    .toggleStyle(CheckboxToggleStyle())
                    .disabled(item.status == .deleted)
            }
            
            Image(systemName: "doc.fill")
                .foregroundColor(item.status == .skipped ? .yellow.opacity(0.4) : FuturisticTheme.softRed.opacity(0.4))
                .font(.system(size: 12))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(item.status == .skipped ? .secondary : FuturisticTheme.textPrimary.opacity(0.9))
                    .strikethrough(item.status == .deleted)
                    .lineLimit(1)
                
                Text(item.path)
                    .font(.system(size: 9, weight: .regular, design: .monospaced))
                    .foregroundColor(FuturisticTheme.textTertiary.opacity(0.5))
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Copy Path Button
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
