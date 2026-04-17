import SwiftUI
import PhotosUI

// MARK: - Canvas

// Renders one slide: background → grid regions (with their photos) → free layers.
// When grid editing is active, divider + intersection handles sit on top.
struct CollageCanvasView: View {
    @EnvironmentObject var vm: CollageViewModel
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat

    private var slide: Slide { vm.currentSlide }
    private var size: CGSize { CGSize(width: canvasWidth, height: canvasHeight) }

    var body: some View {
        ZStack {
            // Background — tapping the background (not dividers/cells/layers) deselects.
            vm.document.backgroundColor
                .onTapGesture { vm.selection = .none }

            // Grid regions
            ForEach(slide.grid.regions) { region in
                let rect = slide.grid.rect(for: region, in: size, spacing: vm.document.spacing)
                GridRegionView(
                    region: region,
                    rect: rect,
                    cornerRadius: vm.document.cornerRadius,
                    photo: slide.grid.cellPhotos[region.origin],
                    isSelected: isCellSelected(region.origin),
                    mergeMode: mergeMode,
                    onTap: { handleRegionTap(region) },
                    onPhotoTransform: { offset, scale in
                        vm.updateCellPhotoTransform(key: region.origin, offset: offset, scale: scale)
                    },
                    onRemove: { vm.removeCellPhoto(at: region.origin) },
                    onUnmerge: { vm.unmerge(at: region.origin) }
                )
            }

            // Layers — sorted by z, free-floating on top of grid
            ForEach(slide.layers.sorted(by: { $0.zIndex < $1.zIndex })) { layer in
                LayerView(
                    layer: layer,
                    slideSize: size,
                    isSelected: isLayerSelected(layer.id),
                    onTap: { vm.selection = .layer(slide: slide.id, layerId: layer.id); vm.bringLayerForward(layer.id) },
                    onMutate: { vm.updateLayer(layer.id, mutate: $0) },
                    onDelete: { vm.deleteLayer(layer.id) }
                )
            }

            // Grid edit overlay — always present so the user can always adjust
            // crop lines. Handles are subtle; they light up on hover/press.
            if vm.isEditingGrid {
                GridEditOverlay(
                    grid: slide.grid,
                    canvasSize: size,
                    spacing: vm.document.spacing,
                    onMoveRowDivider: { index, value in
                        vm.moveRowDivider(at: index, to: value)
                    },
                    onMoveColDivider: { index, value in
                        vm.moveColDivider(at: index, to: value)
                    },
                    onMoveIntersection: { rowIdx, colIdx, x, y in
                        vm.moveColDivider(at: colIdx, to: x)
                        vm.moveRowDivider(at: rowIdx, to: y)
                    }
                )
                // Intersection + divider handles — do NOT rasterize this layer.
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .coordinateSpace(name: "canvas")
        .photosPicker(
            isPresented: $vm.showingPhotoPicker,
            selection: $vm.pickerItems,
            maxSelectionCount: 1,
            matching: .images
        )
        .onChange(of: vm.pickerItems) {
            guard !vm.pickerItems.isEmpty else { return }
            Task { await vm.processPickerItems() }
        }
    }

    private var mergeMode: Bool {
        if case .cell = vm.selection { return true } else { return false }
    }

    private func isCellSelected(_ key: CellKey) -> Bool {
        if case let .cell(_, k) = vm.selection, k == key { return true }
        return false
    }

    private func isLayerSelected(_ id: UUID) -> Bool {
        if case let .layer(_, lid) = vm.selection, lid == id { return true }
        return false
    }

    private func handleRegionTap(_ region: MosaicRegion) {
        // First tap selects the cell; subsequent tap with another cell selected merges them.
        if case let .cell(_, existing) = vm.selection, existing != region.origin {
            if vm.canMerge(a: existing, b: region.origin) {
                vm.mergeRegion(from: existing, to: region.origin)
                vm.selection = .none
                return
            }
        }
        // Empty cell → pick a photo. Filled cell → select it (for merge mode).
        if vm.currentSlide.grid.cellPhotos[region.origin] == nil {
            vm.beginPickingPhoto(forCell: region.origin)
        } else {
            vm.selection = .cell(slide: vm.currentSlide.id, cellKey: region.origin)
        }
    }
}

// MARK: - Grid region (a cell or a merged block)

private struct GridRegionView: View {
    let region: MosaicRegion
    let rect: CGRect
    let cornerRadius: CGFloat
    let photo: CellPhoto?
    let isSelected: Bool
    let mergeMode: Bool
    let onTap: () -> Void
    let onPhotoTransform: (CGSize, CGFloat) -> Void
    let onRemove: () -> Void
    let onUnmerge: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            if let photo {
                photoContent(photo)
            } else {
                emptyContent
            }

            if isSelected {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(MosaicTheme.saffron, lineWidth: 2)
            }
        }
        .frame(width: rect.width, height: rect.height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .position(x: rect.midX, y: rect.midY)
        .onTapGesture { onTap() }
        .overlay(alignment: .topTrailing) {
            if isSelected {
                HStack(spacing: 6) {
                    if region.rowSpan > 1 || region.colSpan > 1 {
                        actionChip(icon: "rectangle.split.2x1", tint: MosaicTheme.stone, action: onUnmerge)
                    }
                    if photo != nil {
                        actionChip(icon: "xmark", tint: MosaicTheme.ember, action: onRemove)
                    }
                }
                .padding(6)
                .position(x: rect.width - 24, y: 24)
            }
        }
    }

    private func actionChip(icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(MosaicTheme.cream)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.9))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func photoContent(_ photo: CellPhoto) -> some View {
        let imgSize = photo.image.pixelSize
        let imgAspect = imgSize.width / max(imgSize.height, 1)
        let cellAspect = rect.width / max(rect.height, 1)
        let base: CGSize = imgAspect > cellAspect
            ? CGSize(width: rect.height * imgAspect, height: rect.height)
            : CGSize(width: rect.width, height: rect.width / imgAspect)

        #if os(macOS)
        Image(nsImage: photo.image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fill)
            .frame(width: base.width * currentScale, height: base.height * currentScale)
            .offset(dragOffset)
            .frame(width: rect.width, height: rect.height)
            .contentShape(Rectangle())
            .gesture(photoPanGesture(photo))
            .simultaneousGesture(photoMagnifyGesture(photo))
        #else
        Image(uiImage: photo.image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fill)
            .frame(width: base.width * currentScale, height: base.height * currentScale)
            .offset(dragOffset)
            .frame(width: rect.width, height: rect.height)
            .contentShape(Rectangle())
            .gesture(photoPanGesture(photo))
            .simultaneousGesture(photoMagnifyGesture(photo))
        #endif
    }

