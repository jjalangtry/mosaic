import Foundation

struct CollageCell: Identifiable, Equatable {
    let id: Int
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat

    func rect(in size: CGSize, spacing: CGFloat) -> CGRect {
        let totalW = size.width
        let totalH = size.height
        let inset = spacing / 2
        let rawWidth = width * totalW - spacing
        let rawHeight = height * totalH - spacing
        let clampedWidth = max(rawWidth, 0)
        let clampedHeight = max(rawHeight, 0)
        return CGRect(
            x: x * totalW + inset,
            y: y * totalH + inset,
            width: clampedWidth,
            height: clampedHeight
        )
    }
}

struct CollageLayout: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String
    let cells: [CollageCell]

    var photoCount: Int { cells.count }

    static let allLayouts: [CollageLayout] = [
        grid2x2,
        grid3x3,
        horizontalStrips,
        verticalStrips,
        featureLeft,
        featureTop,
        lShape,
        triptych,
        mosaicA,
        diagonal,
    ]

    // MARK: - Layout Definitions

    static let grid2x2 = CollageLayout(
        id: "grid2x2", name: "Grid 2×2", icon: "square.grid.2x2",
        cells: [
            CollageCell(id: 0, x: 0, y: 0, width: 0.5, height: 0.5),
            CollageCell(id: 1, x: 0.5, y: 0, width: 0.5, height: 0.5),
            CollageCell(id: 2, x: 0, y: 0.5, width: 0.5, height: 0.5),
            CollageCell(id: 3, x: 0.5, y: 0.5, width: 0.5, height: 0.5),
        ]
    )

    static let grid3x3 = CollageLayout(
        id: "grid3x3", name: "Grid 3×3", icon: "square.grid.3x3",
        cells: (0..<9).map { i in
            CollageCell(
                id: i,
                x: CGFloat(i % 3) / 3.0,
                y: CGFloat(i / 3) / 3.0,
                width: 1.0 / 3.0,
                height: 1.0 / 3.0
            )
        }
    )

    static let horizontalStrips = CollageLayout(
        id: "hStrips", name: "Horizontal", icon: "rectangle.split.3x1",
        cells: [
            CollageCell(id: 0, x: 0, y: 0, width: 1.0, height: 1.0 / 3.0),
            CollageCell(id: 1, x: 0, y: 1.0 / 3.0, width: 1.0, height: 1.0 / 3.0),
            CollageCell(id: 2, x: 0, y: 2.0 / 3.0, width: 1.0, height: 1.0 / 3.0),
        ]
    )

    static let verticalStrips = CollageLayout(
        id: "vStrips", name: "Vertical", icon: "rectangle.split.1x2",
        cells: [
            CollageCell(id: 0, x: 0, y: 0, width: 1.0 / 3.0, height: 1.0),
            CollageCell(id: 1, x: 1.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1.0),
            CollageCell(id: 2, x: 2.0 / 3.0, y: 0, width: 1.0 / 3.0, height: 1.0),
        ]
    )

    static let featureLeft = CollageLayout(
        id: "featureLeft", name: "Feature Left", icon: "rectangle.leadinghalf.inset.filled",
        cells: [
            CollageCell(id: 0, x: 0, y: 0, width: 0.6, height: 1.0),
            CollageCell(id: 1, x: 0.6, y: 0, width: 0.4, height: 0.5),
            CollageCell(id: 2, x: 0.6, y: 0.5, width: 0.4, height: 0.5),
        ]
    )

    static let featureTop = CollageLayout(
        id: "featureTop", name: "Feature Top", icon: "rectangle.tophalf.inset.filled",
        cells: [
            CollageCell(id: 0, x: 0, y: 0, width: 1.0, height: 0.6),
            CollageCell(id: 1, x: 0, y: 0.6, width: 0.5, height: 0.4),
            CollageCell(id: 2, x: 0.5, y: 0.6, width: 0.5, height: 0.4),
        ]
    )

    static let lShape = CollageLayout(
        id: "lShape", name: "L-Shape", icon: "rectangle.split.2x2",
        cells: [
            CollageCell(id: 0, x: 0, y: 0, width: 0.5, height: 0.5),
            CollageCell(id: 1, x: 0.5, y: 0, width: 0.5, height: 1.0),
            CollageCell(id: 2, x: 0, y: 0.5, width: 0.5, height: 0.5),
        ]
    )

    static let triptych = CollageLayout(
        id: "triptych", name: "Triptych", icon: "rectangle.split.3x1",
        cells: [
            CollageCell(id: 0, x: 0, y: 0.1, width: 0.3, height: 0.8),
            CollageCell(id: 1, x: 0.32, y: 0, width: 0.36, height: 1.0),
            CollageCell(id: 2, x: 0.7, y: 0.1, width: 0.3, height: 0.8),
        ]
    )

    static let mosaicA = CollageLayout(
        id: "mosaicA", name: "Mosaic", icon: "square.grid.3x3.topleft.filled",
        cells: [
            CollageCell(id: 0, x: 0, y: 0, width: 0.65, height: 0.65),
            CollageCell(id: 1, x: 0.65, y: 0, width: 0.35, height: 0.35),
            CollageCell(id: 2, x: 0.65, y: 0.35, width: 0.35, height: 0.30),
            CollageCell(id: 3, x: 0, y: 0.65, width: 0.4, height: 0.35),
            CollageCell(id: 4, x: 0.4, y: 0.65, width: 0.6, height: 0.35),
        ]
    )

    static let diagonal = CollageLayout(
        id: "diagonal", name: "Diagonal", icon: "rectangle.on.rectangle.angled",
        cells: [
            CollageCell(id: 0, x: 0, y: 0, width: 0.55, height: 0.45),
            CollageCell(id: 1, x: 0.55, y: 0, width: 0.45, height: 0.55),
            CollageCell(id: 2, x: 0, y: 0.45, width: 0.45, height: 0.55),
            CollageCell(id: 3, x: 0.45, y: 0.55, width: 0.55, height: 0.45),
        ]
    )
}
