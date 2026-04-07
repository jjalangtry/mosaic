import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: CollageViewModel

    var body: some View {
        #if os(macOS)
        macOSLayout
        #else
        iOSLayout
        #endif
    }

    // MARK: - macOS: Sidebar + Canvas + Inspector

    #if os(macOS)
    private var macOSLayout: some View {
        NavigationSplitView {
            LayoutSidebarView()
                .environmentObject(vm)
                .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 280)
        } detail: {
            HStack(spacing: 0) {
                // Canvas area
                ZStack {
                    MosaicTheme.ink
                    noiseOverlay

                    VStack(spacing: 0) {
                        macOSToolbar
                        canvasAreaMacOS
                    }
                }

                // Inspector
                if vm.showInspector {
                    Divider()
                    InspectorView()
                        .environmentObject(vm)
                        .frame(width: 260)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var macOSToolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text("MOSAIC")
                    .font(.system(size: 16, weight: .black))
                    .tracking(5)
                    .foregroundStyle(MosaicTheme.cream)
                Text("collage studio")
                    .font(.system(size: 10, weight: .medium, design: .serif))
                    .foregroundStyle(MosaicTheme.stone)
                    .italic()
            }

            Spacer()

            HStack(spacing: 8) {
                // Inspector toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        vm.showInspector.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.trailing")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(vm.showInspector ? MosaicTheme.saffron : MosaicTheme.stone)
                        .frame(width: 32, height: 28)
                        .glassBackground()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)

                // Export
                Button {
                    vm.exportForInstagram()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11, weight: .bold))
                        Text("Export")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundStyle(MosaicTheme.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(MosaicTheme.saffronGradient)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(MosaicTheme.surface.opacity(0.8))
        .overlay(alignment: .bottom) {
            Rectangle().fill(MosaicTheme.graphite.opacity(0.4)).frame(height: 0.5)
        }
    }

    private var canvasAreaMacOS: some View {
        GeometryReader { geo in
            let padding: CGFloat = 48
            let maxSide = min(geo.size.width - padding * 2, geo.size.height - padding * 2)
            let side = max(maxSide, 300)

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    CollageCanvasView(canvasSize: side)
                        .environmentObject(vm)
                        .frame(width: side, height: side)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.6), radius: 40, y: 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(MosaicTheme.graphite.opacity(0.4), lineWidth: 0.5)
                        )
                    Spacer()
                }
                Spacer()
            }
        }
        .sheet(isPresented: $vm.showingExport) {
            ExportSheet()
                .environmentObject(vm)
                .frame(minWidth: 440, minHeight: 520)
        }
    }
    #endif

    // MARK: - iOS Layout

    #if os(iOS)
    private var iOSLayout: some View {
        ZStack {
            MosaicTheme.ink.ignoresSafeArea()
            noiseOverlay.ignoresSafeArea()

            VStack(spacing: 0) {
                iOSHeader
                canvasAreaiOS
                iOSControlsBar
            }
        }
        .sheet(isPresented: $vm.showingExport) {
            ExportSheet()
                .environmentObject(vm)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(MosaicTheme.surface)
        }
    }

    private var iOSHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("MOSAIC")
                    .font(.system(size: 22, weight: .black))
                    .tracking(6)
                    .foregroundStyle(MosaicTheme.cream)
                Text("collage studio")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(MosaicTheme.stone)
                    .italic()
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var canvasAreaiOS: some View {
        GeometryReader { geo in
            let side = min(geo.size.width - 40, geo.size.height - 20)
            VStack {
                Spacer()
                CollageCanvasView(canvasSize: side)
                    .environmentObject(vm)
                    .frame(width: side, height: side)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(MosaicTheme.graphite.opacity(0.5), lineWidth: 0.5)
                    )
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    @State private var showSettings = false
    @State private var showLayoutPicker = false

    private var iOSControlsBar: some View {
        VStack(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CollageLayout.allLayouts) { layout in
                        LayoutChip(
                            layout: layout,
                            isSelected: vm.selectedLayout.id == layout.id
                        ) {
                            vm.selectLayout(layout)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            HStack(spacing: 12) {
                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "slider.horizontal.3")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MosaicTheme.cream)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .glassBackground()
                        .clipShape(Capsule())
                }

                Spacer()

                Button {
                    vm.exportForInstagram()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 13, weight: .bold))
                        Text("Export")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundStyle(MosaicTheme.ink)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(MosaicTheme.saffronGradient)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .background(
            MosaicTheme.surface
                .overlay(
                    LinearGradient(
                        colors: [MosaicTheme.graphite.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea(edges: .bottom)
        )
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .environmentObject(vm)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(MosaicTheme.surface)
        }
    }
    #endif

    // MARK: - Shared

    private var noiseOverlay: some View {
        StaticNoiseView()
            .allowsHitTesting(false)
    }
}

// Renders once and never redraws — prevents animation-driven Canvas churn
struct StaticNoiseView: View, Equatable {
    nonisolated static func == (lhs: StaticNoiseView, rhs: StaticNoiseView) -> Bool { true }

    var body: some View {
        Canvas { context, size in
            for _ in 0..<600 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...size.height)
                context.opacity = Double.random(in: 0.02...0.06)
                context.fill(
                    Path(CGRect(x: x, y: y, width: 1, height: 1)),
                    with: .color(.white)
                )
            }
        }
        .drawingGroup()
    }
}

// MARK: - Layout Chip (iOS)

struct LayoutChip: View {
    let layout: CollageLayout
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: layout.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? MosaicTheme.saffron : MosaicTheme.stone)
                Text("\(layout.photoCount)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(isSelected ? MosaicTheme.cream : MosaicTheme.stone.opacity(0.7))
            }
            .frame(width: 52, height: 52)
            .background(isSelected ? MosaicTheme.graphite : MosaicTheme.charcoal.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(
                        isSelected ? MosaicTheme.saffron.opacity(0.5) : .clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}