    private func photoPanGesture(_ photo: CellPhoto) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                dragOffset = CGSize(
                    width: photo.offset.width + value.translation.width,
                    height: photo.offset.height + value.translation.height
                )
            }
            .onEnded { value in
                let newOffset = CGSize(
                    width: photo.offset.width + value.translation.width,
                    height: photo.offset.height + value.translation.height
                )
                onPhotoTransform(newOffset, currentScale)
            }
    }

    private func photoMagnifyGesture(_ photo: CellPhoto) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in currentScale = lastScale * value }
            .onEnded { value in
                lastScale = max(0.5, min(6, lastScale * value))
                currentScale = lastScale
                onPhotoTransform(dragOffset, currentScale)
            }
    }

    private var emptyContent: some View {
        ZStack {
            MosaicTheme.charcoal
            DotField()
            VStack(spacing: 6) {
                Image(systemName: mergeMode ? "rectangle.connected.to.line.below" : "plus")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(MosaicTheme.stone.opacity(0.7))
                Text(mergeMode ? "TAP TO MERGE" : "TAP")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(MosaicTheme.stone.opacity(0.5))
            }
        }
    }
}

// MARK: - Grid edit overlay (dividers + intersection handles)

// This is where the critical drag fix lives. Each divider/handle is a view
// whose FRAME defines its hit region, and its gesture is attached BEFORE
// `.position(...)` — otherwise .position() expands the view to fill its
// parent and every handle claims the full canvas as its hit area (the old bug).
private struct GridEditOverlay: View {
    let grid: MosaicGrid
    let canvasSize: CGSize
    let spacing: CGFloat
    let onMoveRowDivider: (Int, CGFloat) -> Void
    let onMoveColDivider: (Int, CGFloat) -> Void
    let onMoveIntersection: (Int, Int, CGFloat, CGFloat) -> Void

