import SwiftUI

// MARK: - Aspect ratio

enum SlideAspect: String, CaseIterable, Identifiable {
    case square        // 1:1
    case portrait45    // 4:5 (Instagram feed / carousel)
    case story916      // 9:16 (Story / Reels cover)

    var id: String { rawValue }

    var ratio: CGFloat {
        switch self {
        case .square:     return 1.0
        case .portrait45: return 4.0 / 5.0
        case .story916:   return 9.0 / 16.0
        }
    }

    var exportSize: CGSize {
        switch self {
        case .square:     return CGSize(width: 1080, height: 1080)
        case .portrait45: return CGSize(width: 1080, height: 1350)
        case .story916:   return CGSize(width: 1080, height: 1920)
        }
    }

    var label: String {
        switch self {
        case .square:     return "Square"
        case .portrait45: return "Portrait"
        case .story916:   return "Story"
        }
    }

    var shortLabel: String {
        switch self {
        case .square:     return "1:1"
        case .portrait45: return "4:5"
        case .story916:   return "9:16"
        }
    }
}

// MARK: - Grid

// A flexible grid: rows × cols, with independently draggable row and column dividers,
// and optional merges that combine rectangular blocks of cells into one.
struct MosaicGrid: Equatable {
    var rows: Int
    var cols: Int
    // (rows-1) values in (0,1), strictly increasing. Fractions of height.
    var rowDividers: [CGFloat]
    // (cols-1) values in (0,1), strictly increasing. Fractions of width.
    var colDividers: [CGFloat]
    // Merged regions. Cells inside a merge are hidden; the merge renders as one cell.
    var merges: [MosaicMerge]
    // Image assignments keyed by cell origin (row, col). For merged regions, keyed
    // by the top-left cell of the merge.
    var cellPhotos: [CellKey: CellPhoto]

    static let empty = MosaicGrid(rows: 2, cols: 2)

    init(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
        self.rowDividers = Self.evenDividers(count: rows - 1)
        self.colDividers = Self.evenDividers(count: cols - 1)
        self.merges = []
        self.cellPhotos = [:]
    }

    private static func evenDividers(count: Int) -> [CGFloat] {
        guard count > 0 else { return [] }
        return (1...count).map { CGFloat($0) / CGFloat(count + 1) }
    }

    // Column widths as fractions.
    var columnWidths: [CGFloat] {
        var stops: [CGFloat] = [0] + colDividers + [1]
        var widths: [CGFloat] = []
        for i in 0..<(stops.count - 1) { widths.append(stops[i + 1] - stops[i]) }
        return widths
    }

    // Row heights as fractions.
    var rowHeights: [CGFloat] {
        var stops: [CGFloat] = [0] + rowDividers + [1]
        var heights: [CGFloat] = []
        for i in 0..<(stops.count - 1) { heights.append(stops[i + 1] - stops[i]) }
        return heights
    }

    // X positions of column starts (fractions).
    var colStarts: [CGFloat] {
        var xs: [CGFloat] = [0]
        for d in colDividers { xs.append(d) }
        return xs
    }

    var rowStarts: [CGFloat] {
        var ys: [CGFloat] = [0]
        for d in rowDividers { ys.append(d) }
        return ys
    }

    // Every visible "region" (a merged region or a single cell not part of a merge).
    var regions: [MosaicRegion] {
        var covered = Set<CellKey>()
        var result: [MosaicRegion] = []
        for merge in merges {
            let region = MosaicRegion(origin: merge.origin, rowSpan: merge.rowSpan, colSpan: merge.colSpan)
            for r in merge.origin.row..<(merge.origin.row + merge.rowSpan) {
                for c in merge.origin.col..<(merge.origin.col + merge.colSpan) {
                    covered.insert(CellKey(row: r, col: c))
                }
            }
            result.append(region)
        }
        for r in 0..<rows {
            for c in 0..<cols {
                let k = CellKey(row: r, col: c)
                if !covered.contains(k) {
                    result.append(MosaicRegion(origin: k, rowSpan: 1, colSpan: 1))
                }
            }
        }
        return result
    }

    // Column ranges [startCol, endCol) where the row divider between rowIdx and rowIdx+1
    // actually separates cells (i.e. no merge crosses that horizontal line at that column).
    func rowDividerSegments(rowIdx: Int) -> [(Int, Int)] {
        var blockedCols = Set<Int>()
        for m in merges where m.origin.row <= rowIdx && m.origin.row + m.rowSpan > rowIdx + 1 {
            for c in m.origin.col..<(m.origin.col + m.colSpan) { blockedCols.insert(c) }
        }
        return Self.runs(total: cols, blocked: blockedCols)
    }

