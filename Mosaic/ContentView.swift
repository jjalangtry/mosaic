import SwiftUI

struct ContentView: View {
    @EnvironmentObject var vm: CollageViewModel
    @State private var showLayoutPicker = false
    @State private var showSettings = false
    @Namespace private var heroNS

    var body: some View {
        ZStack {
            // Layered background
            MosaicTheme.ink
                .ignoresSafeArea()

            // Subtle grain texture via noise overlay
            Canvas { context, size in
                for _ in 0..<600 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let opacity = Double.random(in: 0.02...0.06)
                    context.opacity = opacity
                    context.fill(
                        Path(CGRect(x: x, y: y, width: 1, height: 1)),
                        with: .color(.white)
                    )
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                headerBar
                canvasArea
                controlsBar
            }
        }
        .sheet(isPresented: $showLayoutPicker) {
            LayoutPickerSheet()
                .environmentObject(vm)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(MosaicTheme.surface)
        }
        .sheet(isPresented: $vm.showingExport) {
            ExportSheet()
                .environmentObject(vm)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(MosaicTheme.surface)
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheet()
                .environmentObject(vm)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(MosaicTheme.surface)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("MOSAIC")
                    .font(.system(size: 22, weight: .black, design: .default))
                    .tracking(6)
                    .foregroundStyle(MosaicTheme.cream)

                Text("collage studio")
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(MosaicTheme.stone)
                    .italic()
            }

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(MosaicTheme.stone)
                    .frame(width: 40, height: 40)
                    .glassBackground()
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - Canvas

    private var canvasArea: some View {
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

    // MARK: - Controls Bar

    private var controlsBar: some View {
        VStack(spacing: 12) {
            // Layout quick-scroll
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
                    showLayoutPicker = true
                } label: {
                    Label("Layouts", systemImage: "square.grid.2x2")
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
    }
}

// MARK: - Layout Chip

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
