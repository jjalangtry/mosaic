import SwiftUI

struct LayoutSidebarView: View {
    @EnvironmentObject var vm: CollageViewModel

    var body: some View {
        List {
            Section {
                Text("Choose a layout that\ntells your story.")
                    .font(.system(size: 12, weight: .regular, design: .serif))
                    .foregroundStyle(MosaicTheme.stone)
                    .italic()
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 4)
            }

            Section("Grids") {
                layoutRow(for: .grid2x2)
                layoutRow(for: .grid3x3)
            }

            Section("Strips") {
                layoutRow(for: .horizontalStrips)
                layoutRow(for: .verticalStrips)
            }

            Section("Feature") {
                layoutRow(for: .featureLeft)
                layoutRow(for: .featureTop)
                layoutRow(for: .lShape)
            }

            Section("Creative") {
                layoutRow(for: .triptych)
                layoutRow(for: .mosaicA)
                layoutRow(for: .diagonal)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Layouts")
        .scrollContentBackground(.hidden)
        .background(MosaicTheme.surface)
    }

    private func layoutRow(for layout: CollageLayout) -> some View {
        let isSelected = vm.selectedLayout.id == layout.id

        return Button {
            vm.selectLayout(layout)
        } label: {
            HStack(spacing: 12) {
                // Mini preview
                miniCanvas(layout: layout, isSelected: isSelected)
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                VStack(alignment: .leading, spacing: 2) {
                    Text(layout.name)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundStyle(isSelected ? MosaicTheme.cream : MosaicTheme.stone)

                    Text("\(layout.photoCount) photos")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(MosaicTheme.stone.opacity(0.6))
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(MosaicTheme.saffron)
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .listRowBackground(
            isSelected
            ? MosaicTheme.saffron.opacity(0.08)
            : Color.clear
        )
    }

    @ViewBuilder
    private func miniCanvas(layout: CollageLayout, isSelected: Bool) -> some View {
        let cells = isSelected ? vm.cells(for: layout) : layout.cells
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                MosaicTheme.ink
                ForEach(cells) { cell in
                    let rect = cell.rect(in: size, spacing: 1.5)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(isSelected ? MosaicTheme.saffron.opacity(0.35) : MosaicTheme.graphite)
                        .overlay(
                            RoundedRectangle(cornerRadius: 1.5)
                                .strokeBorder(
                                    isSelected ? MosaicTheme.saffron.opacity(0.6) : MosaicTheme.stone.opacity(0.15),
                                    lineWidth: 0.5
                                )
                        )
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
        }
    }
}