    // Row ranges [startRow, endRow) where the column divider between colIdx and colIdx+1
    // actually separates cells.
    func colDividerSegments(colIdx: Int) -> [(Int, Int)] {
        var blockedRows = Set<Int>()
        for m in merges where m.origin.col <= colIdx && m.origin.col + m.colSpan > colIdx + 1 {
            for r in m.origin.row..<(m.origin.row + m.rowSpan) { blockedRows.insert(r) }
        }
        return Self.runs(total: rows, blocked: blockedRows)
    }

    // True iff the intersection between row divider rowIdx and col divider colIdx
    // is a real four-way crossing — the four surrounding cells are all distinct.
    func intersectionValid(rowIdx: Int, colIdx: Int) -> Bool {
        let rowSegs = rowDividerSegments(rowIdx: rowIdx)
        let colSegs = colDividerSegments(colIdx: colIdx)
        func rowHasCol(_ c: Int) -> Bool {
            rowSegs.contains { start, end in start <= c && c < end }
        }
        func colHasRow(_ r: Int) -> Bool {
            colSegs.contains { start, end in start <= r && r < end }
        }
        return rowHasCol(colIdx) && rowHasCol(colIdx + 1)
            && colHasRow(rowIdx) && colHasRow(rowIdx + 1)
    }

    private static func runs(total: Int, blocked: Set<Int>) -> [(Int, Int)] {
        var result: [(Int, Int)] = []
        var start: Int? = nil
        for i in 0..<total {
            if blocked.contains(i) {
                if let s = start { result.append((s, i)); start = nil }
            } else if start == nil {
                start = i
            }
        }
        if let s = start { result.append((s, total)) }
        return result
    }

    // Fractional x range for a column index span.
    func xRange(startCol: Int, endCol: Int) -> (CGFloat, CGFloat) {
        let starts = colStarts
        let xStart = starts[startCol]
        let xEnd = endCol < starts.count ? starts[endCol] : 1.0
        return (xStart, xEnd)
    }

    func yRange(startRow: Int, endRow: Int) -> (CGFloat, CGFloat) {
        let starts = rowStarts
        let yStart = starts[startRow]
        let yEnd = endRow < starts.count ? starts[endRow] : 1.0
        return (yStart, yEnd)
    }

