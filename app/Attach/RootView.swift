import SwiftUI

enum Tab: Hashable {
    case chats, apps, agents, tasks, profile
}

struct RootView: View {
    @EnvironmentObject private var models: ModelStore
    @StateObject private var installer = EngineInstaller.shared
    @StateObject private var core = CoreRuntime.shared

    @State private var tab: Tab = .chats
    @State private var showSetup = false
    @State private var showJournal = false
    @State private var hasCrash = false
    /// Экран запуска ушёл — дальше работаем с приложением.
    @State private var booted = false

    private var engineReady: Bool {
        installer.phase == .ready && core.phase.isReady
    }

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
            .opacity(booted ? 1 : 0)

            if !booted {
                BootView(installer: installer, core: core)
                    .transition(.opacity)
            }

            if booted && hasCrash {
                VStack {
                    Spacer()
                    CrashNotice(
                        onOpen: {
                            Diag.crashedLastRun = false
                            hasCrash = false
                            showJournal = true
                        },
                        onClose: {
                            Diag.crashedLastRun = false
                            hasCrash = false
                        }
                    )
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: booted)
        .onAppear {
            hasCrash = Diag.crashedLastRun
            // Ядро поднимаем сразу, не дожидаясь действий человека.
            Task { await installer.prepareIfNeeded() }
        }
        .onChange(of: engineReady) { _, ready in
            guard ready else { return }
            Task {
                // Даём экрану запуска показать «готово», иначе он мигнёт.
                try? await Task.sleep(nanoseconds: 800_000_000)
                withAnimation(.easeInOut(duration: 0.45)) {
                    booted = true
                }
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
