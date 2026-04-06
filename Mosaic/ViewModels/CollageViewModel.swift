import SwiftUI
import PhotosUI
import Photos

@MainActor
class CollageViewModel: ObservableObject {
    @Published var selectedLayout: CollageLayout = .grid2x2
    @Published var cellPhotos: [Int: PhotoItem] = [:]
    @Published var spacing: CGFloat = 6
    @Published var cornerRadius: CGFloat = 4
    @Published var backgroundColor: Color = Color(hex: "0D0D0D")
    @Published var selectedCellIndex: Int? = nil
    @Published var showingPhotoPicker = false
    @Published var showingExport = false
    @Published var exportedImage: UIImage? = nil
    @Published var isSaving = false
    @Published var saveSuccess = false

    // Photo picker
    @Published var pickerItems: [PhotosPickerItem] = []

    func selectLayout(_ layout: CollageLayout) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            selectedLayout = layout
            // Keep existing photos, trim extras
            let maxIndex = layout.photoCount - 1
            cellPhotos = cellPhotos.filter { $0.key <= maxIndex }
        }
    }

    func assignPhoto(_ image: UIImage, to cellIndex: Int) {
        let item = PhotoItem(id: UUID().uuidString, image: image)
        withAnimation(.easeInOut(duration: 0.25)) {
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

    func processPickerItems() async {
        guard let cellIndex = selectedCellIndex else { return }

        for (i, item) in pickerItems.enumerated() {
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                let targetIndex = cellIndex + i
                if targetIndex < selectedLayout.photoCount {
                    assignPhoto(uiImage, to: targetIndex)
                }
            }
        }
        pickerItems = []
    }

    func renderCollage(size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Background
            UIColor(backgroundColor).setFill()
            ctx.fill(CGRect(origin: .zero, size: size))

            for cell in selectedLayout.cells {
                let rect = cell.rect(in: size, spacing: spacing * (size.width / 390))

                let path = UIBezierPath(
                    roundedRect: rect,
                    cornerRadius: cornerRadius * (size.width / 390)
                )

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
                            x: rect.midX - w / 2 + photo.offset.width * (size.width / 390),
                            y: rect.midY - h / 2 + photo.offset.height * (size.width / 390),
                            width: w, height: h
                        )
                    } else {
                        let w = rect.width * photo.scale
                        let h = w / imgAspect
                        drawRect = CGRect(
                            x: rect.midX - w / 2 + photo.offset.width * (size.width / 390),
                            y: rect.midY - h / 2 + photo.offset.height * (size.width / 390),
                            width: w, height: h
                        )
                    }
                    img.draw(in: drawRect)
                } else {
                    UIColor(Color(hex: "1C1C1E")).setFill()
                    ctx.fill(rect)
                }

                ctx.cgContext.restoreGState()
            }
        }
    }

    func exportForInstagram() {
        let exportSize = CGSize(width: 1080, height: 1080)
        exportedImage = renderCollage(size: exportSize)
        showingExport = true
    }

    func saveToPhotos() {
        guard let image = exportedImage else { return }
        isSaving = true

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self.isSaving = false
                }
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
}
