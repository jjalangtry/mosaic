import SwiftUI

struct SettingsSheet: View {
    @EnvironmentObject var vm: CollageViewModel
    @Environment(\.dismiss) private var dismiss

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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    // Spacing control
                    settingSection("SPACING") {
                        VStack(spacing: 8) {
                            HStack {
                                Text("\(Int(vm.spacing))pt")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(MosaicTheme.cream)
                                Spacer()
                            }
                            Slider(value: $vm.spacing, in: 0...24, step: 1)
                                .tint(MosaicTheme.saffron)
                        }
                    }

                    // Corner radius
                    settingSection("CORNER RADIUS") {
                        VStack(spacing: 8) {
                            HStack {
                                Text("\(Int(vm.cornerRadius))pt")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(MosaicTheme.cream)
                                Spacer()
                            }
                            Slider(value: $vm.cornerRadius, in: 0...32, step: 1)
                                .tint(MosaicTheme.saffron)
                        }
                    }

                    // Background color
                    settingSection("BACKGROUND") {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 56, maximum: 70), spacing: 10)],
                            spacing: 10
                        ) {
                            ForEach(backgroundColors, id: \.0) { name, color in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        vm.backgroundColor = color
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 36, height: 36)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(
                                                        colorMatches(color)
                                                        ? MosaicTheme.saffron
                                                        : MosaicTheme.graphite,
                                                        lineWidth: colorMatches(color) ? 2 : 1
                                                    )
                                            )
                                            .shadow(
                                                color: colorMatches(color)
                                                ? MosaicTheme.saffron.opacity(0.3) : .clear,
                                                radius: 6
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

                    // Reset
                    Button {
                        withAnimation {
                            vm.spacing = 6
                            vm.cornerRadius = 4
                            vm.backgroundColor = Color(hex: "0D0D0D")
                        }
                    } label: {
                        Text("Reset to defaults")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(MosaicTheme.ember)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("Settings")
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

    private func settingSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(MosaicTheme.stone)

            content()
        }
        .padding(.horizontal, 20)
    }

    private func colorMatches(_ color: Color) -> Bool {
        // Simple comparison via description
        return color.description == vm.backgroundColor.description
    }
}
