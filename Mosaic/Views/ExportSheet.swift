import SwiftUI

struct ExportSheet: View {
    @EnvironmentObject var vm: CollageViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var animateIn = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if let image = vm.exportedImage {
                    // Preview
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(1, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
                        .padding(.horizontal, 40)
                        .scaleEffect(animateIn ? 1 : 0.9)
                        .opacity(animateIn ? 1 : 0)

                    // Info badge
                    HStack(spacing: 16) {
                        infoBadge(label: "SIZE", value: "1080×1080")
                        divider
                        infoBadge(label: "FORMAT", value: "PNG")
                        divider
                        infoBadge(label: "READY", value: "Instagram")
                    }
                    .padding(.horizontal, 20)
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
                                        .tint(MosaicTheme.ink)
                                } else if vm.saveSuccess {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .transition(.scale.combined(with: .opacity))
                                } else {
                                    Image(systemName: "square.and.arrow.down")
                                        .font(.system(size: 14, weight: .bold))
                                }

                                Text(vm.saveSuccess ? "Saved!" : "Save to Photos")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundStyle(MosaicTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                vm.saveSuccess
                                ? AnyShapeStyle(Color.green)
                                : AnyShapeStyle(MosaicTheme.saffronGradient)
                            )
                            .clipShape(Capsule())
                        }
                        .disabled(vm.isSaving)
                        .animation(.spring(response: 0.3), value: vm.saveSuccess)

                        if let image = vm.exportedImage {
                            ShareLink(
                                item: Image(uiImage: image),
                                preview: SharePreview("Mosaic Collage", image: Image(uiImage: image))
                            ) {
                                HStack(spacing: 8) {
                                    Image(systemName: "paperplane")
                                        .font(.system(size: 14, weight: .medium))
                                    Text("Share")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundStyle(MosaicTheme.cream)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .glassBackground()
                                .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 20)
                }
            }
            .padding(.top, 8)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(MosaicTheme.saffron)
                        .fontWeight(.semibold)
                }
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1)) {
                    animateIn = true
                }
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
