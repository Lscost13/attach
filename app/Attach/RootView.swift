import SwiftUI

enum Tab: Hashable {
    case chats, apps, agents, tasks, profile
}

struct RootView: View {
    @EnvironmentObject private var models: ModelStore
    @StateObject private var installer = EngineInstaller.shared
    @State private var tab: Tab = .chats
    @State private var showSetup = false
    @State private var showJournal = false
    @State private var hasCrash = false

    private var engineReady: Bool { installer.phase == .ready }

    var body: some View {
        ZStack {
            TabView(selection: $tab) {
                ChatsView()
                    .tabItem { Label("Чаты", systemImage: "folder") }
                    .tag(Tab.chats)

                AppsView()
                    .tabItem { Label("Мини", systemImage: "square.grid.2x2") }
                    .tag(Tab.apps)

                AgentsView()
                    .tabItem { Label("Агенты", systemImage: "sparkle") }
                    .tag(Tab.agents)

                TasksView()
                    .tabItem { Label("Задачи", systemImage: "checklist") }
                    .tag(Tab.tasks)

                ProfileView()
                    .tabItem { Label("Профиль", systemImage: "person") }
                    .tag(Tab.profile)
            }
            .opacity(engineReady ? 1 : 0)

            if !engineReady {
                EngineSetupView(installer: installer)
                    .transition(.opacity)
            }

            if engineReady && hasCrash {
                VStack {
                    Spacer()
                    CrashNotice(
                        onOpen: { showJournal = true },
                        onClose: { hasCrash = false }
                    )
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: engineReady)
        .onChange(of: engineReady) { _, ready in
            guard ready else { return }
            CoreRuntime.shared.bootIfNeeded()
            if !models.hasKey { showSetup = true }
        }
        .onAppear {
            hasCrash = Diag.hasCrash
            if engineReady {
                CoreRuntime.shared.bootIfNeeded()
                if !models.hasKey { showSetup = true }
            }
        }
        .fullScreenCover(isPresented: $showSetup) {
            ModelSetupView(isOnboarding: true)
        }
        .sheet(isPresented: $showJournal) {
            DiagnosticsView()
        }
    }
}

#Preview {
    RootView()
        .environmentObject(WorkspaceStore())
        .environmentObject(ModelStore())
}
