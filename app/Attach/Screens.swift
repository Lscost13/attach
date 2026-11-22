import SwiftUI

// MARK: - Каркас экрана

struct Screen<Content: View>: View {
    let kicker: String
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(kicker.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.26))

                Text(title)
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.top, 8)

                content()
                    .padding(.top, 18)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 90)
        }
        .scrollIndicators(.hidden)
        .background(Color.black)
    }
}

struct Row: View {
    let icon: String
    let title: String
    let subtitle: String
    var trailing: String? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.44))
            }

            Spacer(minLength: 8)

            if let trailing {
                Text(trailing)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.26))
            }
        }
        .padding(13)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Чаты (проекты)

struct ChatsView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @StateObject private var core = CoreRuntime.shared
    @State private var isCreating = false
    @State private var draftName = ""

    var body: some View {
        NavigationStack {
            Screen(kicker: "Чаты", title: "Проекты") {
                CoreStatusRow(phase: core.phase)

                if store.projects.isEmpty {
                    EmptyProjects()
                } else {
                    VStack(spacing: 8) {
                        ForEach(store.projects) { project in
                            NavigationLink(value: project.id) {
                                ProjectCard(project: project)
                            }
                            .buttonStyle(.plain)
                            .transition(.scale(scale: 0.97).combined(with: .opacity))
                        }
                    }
                    .animation(.snappy(duration: 0.28), value: store.projects)
                }

                Button {
                    draftName = ""
                    isCreating = true
                } label: {
                    Label("Новый проект", systemImage: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.plain)
                .glassSurface(cornerRadius: 18)
                .padding(.top, 10)
            }
            .navigationDestination(for: UUID.self) { id in
                ProjectView(projectID: id)
            }
            .alert("Новый проект", isPresented: $isCreating) {
                TextField("Название", text: $draftName)
                Button("Создать") {
                    withAnimation(.snappy(duration: 0.3)) {
                        _ = store.addProject(name: draftName)
                    }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Папка, в которой будут жить чаты и файлы.")
            }
        }
        .task { core.bootIfNeeded() }
    }
}

struct EmptyProjects: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder")
                .font(.system(size: 24))
                .foregroundStyle(.white.opacity(0.55))
            Text("Пока нет проектов")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            Text("Проект — это папка: чаты, файлы и рабочая папка агента.")
                .font(.system(size: 12.5))
                .foregroundStyle(.white.opacity(0.44))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .padding(.horizontal, 18)
        .background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                .foregroundStyle(.white.opacity(0.14))
        )
    }
}

struct ProjectCard: View {
    let project: Project

    private var subtitle: String {
        let n = project.chats.count
        let mod10 = n % 10
        let mod100 = n % 100
        let word: String
        if mod10 == 1 && mod100 != 11 {
            word = "чат"
        } else if mod10 >= 2 && mod10 <= 4 && (mod100 < 10 || mod100 >= 20) {
            word = "чата"
        } else {
            word = "чатов"
        }
        return "\(n) \(word)"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 16))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.44))
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.26))
        }
        .padding(13)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Проект

struct ProjectView: View {
    @EnvironmentObject private var store: WorkspaceStore
    let projectID: UUID

    private var project: Project? { store.project(projectID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                if let project {
                    if project.chats.isEmpty {
                        Text("В проекте пока нет чатов.\nСоздай первый — кнопкой справа сверху.")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.44))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 24)
                    } else {
                        ForEach(project.chats) { chat in
                            NavigationLink(value: ChatRoute(projectID: projectID, chatID: chat.id)) {
                                ChatRow(chat: chat)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 90)
            .animation(.snappy(duration: 0.28), value: project?.chats)
        }
        .scrollIndicators(.hidden)
        .background(Color.black)
        .navigationTitle(project?.name ?? "Проект")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.snappy(duration: 0.3)) {
                        _ = store.addChat(to: projectID)
                    }
                } label: {
                    Image(systemName: "square.and.pencil")
                }
                .tint(.white)
            }
        }
        .navigationDestination(for: ChatRoute.self) { route in
            ChatView(route: route)
        }
    }
}

