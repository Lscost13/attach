import SwiftUI

@main
struct AttachApp: App {
    @StateObject private var store = WorkspaceStore()
    @StateObject private var models = ModelStore()

    init() {
        Diag.install()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(models)
                .preferredColorScheme(.dark)
                .tint(.white)
        }
    }
}
