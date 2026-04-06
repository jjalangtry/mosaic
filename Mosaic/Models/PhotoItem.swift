import SwiftUI
import Photos

struct PhotoItem: Identifiable, Equatable {
    let id: String
    let image: UIImage
    var offset: CGSize = .zero
    var scale: CGFloat = 1.0

    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.offset == rhs.offset &&
        lhs.scale == rhs.scale
    }
}
