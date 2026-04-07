import SwiftUI
import PhotosUI

struct CollageCanvasView: View {
    @EnvironmentObject var vm: CollageViewModel
    let canvasSize: CGFloat

    var body: some View {
        ZStack {
            vm.backgroundColor

            ForEach(vm.activeCells) { cell in
                CellView(
                    cell: cell,
                    canvasSize: canvasSize,
                    photo: vm.cellPhotos[cell.id],
                    spacing: vm.spacing,
                    cornerRadius: vm.cornerRadius,
                    allowOverlap: vm.allowOverlap,
                    onTap: {
                        vm.selectedCellIndex = cell.id
                        vm.showingPhotoPicker = true
                    },
                    onTransformChanged: { offset, scale in
                        vm.updatePhotoTransform(
                            cellIndex: cell.id,
                            offset: offset,
                            scale: scale
                        )
                    },
                    onBringToFront: {
                        vm.bringPhotoToFront(cellIndex: cell.id)
                    },
                    onRemove: {
                        vm.removePhoto(at: cell.id)
                    }
                )
            }
        }
        .overlay {
            GridHandleOverlay(
                canvasSize: canvasSize,
                spacing: vm.spacing,
                layoutId: vm.selectedLayout.id,
                grid2x2SplitX: vm.grid2x2SplitX,
                grid2x2SplitY: vm.grid2x2SplitY,
                grid3x3SplitX1: vm.grid3x3SplitX1,
                grid3x3SplitX2: vm.grid3x3SplitX2,
                grid3x3SplitY1: vm.grid3x3SplitY1,
                grid3x3SplitY2: vm.grid3x3SplitY2,
                onGrid2x2Change: { x, y in
                    vm.updateGrid2x2Splits(x: x, y: y)
                },
                onGrid3x3Change: { x1, x2, y1, y2 in
                    vm.updateGrid3x3Splits(x1: x1, x2: x2, y1: y1, y2: y2)
                }
            )
        }
        .drawingGroup()
        .photosPicker(
            isPresented: $vm.showingPhotoPicker,
            selection: $vm.pickerItems,
            maxSelectionCount: vm.selectedLayout.photoCount,
            matching: .images
        )
        .onChange(of: vm.pickerItems) {
            Task { await vm.processPickerItems() }
        }
    }
}

// MARK: - Individual Cell

struct CellView: View {
    let cell: CollageCell
    let canvasSize: CGFloat
    let photo: PhotoItem?
    let spacing: CGFloat
    let cornerRadius: CGFloat
    let allowOverlap: Bool
    let onTap: () -> Void
    let onTransformChanged: (CGSize, CGFloat) -> Void
    let onBringToFront: () -> Void
    let onRemove: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var isHovering = false

    private var cellRect: CGRect {
        cell.rect(in: CGSize(width: canvasSize, height: canvasSize), spacing: spacing)
    }

    var body: some View {
        let rect = cellRect

        ZStack {
            if let photo = photo {
                photoContent(photo, in: rect)
            } else {
                emptyCell(in: rect)
            }
        }
        .frame(width: rect.width, height: rect.height)
        .if(!allowOverlap || photo == nil) { view in
            view.clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .position(x: rect.midX, y: rect.midY)
        .zIndex(photo?.zIndex ?? 0)
    }

    @ViewBuilder
    private func photoContent(_ photo: PhotoItem, in rect: CGRect) -> some View {
        GeometryReader { _ in
            let imgSize = photo.image.size
            let imgAspect = imgSize.width / imgSize.height
            let cellAspect = rect.width / rect.height

            let baseSize: CGSize = {
                if imgAspect > cellAspect {
                    let h = rect.height
                    return CGSize(width: h * imgAspect, height: h)
                } else {
                    let w = rect.width
                    return CGSize(width: w, height: w / imgAspect)
                }
            }()

            #if os(macOS)
            Image(nsImage: photo.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: baseSize.width * currentScale, height: baseSize.height * currentScale)
                .offset(dragOffset)
                .frame(width: rect.width, height: rect.height)
                .if(!allowOverlap) { view in
                    view.clipped()
                }
                .contentShape(Rectangle())
                .gesture(dragGesture(photo: photo))
                .gesture(magnifyGesture(photo: photo))
                .onTapGesture {
                    onBringToFront()
                }
                .onHover { hovering in
                    isHovering = hovering
                }
                .overlay(alignment: .topTrailing) {
                    removeButton.opacity(isHovering ? 1 : 0)
                }
            #else
            Image(uiImage: photo.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: baseSize.width * currentScale, height: baseSize.height * currentScale)
                .offset(dragOffset)
                .frame(width: rect.width, height: rect.height)
                .if(!allowOverlap) { view in
                    view.clipped()
                }
                .contentShape(Rectangle())
                .gesture(dragGesture(photo: photo))
                .gesture(magnifyGesture(photo: photo))
                .overlay(alignment: .topTrailing) {
                    removeButton.opacity(0.5)
                }
                .onTapGesture {
                    onBringToFront()
                }
            #endif
        }
        .onAppear {
            dragOffset = photo.offset
            currentScale = photo.scale
            lastScale = photo.scale
        }
    }

    private func dragGesture(photo: PhotoItem) -> some Gesture {
        DragGesture()
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
                onTransformChanged(newOffset, currentScale)
            }
    }

