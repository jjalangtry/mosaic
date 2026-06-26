import SwiftUI
import PhotosUI

#if os(macOS)
import AppKit
#else
import Photos
#endif

// MARK: - Selection

enum SlideSelection: Equatable {
    case none
    case cell(slide: UUID, cellKey: CellKey)
    case layer(slide: UUID, layerId: UUID)
}

// MARK: - Photo picker target (what the picker is filling right now)

enum PhotoPickerTarget: Equatable {
    case cell(slide: UUID, cellKey: CellKey)
    case newLayer(slide: UUID)
}

@MainActor
@Observable
final class CollageViewModel {

    // Document
    var document = SlideDocument()
    var currentSlideIndex: Int = 0

    // Selection & tool state
    var selection: SlideSelection = .none
    var isEditingGrid: Bool = true      // when true, dividers are draggable
    var showInspector: Bool = true      // macOS
    var activePanel: ToolPanel = .none

    // Photo picker
    var showingPhotoPicker = false
    var pickerItems: [PhotosPickerItem] = []
    var pendingPickerTarget: PhotoPickerTarget?

    // Export
    var showingExport = false
    var showingFolderPicker = false      // macOS folder export
    var exportedSlides: [PlatformImage] = []
    var isSaving = false
    var saveSuccess = false

    enum ToolPanel: Equatable {
        case none
        case layout
        case layers
        case slides
        case style
    }

    // MARK: - Convenience accessors

    var currentSlide: Slide {
        get { document.slides[currentSlideIndex] }
        set { document.slides[currentSlideIndex] = newValue }
    }

    var slideCount: Int { document.slides.count }
    var aspect: SlideAspect { document.aspect }

    var selectedLayer: PhotoLayer? {
        guard case let .layer(_, layerId) = selection,
              let layer = currentSlide.layers.first(where: { $0.id == layerId })
        else { return nil }
        return layer
    }

    // MARK: - Aspect / Document

    func setAspect(_ aspect: SlideAspect) {
        guard document.aspect != aspect else { return }
        document.aspect = aspect
    }

    func setSpacing(_ value: CGFloat) { document.spacing = value }
    func setCornerRadius(_ value: CGFloat) { document.cornerRadius = value }
    func setBackground(_ color: Color) { document.backgroundColor = color }

    func reset() {
        document = SlideDocument(aspect: document.aspect)
        currentSlideIndex = 0
        selection = .none
        activePanel = .none
    }

    // MARK: - Slides

    func selectSlide(_ index: Int) {
        guard index >= 0, index < document.slides.count else { return }
        currentSlideIndex = index
        selection = .none
    }

    func addSlide() {
        guard document.slides.count < 10 else { return }
        let template = document.slides[currentSlideIndex].grid
        var newSlide = Slide(grid: MosaicGrid(rows: template.rows, cols: template.cols))
        newSlide.grid.rowDividers = template.rowDividers
        newSlide.grid.colDividers = template.colDividers
        document.slides.append(newSlide)
        currentSlideIndex = document.slides.count - 1
    }

    func duplicateCurrentSlide() {
        guard document.slides.count < 10 else { return }
        var copy = document.slides[currentSlideIndex]
        copy = Slide(grid: copy.grid, layers: copy.layers.map { l in
            var c = l; return c
        })
        document.slides.insert(copy, at: currentSlideIndex + 1)
        currentSlideIndex += 1
    }

    func removeCurrentSlide() {
        guard document.slides.count > 1 else { return }
        document.slides.remove(at: currentSlideIndex)
        currentSlideIndex = min(currentSlideIndex, document.slides.count - 1)
        selection = .none
    }

    // MARK: - Grid editing

    func applyPreset(_ preset: GridPreset) {
        currentSlide.grid = preset.makeGrid()
    }

    func setRows(_ rows: Int) {
        let rows = max(1, min(6, rows))
        var grid = currentSlide.grid
        if rows == grid.rows { return }
        grid.rows = rows
        grid.rowDividers = (1..<rows).map { CGFloat($0) / CGFloat(rows) }
        grid.merges = grid.merges.filter { $0.origin.row + $0.rowSpan <= rows }
        grid.cellPhotos = grid.cellPhotos.filter { $0.key.row < rows }
        currentSlide.grid = grid
    }

    func setCols(_ cols: Int) {
        let cols = max(1, min(6, cols))
        var grid = currentSlide.grid
        if cols == grid.cols { return }
        grid.cols = cols
        grid.colDividers = (1..<cols).map { CGFloat($0) / CGFloat(cols) }
        grid.merges = grid.merges.filter { $0.origin.col + $0.colSpan <= cols }
        grid.cellPhotos = grid.cellPhotos.filter { $0.key.col < cols }
        currentSlide.grid = grid
    }

