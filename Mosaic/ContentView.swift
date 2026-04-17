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

    // MARK: - iOS

    #if os(iOS)
    private var iOSLayout: some View {
        ZStack {
            MosaicTheme.ink.ignoresSafeArea()

            VStack(spacing: 0) {
                CanvasStage()
                    .frame(maxHeight: .infinity)
            }
            .safeAreaInset(edge: .top) {
                TopBar()
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    if vm.slideCount > 1 {
                        SlideStrip()
                            .padding(.horizontal, 14)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if vm.activePanel != .none {
                        ToolPanelHost()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    ToolPalette()
                        .padding(.horizontal, 16)
                        .padding(.bottom, 6)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $vm.showingExport) {
            ExportSheet()
                .environmentObject(vm)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(.clear)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: vm.activePanel)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: vm.slideCount)
    }
    #endif

    // MARK: - macOS

    #if os(macOS)
    private var macOSLayout: some View {
        HStack(spacing: 0) {
            // Left rail — slides
            VStack(spacing: 0) {
                Text("SLIDES")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(MosaicTheme.stone)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                ScrollView {
                    SlideStackVertical()
                        .padding(.horizontal, 10)
                        .padding(.bottom, 20)
                }
            }
            .frame(width: 160)
            .background(MosaicTheme.surface)

            Divider().background(MosaicTheme.graphite)

            // Canvas
            ZStack {
                MosaicTheme.ink
                CanvasStage()
                    .frame(maxHeight: .infinity)
            }
            .safeAreaInset(edge: .top) {
                TopBar()
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    if vm.activePanel != .none {
                        ToolPanelHost()
                    }
                    ToolPalette()
                        .padding(.horizontal, 18)
                        .padding(.bottom, 10)
                }
            }
        }
        .sheet(isPresented: $vm.showingExport) {
            ExportSheet()
                .environmentObject(vm)
                .frame(minWidth: 520, minHeight: 560)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: vm.activePanel)
        .frame(minWidth: 900, minHeight: 700)
    }
    #endif
}

// MARK: - Top bar — aspect picker is the hero, glass everywhere

private struct TopBar: View {
    @EnvironmentObject var vm: CollageViewModel
    @Namespace private var aspectGlass

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                // Aspect ratio picker — expanded to take the freed space
                HStack(spacing: 0) {
                    ForEach(SlideAspect.allCases) { a in
                        aspectSegment(a)
                    }
                }
                .padding(4)
                .frame(maxWidth: .infinity)
                .glassEffect(.regular.interactive(), in: .capsule)

                // Edit-grid toggle
                Button {
                    vm.isEditingGrid.toggle()
                } label: {
                    Image(systemName: vm.isEditingGrid ? "rectangle.dashed" : "rectangle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(vm.isEditingGrid ? MosaicTheme.saffron : MosaicTheme.cream)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)

                // Export — prominent
                Button {
                    vm.exportAllSlides()
                } label: {
                    Label("Export", systemImage: "arrow.up.forward.square.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.system(size: 13, weight: .bold))
                }
                .buttonStyle(.glassProminent)
                .tint(MosaicTheme.saffron)
            }
        }
    }