    func rect(for region: MosaicRegion, in size: CGSize, spacing: CGFloat) -> CGRect {
        let colStarts = self.colStarts
        let rowStarts = self.rowStarts
        let colWidths = self.columnWidths
        let rowHeights = self.rowHeights

        let xFrac = colStarts[region.origin.col]
        let yFrac = rowStarts[region.origin.row]
        let wFrac = colWidths[region.origin.col..<(region.origin.col + region.colSpan)].reduce(0, +)
        let hFrac = rowHeights[region.origin.row..<(region.origin.row + region.rowSpan)].reduce(0, +)

        let inset = spacing / 2
        let x = xFrac * size.width + inset
        let y = yFrac * size.height + inset
        let w = max(wFrac * size.width - spacing, 0)
        let h = max(hFrac * size.height - spacing, 0)
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

struct MosaicMerge: Equatable {
    var origin: CellKey
    var rowSpan: Int
    var colSpan: Int
}

struct MosaicRegion: Hashable, Identifiable {
    let origin: CellKey
    let rowSpan: Int
    let colSpan: Int
    // Identity is the value itself - CellKey is Hashable, so synthesis covers it.
    var id: Self { self }
}

struct CellKey: Hashable, Codable, Equatable {
    let row: Int
    let col: Int
}

struct CellPhoto: Equatable {
    var image: PlatformImage
    var offset: CGSize = .zero
    var scale: CGFloat = 1.0

    static func == (lhs: CellPhoto, rhs: CellPhoto) -> Bool {
        lhs.image === rhs.image && lhs.offset == rhs.offset && lhs.scale == rhs.scale
    }
}

// MARK: - Layers (free-floating photos stacked on top of the grid)

struct PhotoLayer: Identifiable, Equatable {
    let id: UUID
    var image: PlatformImage
    // All normalized to slide size (0..1), so they stay put across aspect changes.
    var centerX: CGFloat
    var centerY: CGFloat
    // Size stored as fraction of slide *width* for both dimensions so aspect is preserved.
    var widthFrac: CGFloat
    var rotation: Angle
    var opacity: Double
    var cornerRadius: CGFloat
    var zIndex: Int

    // Derived height fraction based on image aspect.
    func heightFrac(in slideSize: CGSize) -> CGFloat {
        let imgAspect = image.pixelSize.width / max(image.pixelSize.height, 1)
        let w = widthFrac * slideSize.width
        let h = w / max(imgAspect, 0.0001)
        return h / max(slideSize.height, 1)
    }

    func rect(in slideSize: CGSize) -> CGRect {
        let w = widthFrac * slideSize.width
        let imgAspect = image.pixelSize.width / max(image.pixelSize.height, 1)
        let h = w / max(imgAspect, 0.0001)
        return CGRect(
            x: centerX * slideSize.width - w / 2,
            y: centerY * slideSize.height - h / 2,
            width: w,
            height: h
        )
    }

    static func == (lhs: PhotoLayer, rhs: PhotoLayer) -> Bool {
        lhs.id == rhs.id &&
        lhs.image === rhs.image &&
        lhs.centerX == rhs.centerX &&
        lhs.centerY == rhs.centerY &&
        lhs.widthFrac == rhs.widthFrac &&
        lhs.rotation == rhs.rotation &&
        lhs.opacity == rhs.opacity &&
        lhs.cornerRadius == rhs.cornerRadius &&
        lhs.zIndex == rhs.zIndex
    }
}

// MARK: - Slide

struct Slide: Identifiable, Equatable {
    let id: UUID
    var grid: MosaicGrid
    var layers: [PhotoLayer]

    init(grid: MosaicGrid = MosaicGrid(rows: 2, cols: 2), layers: [PhotoLayer] = []) {
        self.id = UUID()
        self.grid = grid
        self.layers = layers
    }
}

// MARK: - Document

// A document is a single-or-multi-slide composition.
struct SlideDocument: Equatable {
    var slides: [Slide]
    var aspect: SlideAspect
    var backgroundColor: Color
    var spacing: CGFloat
    var cornerRadius: CGFloat

    init(aspect: SlideAspect = .square) {
        self.slides = [Slide()]
        self.aspect = aspect
        self.backgroundColor = Color(hex: "0D0D0D")
        self.spacing = 6
        self.cornerRadius = 8
    }
}

// MARK: - Cross-platform image pixel-size helper

extension PlatformImage {
    var pixelSize: CGSize {
        #if os(macOS)
        if let rep = representations.first {
            return CGSize(width: rep.pixelsWide, height: rep.pixelsHigh)
        }
        return size
        #else
        return CGSize(width: size.width * scale, height: size.height * scale)
        #endif
    }
}

// MARK: - Preset starting grids

enum GridPreset: String, CaseIterable, Identifiable {
    case single       // 1×1
    case split2H      // 2 rows
    case split2V      // 2 cols
    case grid2x2
    case grid3x3
    case featureLeft  // 2 cols, right col split into 2 rows
    case featureTop   // 2 rows, bottom row split into 2 cols
    case strips3H
    case strips3V
    case grid4x4

    var id: String { rawValue }

    var label: String {
        switch self {
        case .single:       return "Single"
        case .split2H:      return "2 Rows"
        case .split2V:      return "2 Cols"
        case .grid2x2:      return "2×2"
        case .grid3x3:      return "3×3"
        case .featureLeft:  return "Feature L"
        case .featureTop:   return "Feature T"
        case .strips3H:     return "3 Rows"
        case .strips3V:     return "3 Cols"
        case .grid4x4:      return "4×4"
        }
    }

    var icon: String {
        switch self {
        case .single:       return "square"
        case .split2H:      return "rectangle.split.1x2"
        case .split2V:      return "rectangle.split.2x1"
        case .grid2x2:      return "square.grid.2x2"
        case .grid3x3:      return "square.grid.3x3"
        case .featureLeft:  return "rectangle.leadinghalf.inset.filled"
        case .featureTop:   return "rectangle.tophalf.inset.filled"
        case .strips3H:     return "rectangle.split.1x2"
        case .strips3V:     return "rectangle.split.3x1"
        case .grid4x4:      return "square.grid.4x3.fill"
        }
    }

    func makeGrid() -> MosaicGrid {
        switch self {
        case .single:
            return MosaicGrid(rows: 1, cols: 1)
        case .split2H:
            return MosaicGrid(rows: 2, cols: 1)
        case .split2V:
            return MosaicGrid(rows: 1, cols: 2)
        case .grid2x2:
            return MosaicGrid(rows: 2, cols: 2)
        case .grid3x3:
            return MosaicGrid(rows: 3, cols: 3)
        case .grid4x4:
            return MosaicGrid(rows: 4, cols: 4)
        case .strips3H:
            return MosaicGrid(rows: 3, cols: 1)
        case .strips3V:
            return MosaicGrid(rows: 1, cols: 3)
        case .featureLeft:
            var g = MosaicGrid(rows: 2, cols: 2)
            g.merges = [MosaicMerge(origin: CellKey(row: 0, col: 0), rowSpan: 2, colSpan: 1)]
            g.colDividers = [0.6]
            return g
        case .featureTop:
            var g = MosaicGrid(rows: 2, cols: 2)
            g.merges = [MosaicMerge(origin: CellKey(row: 0, col: 0), rowSpan: 1, colSpan: 2)]
            g.rowDividers = [0.6]
            return g
        }
    }
}
