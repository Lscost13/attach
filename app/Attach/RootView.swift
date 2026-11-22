import SwiftUI

enum Tab: Hashable {
    case chats, apps, agents, tasks, profile
}

struct RootView: View {
    @EnvironmentObject private var models: ModelStore
    @State private var tab: Tab = .chats
    @State private var showSetup = false

    var body: some View {
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
        .onAppear {
            CoreRuntime.shared.bootIfNeeded()
            if !models.hasKey {
                showSetup = true
            }
        }
        .fullScreenCover(isPresented: $showSetup) {
            ModelSetupView(isOnboarding: true)
        }
    }
}

#Preview {
    RootView()
        .environmentObject(WorkspaceStore())
        .environmentObject(ModelStore())
}