struct ChatRow: View {
    let chat: Chat

    private var subtitle: String {
        if let last = chat.messages.last {
            return last.text.replacingOccurrences(of: "\n", with: " ")
        }
        return "Пустой чат"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left")
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 2) {
                Text(chat.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.44))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(chat.updatedAt, format: .dateTime.hour().minute())
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(.white.opacity(0.26))
        }
        .padding(13)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.1), lineWidth: 1))
    }
}

// MARK: - Чат

struct ChatView: View {
    @EnvironmentObject private var store: WorkspaceStore
    let route: ChatRoute
    @State private var draft = ""
    @FocusState private var focused: Bool

    private var chat: Chat? { store.chat(route) }
    private var messages: [ChatMessage] { chat?.messages ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if messages.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Чат создан")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                Text("Напиши первое сообщение. Модель пока не подключена — ответы появятся, когда добавим ключ и агентский цикл.")
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(.white.opacity(0.44))
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
                        }

                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(18)
                }
                .onChange(of: messages.count) { _, _ in
                    if let last = messages.last {
                        withAnimation(.snappy(duration: 0.25)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            composer
        }
        .background(Color.black)
        .navigationTitle(chat?.title ?? "Чат")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Удалить чат", role: .destructive) {
                        store.deleteChat(route)
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .tint(.white)
            }
        }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Что сделать?", text: $draft, axis: .vertical)
                .focused($focused)
                .font(.system(size: 14.5))
                .foregroundStyle(.white)
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 34, height: 34)
                    .background(.white, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
            .padding(.trailing, 8)
        }
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.white.opacity(0.1), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        withAnimation(.snappy(duration: 0.25)) {
            store.append(ChatMessage(role: .user, text: text), to: route)
        }
        draft = ""
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .assistant { Spacer(minLength: 40) }

            Text(message.text)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .padding(.horizontal, 13)
                .padding(.vertical, 10)
                .background(
                    .white.opacity(message.role == .user ? 0.10 : 0.035),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )

            if message.role == .user { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Остальные вкладки

struct AppsView: View {
    var body: some View {
        Screen(kicker: "Мини-аппы", title: "Свои штуки") {
            VStack(spacing: 12) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 24))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Пока пусто")
                    .font(.system(size: 16, weight: .semibold))
                Text("Скажи агенту в чате — он соберёт мини-апп и положит сюда.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.44))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(32)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(.white.opacity(0.16))
            )
        }
    }
}

struct AgentsView: View {
    var body: some View {
        Screen(kicker: "Агенты", title: "Кто работает") {
            VStack(spacing: 8) {
                Row(icon: "sparkle", title: "Основной", subtitle: "Универсальный · deepseek-chat")
                Row(icon: "chevron.left.forwardslash.chevron.right", title: "Кодер", subtitle: "Пишет и правит код")
                Row(icon: "house", title: "Дом", subtitle: "Бытовые задачи и списки")
            }
        }
    }
}

struct TasksView: View {
    var body: some View {
        Screen(kicker: "Панель", title: "Задачи") {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text("В работе 0")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(.white, in: Capsule())
                        .foregroundStyle(.black)
                    Text("Ждут 0")
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .overlay(Capsule().stroke(.white.opacity(0.17)))
                        .foregroundStyle(.white.opacity(0.64))
                    Spacer()
                }
                .padding(.bottom, 6)

                Text("Задач пока нет. Они появятся, когда агент начнёт работать.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.white.opacity(0.44))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct ProfileView: View {
    var body: some View {
        Screen(kicker: "Профиль", title: "Настройки") {
            VStack(spacing: 8) {
                Row(icon: "key", title: "Модель и ключи", subtitle: "deepseek-chat · Keychain")
                Row(icon: "lock.shield", title: "Разрешения", subtitle: "Файлы, календарь, микрофон")
                Row(icon: "shippingbox", title: "Версия", subtitle: "0.1 · сборка из GitHub Actions")
            }
        }
    }
}