    private let hitThickness: CGFloat = 28   // finger-friendly
    private let visibleThickness: CGFloat = 1.5
    private let intersectionSize: CGFloat = 30

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Column dividers — segmented to skip merged rows
            ForEach(Array(grid.colDividers.enumerated()), id: \.offset) { colIdx, value in
                ForEach(Array(grid.colDividerSegments(colIdx: colIdx).enumerated()), id: \.offset) { _, seg in
                    let (yStartFrac, yEndFrac) = grid.yRange(startRow: seg.0, endRow: seg.1)
                    let segLen = (yEndFrac - yStartFrac) * canvasSize.height
                    let segMidY = (yStartFrac + yEndFrac) / 2 * canvasSize.height

                    DividerHandle(axis: .vertical,
                                  length: segLen,
                                  hitThickness: hitThickness,
                                  visibleThickness: visibleThickness)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
                                .onChanged { v in
                                    onMoveColDivider(colIdx, v.location.x / max(canvasSize.width, 1))
                                }
                        )
                        .position(x: value * canvasSize.width, y: segMidY)
                }
            }

            // Row dividers — segmented to skip merged columns
            ForEach(Array(grid.rowDividers.enumerated()), id: \.offset) { rowIdx, value in
                ForEach(Array(grid.rowDividerSegments(rowIdx: rowIdx).enumerated()), id: \.offset) { _, seg in
                    let (xStartFrac, xEndFrac) = grid.xRange(startCol: seg.0, endCol: seg.1)
                    let segLen = (xEndFrac - xStartFrac) * canvasSize.width
                    let segMidX = (xStartFrac + xEndFrac) / 2 * canvasSize.width

                    DividerHandle(axis: .horizontal,
                                  length: segLen,
                                  hitThickness: hitThickness,
                                  visibleThickness: visibleThickness)
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
                                .onChanged { v in
                                    onMoveRowDivider(rowIdx, v.location.y / max(canvasSize.height, 1))
                                }
                        )
                        .position(x: segMidX, y: value * canvasSize.height)
                }
            }

            // Intersection handles — only at real four-way crossings
            ForEach(Array(grid.rowDividers.enumerated()), id: \.offset) { rowIdx, rowVal in
                ForEach(Array(grid.colDividers.enumerated()), id: \.offset) { colIdx, colVal in
                    if grid.intersectionValid(rowIdx: rowIdx, colIdx: colIdx) {
                        IntersectionHandle(size: intersectionSize)
                            .highPriorityGesture(
                                DragGesture(minimumDistance: 0, coordinateSpace: .named("canvas"))
                                    .onChanged { v in
                                        let nx = v.location.x / max(canvasSize.width, 1)
                                        let ny = v.location.y / max(canvasSize.height, 1)
                                        onMoveIntersection(rowIdx, colIdx, nx, ny)
                                    }
                            )
                            .position(x: colVal * canvasSize.width, y: rowVal * canvasSize.height)
                    }
                }
            }
        }
        .frame(width: canvasSize.width, height: canvasSize.height)
        .allowsHitTesting(true)
    }
}

private struct DividerHandle: View {
    enum Axis { case horizontal, vertical }
    let axis: Axis
    let length: CGFloat
    let hitThickness: CGFloat
    let visibleThickness: CGFloat

    var body: some View {
        ZStack {
            // Visible line centered inside the hit frame
            Rectangle()
                .fill(MosaicTheme.saffron.opacity(0.45))
                .frame(
                    width: axis == .vertical ? visibleThickness : length,
                    height: axis == .vertical ? length : visibleThickness
                )
        }
        .frame(
            width: axis == .vertical ? hitThickness : length,
            height: axis == .vertical ? length : hitThickness
        )
        .contentShape(Rectangle())
    }
}

private struct IntersectionHandle: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(MosaicTheme.ink)
                .frame(width: 14, height: 14)
                .overlay(
                    Circle().strokeBorder(MosaicTheme.saffron, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
    }
}