    /// Move the divider at `index` (row or column) to a new normalized position,
    /// clamped between its neighbors.
    func moveRowDivider(at index: Int, to value: CGFloat) {
        var g = currentSlide.grid
        guard index >= 0, index < g.rowDividers.count else { return }
        let minPos = index == 0 ? 0.05 : g.rowDividers[index - 1] + 0.05
        let maxPos = index == g.rowDividers.count - 1 ? 0.95 : g.rowDividers[index + 1] - 0.05
        g.rowDividers[index] = min(max(value, minPos), maxPos)
        currentSlide.grid = g
    }

    func moveColDivider(at index: Int, to value: CGFloat) {
        var g = currentSlide.grid
        guard index >= 0, index < g.colDividers.count else { return }
        let minPos = index == 0 ? 0.05 : g.colDividers[index - 1] + 0.05
        let maxPos = index == g.colDividers.count - 1 ? 0.95 : g.colDividers[index + 1] - 0.05
        g.colDividers[index] = min(max(value, minPos), maxPos)
        currentSlide.grid = g
    }

    // Merge / unmerge

    func canMerge(a: CellKey, b: CellKey) -> Bool {
        let rowMin = min(a.row, b.row), rowMax = max(a.row, b.row)
        let colMin = min(a.col, b.col), colMax = max(a.col, b.col)
        let grid = currentSlide.grid
        // Not overlapping an existing merge
        for m in grid.merges {
            let mRange = m.origin.row..<(m.origin.row + m.rowSpan)
            let mCols = m.origin.col..<(m.origin.col + m.colSpan)
            for r in rowMin...rowMax {
                for c in colMin...colMax where mRange.contains(r) && mCols.contains(c) {
                    return false
                }
            }
        }
        return true
    }

    func mergeRegion(from: CellKey, to: CellKey) {
        let rowMin = min(from.row, to.row), rowMax = max(from.row, to.row)
        let colMin = min(from.col, to.col), colMax = max(from.col, to.col)
        var g = currentSlide.grid
        let merge = MosaicMerge(
            origin: CellKey(row: rowMin, col: colMin),
            rowSpan: rowMax - rowMin + 1,
            colSpan: colMax - colMin + 1
        )
        // Remove any existing merges inside this region
        g.merges.removeAll { m in
            m.origin.row >= rowMin &&
            m.origin.col >= colMin &&
            m.origin.row + m.rowSpan <= rowMax + 1 &&
            m.origin.col + m.colSpan <= colMax + 1
        }
        g.merges.append(merge)
        // Remove photos in cells inside the merge (except the top-left)
        for r in rowMin...rowMax {
            for c in colMin...colMax {
                if r == rowMin && c == colMin { continue }
                g.cellPhotos.removeValue(forKey: CellKey(row: r, col: c))
            }
        }
        currentSlide.grid = g
    }

    func unmerge(at origin: CellKey) {
        var g = currentSlide.grid
        g.merges.removeAll { $0.origin == origin }
        currentSlide.grid = g
    }

    // MARK: - Cell photo assignment

    func beginPickingPhoto(forCell key: CellKey) {
        pendingPickerTarget = .cell(slide: currentSlide.id, cellKey: key)
        showingPhotoPicker = true
    }

    func beginPickingNewLayer() {
        pendingPickerTarget = .newLayer(slide: currentSlide.id)
        showingPhotoPicker = true
    }

    func updateCellPhotoTransform(key: CellKey, offset: CGSize, scale: CGFloat) {
        guard var photo = currentSlide.grid.cellPhotos[key] else { return }
        photo.offset = offset
        photo.scale = scale
        currentSlide.grid.cellPhotos[key] = photo
    }

    func removeCellPhoto(at key: CellKey) {
        currentSlide.grid.cellPhotos.removeValue(forKey: key)
    }

    // MARK: - Layers

    func addLayer(image: PlatformImage) {
        let z = (currentSlide.layers.map { $0.zIndex }.max() ?? 0) + 1
        let layer = PhotoLayer(
            id: UUID(),
            image: image,
            centerX: 0.5,
            centerY: 0.5,
            widthFrac: 0.55,
            rotation: .degrees(0),
            opacity: 1.0,
            cornerRadius: 6,
            zIndex: z
        )
        currentSlide.layers.append(layer)
        selection = .layer(slide: currentSlide.id, layerId: layer.id)
    }

