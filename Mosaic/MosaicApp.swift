import SwiftUI

@main
struct MosaicApp: App {
    @StateObject private var collageVM = CollageViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(collageVM)
                .preferredColorScheme(.dark)
        }
    }
}
