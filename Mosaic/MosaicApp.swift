import SwiftUI

@main
struct MosaicApp: App {
    @StateObject private var collageVM = CollageViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(collageVM)
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