    func updateLayer(_ layerId: UUID, mutate: (inout PhotoLayer) -> Void) {
        guard let idx = currentSlide.layers.firstIndex(where: { $0.id == layerId }) else { return }
        mutate(&currentSlide.layers[idx])
    }

    func deleteLayer(_ layerId: UUID) {
        currentSlide.layers.removeAll { $0.id == layerId }
        if case let .layer(_, lid) = selection, lid == layerId {
            selection = .none
        }
    }

    func bringLayerForward(_ layerId: UUID) {
        guard let idx = currentSlide.layers.firstIndex(where: { $0.id == layerId }) else { return }
        let maxZ = currentSlide.layers.map { $0.zIndex }.max() ?? 0
        currentSlide.layers[idx].zIndex = maxZ + 1
    }

    func sendLayerBackward(_ layerId: UUID) {
        guard let idx = currentSlide.layers.firstIndex(where: { $0.id == layerId }) else { return }
        let minZ = currentSlide.layers.map { $0.zIndex }.min() ?? 0
        currentSlide.layers[idx].zIndex = minZ - 1
    }

    // MARK: - Photo picker processing

    func processPickerItems() async {
        let target = pendingPickerTarget
        pendingPickerTarget = nil
        guard let target else {
            pickerItems = []
            return
        }

        for item in pickerItems {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            guard let image = Self.makeImage(from: data) else { continue }

            switch target {
            case .cell(_, let key):
                currentSlide.grid.cellPhotos[key] = CellPhoto(image: image)
                // Only first image fills the cell.
                pickerItems = []
                return
            case .newLayer:
                addLayer(image: image)
            }
        }
        pickerItems = []
    }

    private static func makeImage(from data: Data) -> PlatformImage? {
        #if os(macOS)
        return NSImage(data: data)
        #else
        return UIImage(data: data)
        #endif
    }

    // MARK: - Rendering

    func render(slide: Slide, at size: CGSize) -> PlatformImage {
        #if os(macOS)
        return renderMacOS(slide: slide, size: size)
        #else
        return renderIOS(slide: slide, size: size)
        #endif
    }

    func exportAllSlides() {
        let size = document.aspect.exportSize
        exportedSlides = document.slides.map { render(slide: $0, at: size) }
        showingExport = true
    }

    #if os(macOS)
    private func renderMacOS(slide: Slide, size: CGSize) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor(document.backgroundColor).setFill()
        NSRect(origin: .zero, size: size).fill()

        let spacing = document.spacing * (size.width / 1080.0)
        let cornerRadius = document.cornerRadius * (size.width / 1080.0)
        let grid = slide.grid

        for region in grid.regions {
            let rect = grid.rect(for: region, in: size, spacing: spacing)
            let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            NSGraphicsContext.current?.saveGraphicsState()
            path.addClip()

            if let photo = grid.cellPhotos[region.origin] {
                let draw = drawRectMacOS(for: photo, in: rect, scaleHint: size.width / 1080.0)
                photo.image.draw(in: draw, from: .zero, operation: .sourceOver, fraction: 1.0)
            } else {
                NSColor(MosaicTheme.charcoal).setFill()
                rect.fill()
            }
            NSGraphicsContext.current?.restoreGraphicsState()
        }

