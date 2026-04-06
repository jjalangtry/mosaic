import SwiftUI
import PhotosUI

struct CollageCanvasView: View {
    @EnvironmentObject var vm: CollageViewModel
    let canvasSize: CGFloat

    var body: some View {
        ZStack {
            vm.backgroundColor

            ForEach(vm.selectedLayout.cells) { cell in
                CellView(
                    cell: cell,
                    canvasSize: canvasSize,
                    photo: vm.cellPhotos[cell.id],
                    spacing: vm.spacing,
                    cornerRadius: vm.cornerRadius,
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
                    onRemove: {
                        vm.removePhoto(at: cell.id)
                    }
                )
            }
        }
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
    let onTap: () -> Void
    let onTransformChanged: (CGSize, CGFloat) -> Void
    let onRemove: () -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var isHovered = false
    @GestureState private var isPressing = false

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
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .position(x: rect.midX, y: rect.midY)
    }

    @ViewBuilder
    private func photoContent(_ photo: PhotoItem, in rect: CGRect) -> some View {
        GeometryReader { _ in
            let img = photo.image
            let imgAspect = img.size.width / img.size.height
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

            Image(uiImage: img)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(
                    width: baseSize.width * currentScale,
                    height: baseSize.height * currentScale
                )
                .offset(dragOffset)
                .frame(width: rect.width, height: rect.height)
                .clipped()
                .contentShape(Rectangle())
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = CGSize(
                                width: (photo.offset.width) + value.translation.width,
                                height: (photo.offset.height) + value.translation.height
                            )
                        }
                        .onEnded { value in
                            let newOffset = CGSize(
                                width: photo.offset.width + value.translation.width,
                                height: photo.offset.height + value.translation.height
                            )
                            onTransformChanged(newOffset, currentScale)
                        }
                )
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            currentScale = lastScale * value
                        }
                        .onEnded { value in
                            lastScale = lastScale * value
                            currentScale = lastScale
                            onTransformChanged(photo.offset, currentScale)
                        }
                )
                .overlay(alignment: .topTrailing) {
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
                    .padding(6)
                    .opacity(isHovered ? 1 : 0.5)
                }
                .onAppear {
                    dragOffset = photo.offset
                    currentScale = photo.scale
                    lastScale = photo.scale
                }
        }
    }

    @ViewBuilder
    private func emptyCell(in rect: CGRect) -> some View {
        ZStack {
            MosaicTheme.charcoal

            // Subtle cross-hatch pattern
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
        .onTapGesture {
            onTap()
        }
        .scaleEffect(isPressing ? 0.97 : 1.0)
    }
}
