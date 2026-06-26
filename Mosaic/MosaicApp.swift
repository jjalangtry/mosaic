import SwiftUI

@main
struct MosaicApp: App {
    @State private var collageVM = CollageViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(collageVM)
                .preferredColorScheme(.dark)
            #if os(macOS)
                .frame(minWidth: 960, minHeight: 680)
            #endif
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .defaultSize(width: 1200, height: 800)
        #endif
    }
}
