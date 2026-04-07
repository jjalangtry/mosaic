import SwiftUI

struct InspectorView: View {
    @EnvironmentObject var vm: CollageViewModel

    let backgroundColors: [(String, Color)] = [
        ("Ink", Color(hex: "0D0D0D")),
        ("Charcoal", Color(hex: "1C1C1E")),
        ("Slate", Color(hex: "2C3E50")),
        ("Midnight", Color(hex: "191970")),
        ("Wine", Color(hex: "3C1518")),
        ("Forest", Color(hex: "1B2A1B")),
        ("Cream", Color(hex: "F5F0EB")),
        ("White", Color(hex: "FFFFFF")),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text("INSPECTOR")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(MosaicTheme.stone)
                    .padding(.top, 4)

                // Current layout info
                inspectorSection("LAYOUT") {
                    HStack(spacing: 10) {
                        miniLayoutPreview
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 5))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(vm.selectedLayout.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(MosaicTheme.cream)
                            Text("\(vm.selectedLayout.photoCount) cells · \(vm.cellPhotos.count) filled")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(MosaicTheme.stone)
                        }
                    }
                }

                Divider().background(MosaicTheme.graphite)

                // Spacing
                inspectorSection("SPACING") {
                    VStack(spacing: 6) {
                        HStack {
                            Text("\(Int(vm.spacing))pt")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(MosaicTheme.cream)
                            Spacer()
                        }
                        Slider(value: $vm.spacing, in: 0...24, step: 1)
                            .tint(MosaicTheme.saffron)
                            .controlSize(.small)
                    }
                }

                // Corner Radius
                inspectorSection("CORNERS") {
                    VStack(spacing: 6) {
                        HStack {
                            Text("\(Int(vm.cornerRadius))pt")
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(MosaicTheme.cream)
                            Spacer()
                        }
                        Slider(value: $vm.cornerRadius, in: 0...32, step: 1)
                            .tint(MosaicTheme.saffron)
                            .controlSize(.small)
                    }
                }

                Divider().background(MosaicTheme.graphite)

                inspectorSection("STACKING") {
                    Toggle(isOn: $vm.allowOverlap) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Allow overlap")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(MosaicTheme.cream)
                            Text("Tap a photo to bring it forward.")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundStyle(MosaicTheme.stone.opacity(0.7))
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(MosaicTheme.saffron)
                }

                Divider().background(MosaicTheme.graphite)

                // Background
                inspectorSection("BACKGROUND") {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 48, maximum: 56), spacing: 8)],
                        spacing: 8
                    ) {
                        ForEach(backgroundColors, id: \.0) { name, color in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    vm.backgroundColor = color
                                }
                            } label: {
                                VStack(spacing: 3) {
                                    Circle()
                                        .fill(color)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Circle().strokeBorder(
                                                colorMatches(color)
                                                ? MosaicTheme.saffron
                                                : MosaicTheme.graphite,
                                                lineWidth: colorMatches(color) ? 2 : 1
                                            )
                                        )
                                        .shadow(
                                            color: colorMatches(color) ? MosaicTheme.saffron.opacity(0.3) : .clear,
                                            radius: 4
                                        )

                                    Text(name)
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundStyle(MosaicTheme.stone)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider().background(MosaicTheme.graphite)

                // Output info
                inspectorSection("OUTPUT") {
                    VStack(alignment: .leading, spacing: 6) {
                        infoRow(label: "Dimensions", value: "1080 × 1080")
                        infoRow(label: "Format", value: "PNG")
                        infoRow(label: "Platform", value: "Instagram")
                    }
                }

                Spacer()

                // Reset
                Button {
                    withAnimation {
                        vm.spacing = 6
                        vm.cornerRadius = 4
                        vm.backgroundColor = Color(hex: "0D0D0D")
                        vm.allowOverlap = false
                    }
                } label: {
                    Text("Reset to defaults")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(MosaicTheme.ember)
                }
            }
            .padding(16)
        }
        .background(MosaicTheme.surface)
    }

    // MARK: - Helpers

    private func inspectorSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(MosaicTheme.stone.opacity(0.7))

            content()
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MosaicTheme.stone)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(MosaicTheme.cream.opacity(0.8))
        }
    }

    private var miniLayoutPreview: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                MosaicTheme.ink
                ForEach(vm.activeCells) { cell in
                    let rect = cell.rect(in: size, spacing: 1.5)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(MosaicTheme.saffron.opacity(0.3))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                }
            }
        }
    }

    private func colorMatches(_ color: Color) -> Bool {
        color.description == vm.backgroundColor.description
    }
}
