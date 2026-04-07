import SwiftUI

struct PhotoItem: Identifiable, Equatable {
    let id: String
    let image: PlatformImage
    var offset: CGSize = .zero
    var scale: CGFloat = 1.0
    var zIndex: Double = 0

    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.offset == rhs.offset &&
        lhs.scale == rhs.scale &&
        lhs.zIndex == rhs.zIndex
    }
}