    @ViewBuilder
    private func aspectSegment(_ a: SlideAspect) -> some View {
        let isOn = vm.aspect == a
        let button = Button {
            withAnimation(.bouncy(duration: 0.35)) { vm.setAspect(a) }
        } label: {
            VStack(spacing: 2) {
                Text(a.shortLabel)
                    .font(.system(size: 12, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(isOn ? MosaicTheme.ink : MosaicTheme.cream)
                Text(a.label)
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(isOn ? MosaicTheme.ink.opacity(0.7) : MosaicTheme.stone)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)

        if isOn {
            button
                .glassEffect(.regular.tint(MosaicTheme.saffron).interactive(), in: .capsule)
                .glassEffectID("aspectThumb", in: aspectGlass)
        } else {
            button
        }
    }
}

// MARK: - Canvas stage

private struct CanvasStage: View {
    @EnvironmentObject var vm: CollageViewModel

    var body: some View {
        GeometryReader { geo in
            let pad: CGFloat = 16
            let available = CGSize(
                width: max(geo.size.width - pad * 2, 100),
                height: max(geo.size.height - pad * 2, 100)
            )
            let ratio = vm.aspect.ratio
            // Fit aspect into available
            let (w, h): (CGFloat, CGFloat) = {
                let fitByWidth = (available.width, available.width / ratio)
                let fitByHeight = (available.height * ratio, available.height)
                return fitByWidth.1 <= available.height ? fitByWidth : fitByHeight
            }()

            VStack {
                Spacer(minLength: 0)
                HStack {
                    Spacer(minLength: 0)
                    CollageCanvasView(canvasWidth: w, canvasHeight: h)
                        .environmentObject(vm)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: .black.opacity(0.45), radius: 24, y: 8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(MosaicTheme.graphite.opacity(0.6), lineWidth: 0.5)
                        )
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 0)
            }
            .padding(pad)
        }
    }
}

// MARK: - Tool palette — true Liquid Glass

private struct ToolPalette: View {
    @EnvironmentObject var vm: CollageViewModel
    @Namespace private var paletteGlass

    var body: some View {
        GlassEffectContainer(spacing: 6) {
            HStack(spacing: 0) {
                paletteButton(panel: .layout, icon: "square.grid.3x3", label: "Grid")
                paletteButton(panel: .layers, icon: "square.3.layers.3d.top.filled", label: "Layers")
                paletteButton(panel: .slides, icon: "rectangle.stack", label: "Slides")
                paletteButton(panel: .style,  icon: "paintbrush.pointed", label: "Style")
            }
            .padding(4)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .frame(maxWidth: 540)
    }

    @ViewBuilder
    private func paletteButton(panel: CollageViewModel.ToolPanel, icon: String, label: String) -> some View {
        let selected = vm.activePanel == panel
        let button = Button {
            withAnimation(.bouncy(duration: 0.35)) {
                vm.activePanel = (vm.activePanel == panel) ? .none : panel
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.5)
            }
            .foregroundStyle(selected ? MosaicTheme.ink : MosaicTheme.cream)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)

        if selected {
            button
                .glassEffect(.regular.tint(MosaicTheme.saffron).interactive(), in: .capsule)
                .glassEffectID("paletteThumb", in: paletteGlass)
        } else {
            button
        }
    }
}

// MARK: - Active panel host

private struct ToolPanelHost: View {
    @EnvironmentObject var vm: CollageViewModel

    var body: some View {
        Group {
            switch vm.activePanel {
            case .layout: LayoutPanel()
            case .layers: LayersPanel()
            case .slides: SlidesPanel()
            case .style:  StylePanel()
            case .none:   EmptyView()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 22))
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
    }
}

// MARK: - Layout panel (grid presets + rows/cols steppers + merge hint)

private struct LayoutPanel: View {
    @EnvironmentObject var vm: CollageViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("PRESETS")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(GridPreset.allCases) { p in
                        Button { vm.applyPreset(p) } label: {
                            VStack(spacing: 4) {
                                Image(systemName: p.icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(MosaicTheme.cream)
                                Text(p.label)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(MosaicTheme.stone)
                            }
                            .frame(width: 60, height: 56)
                            .background(MosaicTheme.charcoal)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 10) {
                stepper(label: "ROWS", value: vm.currentSlide.grid.rows) { delta in
                    vm.setRows(vm.currentSlide.grid.rows + delta)
                }
                stepper(label: "COLS", value: vm.currentSlide.grid.cols) { delta in
                    vm.setCols(vm.currentSlide.grid.cols + delta)
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .tracking(3)
            .foregroundStyle(MosaicTheme.stone)
    }

    private func stepper(label: String, value: Int, onChange: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .tracking(2)
                .foregroundStyle(MosaicTheme.stone)
            Spacer(minLength: 4)
            Button { onChange(-1) } label: { stepIcon("minus") }.buttonStyle(.plain)
            Text("\(value)")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(MosaicTheme.cream)
                .frame(minWidth: 22)
            Button { onChange(1) } label: { stepIcon("plus") }.buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    private func stepIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(MosaicTheme.saffron)
            .frame(width: 20, height: 20)
            .background(MosaicTheme.graphite)
            .clipShape(Circle())
    }
}

// MARK: - Layers panel

private struct LayersPanel: View {
    @EnvironmentObject var vm: CollageViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LAYERS")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(MosaicTheme.stone)
                Spacer()
                Button {
                    vm.beginPickingNewLayer()
                } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(MosaicTheme.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(MosaicTheme.saffron)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if vm.currentSlide.layers.isEmpty {
                Text("No layers. Tap Add to stack a photo on top of the grid.")
                    .font(.system(size: 11))
                    .foregroundStyle(MosaicTheme.stone)
                    .padding(.vertical, 8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(vm.currentSlide.layers.sorted(by: { $0.zIndex > $1.zIndex })) { layer in
                            LayerTile(layer: layer)
                        }
                    }
                }
            }

            if let selected = vm.selectedLayer {
                selectedLayerControls(selected)
            }
        }
    }

    private func selectedLayerControls(_ layer: PhotoLayer) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                smallButton("arrow.up", "Forward") {
                    vm.bringLayerForward(layer.id)
                }
                smallButton("arrow.down", "Back") {
                    vm.sendLayerBackward(layer.id)
                }
                smallButton("trash", "Delete", tint: MosaicTheme.ember) {
                    vm.deleteLayer(layer.id)
                }
                Spacer()
            }
            slider(label: "OPACITY", value: Binding(
                get: { layer.opacity },
                set: { new in vm.updateLayer(layer.id) { $0.opacity = new } }
            ), range: 0.1...1.0)
            slider(label: "ROUND", value: Binding(
                get: { Double(layer.cornerRadius) },
                set: { new in vm.updateLayer(layer.id) { $0.cornerRadius = CGFloat(new) } }
            ), range: 0...60)
            slider(label: "ROTATE", value: Binding(
                get: { layer.rotation.degrees },
                set: { new in vm.updateLayer(layer.id) { $0.rotation = .degrees(new) } }
            ), range: -180...180)
        }
    }

