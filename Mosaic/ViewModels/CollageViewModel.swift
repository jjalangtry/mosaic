import SwiftUI
import PhotosUI

#if os(macOS)
import AppKit
#else
import Photos
#endif

@MainActor
class CollageViewModel: ObservableObject {
    @Published var selectedLayout: CollageLayout = .grid2x2
    @Published var cellPhotos: [Int: PhotoItem] = [:]
    @Published var spacing: CGFloat = 6
    @Published var cornerRadius: CGFloat = 4
    @Published var backgroundColor: Color = Color(hex: "0D0D0D")
    @Published var allowOverlap = false
    @Published var grid2x2SplitX: CGFloat = 0.5
    @Published var grid2x2SplitY: CGFloat = 0.5
    @Published var grid3x3SplitX1: CGFloat = 1.0 / 3.0
    @Published var grid3x3SplitX2: CGFloat = 2.0 / 3.0
    @Published var grid3x3SplitY1: CGFloat = 1.0 / 3.0
    @Published var grid3x3SplitY2: CGFloat = 2.0 / 3.0
    @Published var selectedCellIndex: Int? = nil
    @Published var showingPhotoPicker = false
    @Published var showingExport = false
    @Published var exportedImage: PlatformImage? = nil
    @Published var isSaving = false
    @Published var saveSuccess = false
    @Published var showInspector = true

    @Published var pickerItems: [PhotosPickerItem] = []

    private var layoutSwitchTask: Task<Void, Never>?

    var activeCells: [CollageCell] {
        cells(for: selectedLayout)
    }

    func cells(for layout: CollageLayout) -> [CollageCell] {
        switch layout.id {
        case CollageLayout.grid2x2.id:
            return grid2x2Cells()
        case CollageLayout.grid3x3.id:
            return grid3x3Cells()
        default:
            return layout.cells
        }
    }

    func selectLayout(_ layout: CollageLayout) {
        // Debounce rapid clicks — cancel pending switch and only commit the latest
        layoutSwitchTask?.cancel()
        layoutSwitchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }

