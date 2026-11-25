import SwiftUI

@main
struct AttachApp: App {
    @StateObject private var store = WorkspaceStore()
    @StateObject private var models = ModelStore.shared
    @Environment(\.scenePhase) private var scenePhase

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
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        BackgroundKeeper.end()
                        CoreRuntime.shared.checkAlive()
                    case .background:
                        BackgroundKeeper.begin()
                    default:
                        break
                    }
                }
        }
    }
}