    private func smallButton(_ icon: String, _ label: String, tint: Color = MosaicTheme.graphite, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .bold))
                Text(label).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(MosaicTheme.cream)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func slider(label: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(2)
                .foregroundStyle(MosaicTheme.stone)
                .frame(width: 52, alignment: .leading)
            Slider(value: value, in: range)
                .tint(MosaicTheme.saffron)
        }
    }
}

private struct LayerTile: View {
    @EnvironmentObject var vm: CollageViewModel
    let layer: PhotoLayer

    private var isSelected: Bool {
        if case let .layer(_, id) = vm.selection { return id == layer.id }
        return false
    }

    var body: some View {
        Button {
            vm.selection = .layer(slide: vm.currentSlide.id, layerId: layer.id)
        } label: {
            ZStack {
                #if os(macOS)
                Image(nsImage: layer.image).resizable().aspectRatio(contentMode: .fill)
                #else
                Image(uiImage: layer.image).resizable().aspectRatio(contentMode: .fill)
                #endif
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? MosaicTheme.saffron : MosaicTheme.graphite,
                                  lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Slides panel

private struct SlidesPanel: View {
    @EnvironmentObject var vm: CollageViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CAROUSEL")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(MosaicTheme.stone)
                Text("\(vm.slideCount) / 10")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(MosaicTheme.stone.opacity(0.6))
                Spacer()
                Button { vm.duplicateCurrentSlide() } label: {
                    Label("Duplicate", systemImage: "square.on.square")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MosaicTheme.cream)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(MosaicTheme.graphite)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(vm.slideCount >= 10)

                Button { vm.addSlide() } label: {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(MosaicTheme.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(MosaicTheme.saffron)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(vm.slideCount >= 10)
            }

            Text("Instagram carousel: go Portrait (4:5) for max canvas.")
                .font(.system(size: 10))
                .foregroundStyle(MosaicTheme.stone)

            if vm.slideCount > 1 {
                Button {
                    vm.removeCurrentSlide()
                } label: {
                    Label("Remove current slide", systemImage: "trash")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MosaicTheme.ember)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Style panel

private struct StylePanel: View {
    @EnvironmentObject var vm: CollageViewModel

    private let palette: [(String, Color)] = [
        ("Ink",       Color(hex: "0D0D0D")),
        ("Charcoal",  Color(hex: "1C1C1E")),
        ("Slate",     Color(hex: "2C3E50")),
        ("Midnight",  Color(hex: "191970")),
        ("Wine",      Color(hex: "3C1518")),
        ("Forest",    Color(hex: "1B2A1B")),
        ("Cream",     Color(hex: "F5F0EB")),
        ("White",     Color(hex: "FFFFFF")),
        ("Saffron",   Color(hex: "E8A838")),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            labeledSlider(label: "SPACING",
                          value: Binding(get: { Double(vm.document.spacing) },
                                         set: { vm.setSpacing(CGFloat($0)) }),
                          range: 0...40,
                          suffix: "pt")
            labeledSlider(label: "CORNERS",
                          value: Binding(get: { Double(vm.document.cornerRadius) },
                                         set: { vm.setCornerRadius(CGFloat($0)) }),
                          range: 0...60,
                          suffix: "pt")

            Text("BACKGROUND")
                .font(.system(size: 9, weight: .bold))
                .tracking(3)
                .foregroundStyle(MosaicTheme.stone)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 38, maximum: 50), spacing: 10)],
                spacing: 10
            ) {
                ForEach(palette, id: \.0) { name, color in
                    Button { vm.setBackground(color) } label: {
                        Circle()
                            .fill(color)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle().strokeBorder(
                                    sameColor(color, vm.document.backgroundColor) ? MosaicTheme.saffron : MosaicTheme.graphite,
                                    lineWidth: sameColor(color, vm.document.backgroundColor) ? 2 : 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func labeledSlider(label: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(MosaicTheme.stone)
                Spacer()
                Text("\(Int(value.wrappedValue))\(suffix)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MosaicTheme.cream)
            }
            Slider(value: value, in: range).tint(MosaicTheme.saffron)
        }
    }

    private func sameColor(_ a: Color, _ b: Color) -> Bool {
        a.description == b.description
    }
}

// MARK: - Slide strip (iOS)

private struct SlideStrip: View {
    @EnvironmentObject var vm: CollageViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(vm.document.slides.enumerated()), id: \.element.id) { idx, slide in
                    SlideThumb(index: idx, slide: slide, isCurrent: idx == vm.currentSlideIndex) {
                        vm.selectSlide(idx)
                    }
                }
                Button { vm.addSlide() } label: {
                    VStack {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(MosaicTheme.saffron)
                    }
                    .frame(width: 50, height: 62)
                    .background(MosaicTheme.charcoal)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(MosaicTheme.saffron.opacity(0.4),
                                          style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(vm.slideCount >= 10)
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Slide vertical stack (macOS left rail)

private struct SlideStackVertical: View {
    @EnvironmentObject var vm: CollageViewModel
    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(vm.document.slides.enumerated()), id: \.element.id) { idx, slide in
                SlideThumb(index: idx, slide: slide, isCurrent: idx == vm.currentSlideIndex) {
                    vm.selectSlide(idx)
                }
            }
            Button { vm.addSlide() } label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MosaicTheme.saffron)
                    .frame(width: 120, height: 30)
                    .background(MosaicTheme.charcoal)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .disabled(vm.slideCount >= 10)
        }
    }
}

private struct SlideThumb: View {
    let index: Int
    let slide: Slide
    let isCurrent: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GeometryReader { geo in
                let s = geo.size
                ZStack {
                    MosaicTheme.ink
                    ForEach(slide.grid.regions) { region in
                        let rect = slide.grid.rect(for: region, in: s, spacing: 2)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(
                                slide.grid.cellPhotos[region.origin] != nil
                                    ? MosaicTheme.saffron.opacity(isCurrent ? 0.55 : 0.25)
                                    : MosaicTheme.graphite
                            )
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                    }
                    Text("\(index + 1)")
                        .font(.system(size: 9, weight: .black))
                        .foregroundStyle(isCurrent ? MosaicTheme.ink : MosaicTheme.cream)
                        .padding(3)
                        .background(isCurrent ? MosaicTheme.saffron : MosaicTheme.graphite)
                        .clipShape(Capsule())
                        .padding(4)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
            .frame(width: 50, height: 62)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isCurrent ? MosaicTheme.saffron : MosaicTheme.graphite,
                                  lineWidth: isCurrent ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}