            // Don't animate Canvas redraws — just swap instantly
            selectedLayout = layout
            let maxIndex = layout.photoCount - 1
            cellPhotos = cellPhotos.filter { $0.key <= maxIndex }
        }
    }

    func assignPhoto(_ image: PlatformImage, to cellIndex: Int) {
        let item = PhotoItem(
            id: UUID().uuidString,
            image: image,
            zIndex: nextZIndex()
        )
        _ = withAnimation(.easeInOut(duration: 0.25)) {
            cellPhotos[cellIndex] = item
        }
    }

    func removePhoto(at cellIndex: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            cellPhotos.removeValue(forKey: cellIndex)
        }
    }

    func updatePhotoTransform(cellIndex: Int, offset: CGSize, scale: CGFloat) {
        guard var photo = cellPhotos[cellIndex] else { return }
        photo.offset = offset
        photo.scale = scale
        cellPhotos[cellIndex] = photo
    }

    func bringPhotoToFront(cellIndex: Int) {
        guard var photo = cellPhotos[cellIndex] else { return }
        photo.zIndex = nextZIndex()
        cellPhotos[cellIndex] = photo
    }

    func updateGrid2x2Splits(x: CGFloat, y: CGFloat) {
        let minSplit: CGFloat = 0.2
        let maxSplit: CGFloat = 0.8
        grid2x2SplitX = clamp(x, min: minSplit, max: maxSplit)
        grid2x2SplitY = clamp(y, min: minSplit, max: maxSplit)
    }

    func updateGrid3x3Splits(x1: CGFloat? = nil, x2: CGFloat? = nil, y1: CGFloat? = nil, y2: CGFloat? = nil) {
        let minSplit: CGFloat = 0.15
        let maxSplit: CGFloat = 0.85
        let minGap: CGFloat = 0.12

        var newX1 = clamp(x1 ?? grid3x3SplitX1, min: minSplit, max: maxSplit)
        var newX2 = clamp(x2 ?? grid3x3SplitX2, min: minSplit, max: maxSplit)
        if newX2 - newX1 < minGap {
            if x1 != nil {
                newX1 = clamp(newX2 - minGap, min: minSplit, max: maxSplit)
            } else {
                newX2 = clamp(newX1 + minGap, min: minSplit, max: maxSplit)
            }
        }
        if newX1 > newX2 {
            swap(&newX1, &newX2)
        }

        var newY1 = clamp(y1 ?? grid3x3SplitY1, min: minSplit, max: maxSplit)
        var newY2 = clamp(y2 ?? grid3x3SplitY2, min: minSplit, max: maxSplit)
        if newY2 - newY1 < minGap {
            if y1 != nil {
                newY1 = clamp(newY2 - minGap, min: minSplit, max: maxSplit)
            } else {
                newY2 = clamp(newY1 + minGap, min: minSplit, max: maxSplit)
            }
        }
        if newY1 > newY2 {
            swap(&newY1, &newY2)
        }

        grid3x3SplitX1 = newX1
        grid3x3SplitX2 = newX2
        grid3x3SplitY1 = newY1
        grid3x3SplitY2 = newY2
    }

    func processPickerItems() async {
        guard let cellIndex = selectedCellIndex else { return }

        for (i, item) in pickerItems.enumerated() {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let targetIndex = cellIndex + i
                guard targetIndex < selectedLayout.photoCount else { break }

                #if os(macOS)
                if let nsImage = NSImage(data: data) {
                    assignPhoto(nsImage, to: targetIndex)
                }
                #else
                if let uiImage = UIImage(data: data) {
                    assignPhoto(uiImage, to: targetIndex)
                }
                #endif
            }
        }
        pickerItems = []
    }

    // MARK: - Rendering

    func renderCollage(size: CGSize) -> PlatformImage {
        #if os(macOS)
        return renderCollageMacOS(size: size)
        #else
        return renderCollageiOS(size: size)
        #endif
    }

    #if os(macOS)
    private func renderCollageMacOS(size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()

        // Background
        NSColor(backgroundColor).setFill()
        NSRect(origin: .zero, size: size).fill()

        let scale = size.width / 390.0

        let cells = activeCells
        if allowOverlap {
            let sortedPhotos = cells.compactMap { cell -> (CollageCell, PhotoItem)? in
                guard let photo = cellPhotos[cell.id] else { return nil }
                return (cell, photo)
            }.sorted { $0.1.zIndex < $1.1.zIndex }

            for cell in cells where cellPhotos[cell.id] == nil {
                let rect = cell.rect(in: size, spacing: spacing * scale)
                NSColor(MosaicTheme.charcoal).setFill()
                rect.fill()
            }

            for (cell, photo) in sortedPhotos {
                let rect = cell.rect(in: size, spacing: spacing * scale)
                let img = photo.image
                let imgAspect = img.size.width / img.size.height
                let cellAspect = rect.width / rect.height

                var drawRect: CGRect
                if imgAspect > cellAspect {
                    let h = rect.height * photo.scale
                    let w = h * imgAspect
                    drawRect = CGRect(
                        x: rect.midX - w / 2 + photo.offset.width * scale,
                        y: rect.midY - h / 2 + photo.offset.height * scale,
                        width: w, height: h
                    )
                } else {
                    let w = rect.width * photo.scale
                    let h = w / imgAspect
                    drawRect = CGRect(
                        x: rect.midX - w / 2 + photo.offset.width * scale,
                        y: rect.midY - h / 2 + photo.offset.height * scale,
                        width: w, height: h
                    )
                }
                img.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            }
        } else {
            for cell in cells {
                let rect = cell.rect(in: size, spacing: spacing * scale)
                let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius * scale, yRadius: cornerRadius * scale)

                NSGraphicsContext.current?.saveGraphicsState()
                path.addClip()

                if let photo = cellPhotos[cell.id] {
                    let img = photo.image
                    let imgAspect = img.size.width / img.size.height
                    let cellAspect = rect.width / rect.height

                    var drawRect: CGRect
                    if imgAspect > cellAspect {
                        let h = rect.height * photo.scale
                        let w = h * imgAspect
                        drawRect = CGRect(
                            x: rect.midX - w / 2 + photo.offset.width * scale,
                            y: rect.midY - h / 2 + photo.offset.height * scale,
                            width: w, height: h
                        )
                    } else {
                        let w = rect.width * photo.scale
                        let h = w / imgAspect
                        drawRect = CGRect(
                            x: rect.midX - w / 2 + photo.offset.width * scale,
                            y: rect.midY - h / 2 + photo.offset.height * scale,
                            width: w, height: h
                        )
                    }
                    img.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
                } else {
                    NSColor(MosaicTheme.charcoal).setFill()
                    rect.fill()
                }

                NSGraphicsContext.current?.restoreGraphicsState()
            }
        }

        image.unlockFocus()
        return image
    }
    #endif

    #if os(iOS)
    private func renderCollageiOS(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(backgroundColor).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let scale = size.width / 390.0

            let cells = activeCells
            if allowOverlap {
                let sortedPhotos = cells.compactMap { cell -> (CollageCell, PhotoItem)? in
                    guard let photo = cellPhotos[cell.id] else { return nil }
                    return (cell, photo)
                }.sorted { $0.1.zIndex < $1.1.zIndex }

                for cell in cells where cellPhotos[cell.id] == nil {
                    let rect = cell.rect(in: size, spacing: spacing * scale)
                    UIColor(MosaicTheme.charcoal).setFill()
                    ctx.fill(rect)
                }

                for (cell, photo) in sortedPhotos {
                    let rect = cell.rect(in: size, spacing: spacing * scale)
                    let img = photo.image
                    let imgAspect = img.size.width / img.size.height
                    let cellAspect = rect.width / rect.height

                    var drawRect: CGRect
                    if imgAspect > cellAspect {
                        let h = rect.height * photo.scale
                        let w = h * imgAspect
                        drawRect = CGRect(
                            x: rect.midX - w / 2 + photo.offset.width * scale,
                            y: rect.midY - h / 2 + photo.offset.height * scale,
                            width: w, height: h
                        )
                    } else {
                        let w = rect.width * photo.scale
                        let h = w / imgAspect
                        drawRect = CGRect(
                            x: rect.midX - w / 2 + photo.offset.width * scale,
                            y: rect.midY - h / 2 + photo.offset.height * scale,
                            width: w, height: h
                        )
                    }
                    img.draw(in: drawRect)
                }
            } else {
                for cell in cells {
                    let rect = cell.rect(in: size, spacing: spacing * scale)
                    let path = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius * scale)

                    ctx.cgContext.saveGState()
                    path.addClip()

                    if let photo = cellPhotos[cell.id] {
                        let img = photo.image
                        let imgAspect = img.size.width / img.size.height
                        let cellAspect = rect.width / rect.height

                        var drawRect: CGRect
                        if imgAspect > cellAspect {
                            let h = rect.height * photo.scale
                            let w = h * imgAspect
                            drawRect = CGRect(
                                x: rect.midX - w / 2 + photo.offset.width * scale,
                                y: rect.midY - h / 2 + photo.offset.height * scale,
                                width: w, height: h
                            )
                        } else {
                            let w = rect.width * photo.scale
                            let h = w / imgAspect
                            drawRect = CGRect(
                                x: rect.midX - w / 2 + photo.offset.width * scale,
                                y: rect.midY - h / 2 + photo.offset.height * scale,
                                width: w, height: h
                            )
                        }
                        img.draw(in: drawRect)
                    } else {
                        UIColor(MosaicTheme.charcoal).setFill()
                        ctx.fill(rect)
                    }

                    ctx.cgContext.restoreGState()
                }
            }
        }
    }
    #endif

    func exportForInstagram() {
        let exportSize = CGSize(width: 1080, height: 1080)
        exportedImage = renderCollage(size: exportSize)
        showingExport = true
    }

    // MARK: - Save

    func saveToPhotos() {
        guard let image = exportedImage else { return }
        isSaving = true

        #if os(macOS)
        saveWithPanelMacOS(image: image)
        #else
        saveToPhotosiOS(image: image)
        #endif
    }

    #if os(macOS)
    private func saveWithPanelMacOS(image: NSImage) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "mosaic-collage.png"
        panel.title = "Save Collage"
        panel.message = "Choose where to save your Instagram collage"

        panel.begin { [weak self] response in
            guard let self else { return }
            Task { @MainActor in
                if response == .OK, let url = panel.url {
                    if let tiff = image.tiffRepresentation,
                       let bitmap = NSBitmapImageRep(data: tiff),
                       let png = bitmap.representation(using: .png, properties: [:]) {
                        try? png.write(to: url)
                        self.saveSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.saveSuccess = false
                        }
                    }
                }
                self.isSaving = false
            }
        }
    }
    #endif

    #if os(iOS)
    private func saveToPhotosiOS(image: UIImage) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { self.isSaving = false }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                DispatchQueue.main.async {
                    self.isSaving = false
                    if success {
                        self.saveSuccess = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.saveSuccess = false
                        }
                    }
                }
            }
        }
    }
    #endif

    private func grid2x2Cells() -> [CollageCell] {
        let x = grid2x2SplitX
        let y = grid2x2SplitY
        return [
            CollageCell(id: 0, x: 0, y: 0, width: x, height: y),
            CollageCell(id: 1, x: x, y: 0, width: 1 - x, height: y),
            CollageCell(id: 2, x: 0, y: y, width: x, height: 1 - y),
            CollageCell(id: 3, x: x, y: y, width: 1 - x, height: 1 - y),
        ]
    }

    private func grid3x3Cells() -> [CollageCell] {
        let x1 = grid3x3SplitX1
        let x2 = grid3x3SplitX2
        let y1 = grid3x3SplitY1
        let y2 = grid3x3SplitY2
        let widths = [x1, x2 - x1, 1 - x2]
        let heights = [y1, y2 - y1, 1 - y2]

        var cells: [CollageCell] = []
        var id = 0
        for row in 0..<3 {
            for col in 0..<3 {
                let x = widths.prefix(col).reduce(0, +)
                let y = heights.prefix(row).reduce(0, +)
                cells.append(CollageCell(id: id, x: x, y: y, width: widths[col], height: heights[row]))
                id += 1
            }
        }
        return cells
    }

    private func nextZIndex() -> Double {
        let maxZ = cellPhotos.values.map(\.zIndex).max() ?? 0
        return maxZ + 1
    }

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.min(Swift.max(value, min), max)
    }
}