// MARK: - Layer view (free-floating photo stacked above the grid)

private struct LayerView: View {
    let layer: PhotoLayer
    let slideSize: CGSize
    let isSelected: Bool
    let onTap: () -> Void
    let onMutate: (@escaping (inout PhotoLayer) -> Void) -> Void
    let onDelete: () -> Void

    // Mid-gesture transient state
    @State private var dragDelta: CGSize = .zero
    @State private var scaleDelta: CGFloat = 1.0
    @State private var rotationDelta: Angle = .zero

    private var rect: CGRect { layer.rect(in: slideSize) }

    var body: some View {
        let r = rect
        let w = r.width * scaleDelta
        let h = r.height * scaleDelta

        ZStack {
            #if os(macOS)
            Image(nsImage: layer.image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
            #else
            Image(uiImage: layer.image)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fill)
            #endif
        }
        .frame(width: w, height: h)
        .clipShape(RoundedRectangle(cornerRadius: layer.cornerRadius))
        .opacity(layer.opacity)
        .shadow(color: .black.opacity(isSelected ? 0.35 : 0.2), radius: isSelected ? 8 : 4, y: 2)
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: layer.cornerRadius)
                    .strokeBorder(MosaicTheme.saffron, lineWidth: 2)
            }
        }
        .rotationEffect(layer.rotation + rotationDelta)
        .contentShape(Rectangle())
        .position(x: r.midX + dragDelta.width, y: r.midY + dragDelta.height)
        .gesture(dragGesture)
        .simultaneousGesture(pinchGesture)
        .simultaneousGesture(rotationGesture)
        .onTapGesture { onTap() }
        .overlay {
            if isSelected {
                selectionControls
                    .position(x: r.midX + dragDelta.width, y: r.midY + dragDelta.height)
            }
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { v in
                dragDelta = v.translation
            }
            .onEnded { v in
                onMutate { l in
                    l.centerX = min(max((rect.midX + v.translation.width) / slideSize.width, -0.2), 1.2)
                    l.centerY = min(max((rect.midY + v.translation.height) / slideSize.height, -0.2), 1.2)
                }
                dragDelta = .zero
            }
    }

    private var pinchGesture: some Gesture {
        MagnificationGesture()
            .onChanged { v in scaleDelta = v }
            .onEnded { v in
                onMutate { l in
                    l.widthFrac = min(max(l.widthFrac * v, 0.05), 2.0)
                }
                scaleDelta = 1.0
            }
    }

    private var rotationGesture: some Gesture {
        RotationGesture()
            .onChanged { v in rotationDelta = v }
            .onEnded { v in
                onMutate { l in l.rotation = l.rotation + v }
                rotationDelta = .zero
            }
    }

    private var selectionControls: some View {
        // Four small handles; delete button top-right inside bounds
        let w = rect.width * scaleDelta
        let h = rect.height * scaleDelta
        return ZStack {
            // Corner handles (visual only — gestures above do resize via pinch)
            ForEach(0..<4, id: \.self) { i in
                let dx: CGFloat = (i % 2 == 0 ? -1 : 1) * w / 2
                let dy: CGFloat = (i < 2 ? -1 : 1) * h / 2
                Circle()
                    .fill(MosaicTheme.saffron)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().strokeBorder(MosaicTheme.ink, lineWidth: 1))
                    .offset(x: dx, y: dy)
            }

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(MosaicTheme.cream)
                    .frame(width: 24, height: 24)
                    .background(MosaicTheme.ember)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .offset(x: w / 2 + 14, y: -h / 2 - 14)
        }
        .rotationEffect(layer.rotation + rotationDelta)
        .allowsHitTesting(true)
    }
}

// MARK: - Decorative empty-cell pattern

private struct DotField: View, Equatable {
    nonisolated static func == (lhs: DotField, rhs: DotField) -> Bool { true }
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 16
            ctx.opacity = 0.1
            var r: CGFloat = step / 2
            while r < size.height {
                var c: CGFloat = step / 2
                while c < size.width {
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: c - 1, y: r - 1, width: 2, height: 2)),
                        with: .color(MosaicTheme.stone)
                    )
                    c += step
                }
                r += step
            }
        }
    }
}
