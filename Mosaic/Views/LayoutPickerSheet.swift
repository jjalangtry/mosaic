import SwiftUI

struct LayoutPickerSheet: View {
    @EnvironmentObject var vm: CollageViewModel
    @Environment(\.dismiss) private var dismiss

    let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Choose a layout that tells your story.")
                        .font(.system(size: 13, weight: .regular, design: .serif))
                        .foregroundStyle(MosaicTheme.stone)
                        .italic()
                        .padding(.horizontal, 20)

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(CollageLayout.allLayouts) { layout in
                            LayoutPreviewCard(
                                layout: layout,
                                isSelected: vm.selectedLayout.id == layout.id
                            ) {
                                vm.selectLayout(layout)
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Layouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(MosaicTheme.saffron)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

struct LayoutPreviewCard: View {
    let layout: CollageLayout
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // Mini canvas preview
                GeometryReader { geo in
                    let size = geo.size
                    ZStack {
                        MosaicTheme.ink
                        ForEach(layout.cells) { cell in
                            let rect = cell.rect(in: size, spacing: 2)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    isSelected
                                    ? MosaicTheme.saffron.opacity(0.3)
                                    : MosaicTheme.graphite
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .strokeBorder(
                                            isSelected
                                            ? MosaicTheme.saffron.opacity(0.6)
                                            : MosaicTheme.stone.opacity(0.2),
                                            lineWidth: 0.5
                                        )
                                )
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                        }
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(spacing: 2) {
                    Text(layout.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? MosaicTheme.cream : MosaicTheme.stone)

                    Text("\(layout.photoCount) photos")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(MosaicTheme.stone.opacity(0.6))
                }
            }
            .padding(8)
            .background(isSelected ? MosaicTheme.charcoal : .clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(
                        isSelected ? MosaicTheme.saffron.opacity(0.4) : .clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