        // Layers sorted by z
        for layer in slide.layers.sorted(by: { $0.zIndex < $1.zIndex }) {
            drawLayerMacOS(layer, in: size)
        }
        return image
    }

    private func drawRectMacOS(for photo: CellPhoto, in rect: CGRect, scaleHint: CGFloat) -> CGRect {
        let img = photo.image
        let imgAspect = img.pixelSize.width / max(img.pixelSize.height, 1)
        let cellAspect = rect.width / max(rect.height, 1)
        let base: CGSize
        if imgAspect > cellAspect {
            let h = rect.height
            base = CGSize(width: h * imgAspect, height: h)
        } else {
            let w = rect.width
            base = CGSize(width: w, height: w / imgAspect)
        }
        let w = base.width * photo.scale
        let h = base.height * photo.scale
        let cx = rect.midX + photo.offset.width * scaleHint
        let cy = rect.midY + photo.offset.height * scaleHint
        return CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
    }

    private func drawLayerMacOS(_ layer: PhotoLayer, in slideSize: CGSize) {
        let rect = layer.rect(in: slideSize)
        guard let ctx = NSGraphicsContext.current else { return }
        ctx.saveGraphicsState()
        ctx.cgContext.translateBy(x: rect.midX, y: rect.midY)
        ctx.cgContext.rotate(by: CGFloat(layer.rotation.radians))
        ctx.cgContext.translateBy(x: -rect.midX, y: -rect.midY)
        let path = NSBezierPath(roundedRect: rect,
                                xRadius: layer.cornerRadius * slideSize.width / 1080.0,
                                yRadius: layer.cornerRadius * slideSize.width / 1080.0)
        path.addClip()
        layer.image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: CGFloat(layer.opacity))
        ctx.restoreGraphicsState()
    }
    #endif

    #if os(iOS)
    private func renderIOS(slide: Slide, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor(document.backgroundColor).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            let scaleHint = size.width / 1080.0
            let spacing = document.spacing * scaleHint
            let cornerRadius = document.cornerRadius * scaleHint
            let grid = slide.grid

            for region in grid.regions {
                let rect = grid.rect(for: region, in: size, spacing: spacing)
                ctx.cgContext.saveGState()
                UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).addClip()

                if let photo = grid.cellPhotos[region.origin] {
                    let draw = drawRectIOS(for: photo, in: rect, scaleHint: scaleHint)
                    photo.image.draw(in: draw)
                } else {
                    UIColor(MosaicTheme.charcoal).setFill()
                    ctx.fill(rect)
                }
                ctx.cgContext.restoreGState()
            }

            for layer in slide.layers.sorted(by: { $0.zIndex < $1.zIndex }) {
                drawLayerIOS(layer, in: size, context: ctx.cgContext)
            }
        }
    }

    private func drawRectIOS(for photo: CellPhoto, in rect: CGRect, scaleHint: CGFloat) -> CGRect {
        let img = photo.image
        let imgAspect = img.pixelSize.width / max(img.pixelSize.height, 1)
        let cellAspect = rect.width / max(rect.height, 1)
        let base: CGSize
        if imgAspect > cellAspect {
            let h = rect.height
            base = CGSize(width: h * imgAspect, height: h)
        } else {
            let w = rect.width
            base = CGSize(width: w, height: w / imgAspect)
        }
        let w = base.width * photo.scale
        let h = base.height * photo.scale
        let cx = rect.midX + photo.offset.width * scaleHint
        let cy = rect.midY + photo.offset.height * scaleHint
        return CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)
    }

    private func drawLayerIOS(_ layer: PhotoLayer, in slideSize: CGSize, context: CGContext) {
        let rect = layer.rect(in: slideSize)
        context.saveGState()
        context.translateBy(x: rect.midX, y: rect.midY)
        context.rotate(by: CGFloat(layer.rotation.radians))
        context.translateBy(x: -rect.midX, y: -rect.midY)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: layer.cornerRadius * slideSize.width / 1080.0)
        path.addClip()
        layer.image.draw(in: rect, blendMode: .normal, alpha: CGFloat(layer.opacity))
        context.restoreGState()
    }
    #endif

    // MARK: - Save

    func saveAllToPhotos() {
        guard !exportedSlides.isEmpty else { return }
        #if os(macOS)
        // Present the native SwiftUI folder picker; writing happens in writeSlides(to:).
        showingFolderPicker = true
        #else
        isSaving = true
        Task { await saveAllToPhotosIOS() }
        #endif
    }

    #if os(macOS)
    /// Writes each slide as a numbered PNG into the user-chosen folder.
    /// Invoked by the SwiftUI `.fileImporter` folder picker in ExportSheet.
    func writeSlides(to folderURL: URL) {
        let didAccess = folderURL.startAccessingSecurityScopedResource()
        defer { if didAccess { folderURL.stopAccessingSecurityScopedResource() } }

        isSaving = true
        for (i, img) in exportedSlides.enumerated() {
            guard let tiff = img.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiff),
                  let png = bitmap.representation(using: .png, properties: [:]) else { continue }
            let file = folderURL.appendingPathComponent(String(format: "mosaic-%02d.png", i + 1))
            try? png.write(to: file)
        }
        isSaving = false
        saveSuccess = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            saveSuccess = false
        }
    }
    #endif

    #if os(iOS)
    private func saveAllToPhotosIOS() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            isSaving = false
            return
        }

        // Capture images locally so the change block doesn't reach into main-actor state.
        let slides = exportedSlides
        do {
            try await PHPhotoLibrary.shared().performChanges {
                for img in slides {
                    PHAssetChangeRequest.creationRequestForAsset(from: img)
                }
            }
            isSaving = false
            saveSuccess = true
            try? await Task.sleep(for: .seconds(2))
            saveSuccess = false
        } catch {
            isSaving = false
        }
    }
    #endif
}