    private func magnifyGesture(photo: PhotoItem) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                currentScale = lastScale * value
            }
            .onEnded { value in
                lastScale = lastScale * value
                currentScale = lastScale
                onTransformChanged(photo.offset, currentScale)
            }
    }

    private var removeButton: some View {
        Button {
            onRemove()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(6)
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }

    @ViewBuilder
    private func emptyCell(in rect: CGRect) -> some View {
        ZStack {
            MosaicTheme.charcoal

            CrosshatchView()

            VStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(MosaicTheme.stone.opacity(0.6))
                Text("TAP")
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(MosaicTheme.stone.opacity(0.4))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        #if os(macOS)
        .onHover { hovering in
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
        #endif
    }
}

// MARK: - Grid Handles

struct GridHandleOverlay: View {
    let canvasSize: CGFloat
    let spacing: CGFloat
    let layoutId: String
    let grid2x2SplitX: CGFloat
    let grid2x2SplitY: CGFloat
    let grid3x3SplitX1: CGFloat
    let grid3x3SplitX2: CGFloat
    let grid3x3SplitY1: CGFloat
    let grid3x3SplitY2: CGFloat
    let onGrid2x2Change: (CGFloat, CGFloat) -> Void
    let onGrid3x3Change: (CGFloat, CGFloat, CGFloat, CGFloat) -> Void

    var body: some View {
        if layoutId == CollageLayout.grid2x2.id {
            handleLayer(
                verticals: [grid2x2SplitX],
                horizontals: [grid2x2SplitY],
                onUpdate: { xs, ys in
                    guard let x = xs.first, let y = ys.first else { return }
                    onGrid2x2Change(x, y)
                }
            )
        } else if layoutId == CollageLayout.grid3x3.id {
            handleLayer(
                verticals: [grid3x3SplitX1, grid3x3SplitX2],
                horizontals: [grid3x3SplitY1, grid3x3SplitY2],
                onUpdate: { xs, ys in
                    guard xs.count == 2, ys.count == 2 else { return }
                    onGrid3x3Change(xs[0], xs[1], ys[0], ys[1])
                }
            )
        }
    }

    private func handleLayer(
        verticals: [CGFloat],
        horizontals: [CGFloat],
        onUpdate: @escaping ([CGFloat], [CGFloat]) -> Void
    ) -> some View {
        ZStack {
            ForEach(Array(verticals.enumerated()), id: \.offset) { index, value in
                let xPos = value * canvasSize
                GridHandleLine(
                    isVertical: true,
                    length: canvasSize,
                    thickness: max(2, spacing / 2),
                    position: xPos
                )
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            var updated = verticals
                            updated[index] = gesture.location.x / canvasSize
                            onUpdate(updated, horizontals)
                        }
                )
            }

            ForEach(Array(horizontals.enumerated()), id: \.offset) { index, value in
                let yPos = value * canvasSize
                GridHandleLine(
                    isVertical: false,
                    length: canvasSize,
                    thickness: max(2, spacing / 2),
                    position: yPos
                )
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            var updated = horizontals
                            updated[index] = gesture.location.y / canvasSize
                            onUpdate(verticals, updated)
                        }
                )
            }
        }
        .frame(width: canvasSize, height: canvasSize)
        .allowsHitTesting(true)
    }
}

struct GridHandleLine: View {
    let isVertical: Bool
    let length: CGFloat
    let thickness: CGFloat
    let position: CGFloat

    var body: some View {
        let hitSize: CGFloat = max(18, thickness + 12)
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .frame(
                    width: isVertical ? hitSize : length,
                    height: isVertical ? length : hitSize
                )
            Rectangle()
                .fill(MosaicTheme.saffron.opacity(0.6))
                .frame(
                    width: isVertical ? thickness : length,
                    height: isVertical ? length : thickness
                )
        }
        .position(
            x: isVertical ? position : length / 2,
            y: isVertical ? length / 2 : position
        )
        .contentShape(Rectangle())
        .accessibilityHidden(true)
    }
}

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Static Crosshatch (renders once, no animation churn)

struct CrosshatchView: View, Equatable {
    nonisolated static func == (lhs: CrosshatchView, rhs: CrosshatchView) -> Bool { true }

    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 12
            context.opacity = 0.08
            for x in stride(from: 0, to: size.width, by: step) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(MosaicTheme.stone), lineWidth: 0.5)
            }
            for y in stride(from: 0, to: size.height, by: step) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(MosaicTheme.stone), lineWidth: 0.5)
            }
        }
        .drawingGroup()
    }
}

// MARK: - NSImage size extension

#if os(macOS)
extension NSImage {
    var size: CGSize {
        guard let rep = representations.first else { return .zero }
        return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
    }
}
#endif
