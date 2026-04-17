import SwiftUI

struct ExportSheet: View {
    @EnvironmentObject var vm: CollageViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var previewIndex: Int = 0

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("EXPORT")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(MosaicTheme.stone)
                Spacer()
                Button("Done") { dismiss() }
                    .foregroundStyle(MosaicTheme.saffron)
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            if !vm.exportedSlides.isEmpty {
                TabView(selection: $previewIndex) {
                    ForEach(Array(vm.exportedSlides.enumerated()), id: \.offset) { idx, img in
                        slidePreview(img, index: idx, total: vm.exportedSlides.count)
                            .tag(idx)
                            .padding(.horizontal, 24)
                    }
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .always))
                #endif
                .frame(maxHeight: .infinity)

                HStack(spacing: 14) {
                    infoBadge("COUNT", "\(vm.exportedSlides.count)")
                    dividerV
                    infoBadge("SIZE", sizeLabel(vm.document.aspect.exportSize))
                    dividerV
                    infoBadge("FORMAT", "PNG")
                }
                .padding(.horizontal, 20)
            }

            Button {
                vm.saveAllToPhotos()
            } label: {
                HStack(spacing: 8) {
                    if vm.isSaving {
                        ProgressView().controlSize(.small)
                    } else if vm.saveSuccess {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                    } else {
                        Image(systemName: "square.and.arrow.down").font(.system(size: 13, weight: .bold))
                    }
                    #if os(iOS)
                    Text(vm.saveSuccess ? "Saved!" : "Save all to Photos")
                        .font(.system(size: 14, weight: .bold))
                    #else
                    Text(vm.saveSuccess ? "Saved!" : "Save all as PNG…")
                        .font(.system(size: 13, weight: .bold))
                    #endif
                }
                .foregroundStyle(MosaicTheme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(vm.saveSuccess ? AnyShapeStyle(Color.green) : AnyShapeStyle(MosaicTheme.saffronGradient))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(vm.isSaving)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(MosaicTheme.surface)
        .animation(.spring(response: 0.3), value: vm.saveSuccess)
    }

    private func slidePreview(_ image: PlatformImage, index: Int, total: Int) -> some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(MosaicTheme.ink)
                #if os(macOS)
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(vm.document.aspect.ratio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                #else
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(vm.document.aspect.ratio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                #endif
            }
            .shadow(color: .black.opacity(0.4), radius: 16, y: 6)

            Text("\(index + 1) of \(total)")
                .font(.system(size: 9, weight: .bold))
                .tracking(2)
                .foregroundStyle(MosaicTheme.stone)
        }
    }

    private func sizeLabel(_ s: CGSize) -> String {
        "\(Int(s.width))×\(Int(s.height))"
    }

    private func infoBadge(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .bold))
                .tracking(2)
                .foregroundStyle(MosaicTheme.stone)
            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MosaicTheme.cream)
        }
    }

    private var dividerV: some View {
        Rectangle().fill(MosaicTheme.graphite).frame(width: 1, height: 20)
    }
}
