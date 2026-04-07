import SwiftUI

struct ExportSheet: View {
    @EnvironmentObject var vm: CollageViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var animateIn = false

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("EXPORT")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(MosaicTheme.stone)

                Spacer()

                Button("Done") { dismiss() }
                    .foregroundStyle(MosaicTheme.saffron)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            if let image = vm.exportedImage {
                // Preview
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
                    .padding(.horizontal, 48)
                    .scaleEffect(animateIn ? 1 : 0.92)
                    .opacity(animateIn ? 1 : 0)
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
                    .padding(.horizontal, 48)
                    .scaleEffect(animateIn ? 1 : 0.92)
                    .opacity(animateIn ? 1 : 0)
                #endif

                // Info badges
                HStack(spacing: 20) {
                    infoBadge(label: "SIZE", value: "1080×1080")
                    divider
                    infoBadge(label: "FORMAT", value: "PNG")
                    divider
                    infoBadge(label: "READY", value: "Instagram")
                }
                .opacity(animateIn ? 1 : 0)

                Spacer()

                // Actions
                VStack(spacing: 10) {
                    Button {
                        vm.saveToPhotos()
                    } label: {
                        HStack(spacing: 8) {
                            if vm.isSaving {
                                ProgressView()
                                    .controlSize(.small)
                                    #if os(macOS)
                                    .tint(MosaicTheme.ink)
                                    #endif
                            } else if vm.saveSuccess {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .transition(.scale.combined(with: .opacity))
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 14, weight: .bold))
                            }

                            #if os(macOS)
                            Text(vm.saveSuccess ? "Saved!" : "Save as PNG…")
                                .font(.system(size: 13, weight: .bold))
                            #else
                            Text(vm.saveSuccess ? "Saved!" : "Save to Photos")
                                .font(.system(size: 15, weight: .bold))
                            #endif
                        }
                        .foregroundStyle(MosaicTheme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            vm.saveSuccess
                            ? AnyShapeStyle(Color.green)
                            : AnyShapeStyle(MosaicTheme.saffronGradient)
                        )
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isSaving)
                    .animation(.spring(response: 0.3), value: vm.saveSuccess)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .opacity(animateIn ? 1 : 0)
                .offset(y: animateIn ? 0 : 16)
            }
        }
        .background(MosaicTheme.surface)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                animateIn = true
            }
        }
    }

    private func infoBadge(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(MosaicTheme.stone)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MosaicTheme.cream)
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(MosaicTheme.graphite)
            .frame(width: 1, height: 24)
    }
}
