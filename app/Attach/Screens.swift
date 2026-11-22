import SwiftUI

// MARK: - Тема

enum Theme {
    static let hPad: CGFloat = 20
    static let cardRadius: CGFloat = 22
    static let iconSide: CGFloat = 42
}

// MARK: - Каркас экрана

struct Screen<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.white)

                content()
                    .padding(.top, 20)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Theme.hPad)
            .padding(.top, 10)
            .padding(.bottom, 100)
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
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: Theme.iconSide, height: Theme.iconSide)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer(minLength: 8)

            if let trailing {
                Text(trailing)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .padding(16)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Чаты (проекты)

struct ChatsView: View {
    @EnvironmentObject private var store: WorkspaceStore
    @State private var isCreating = false
    @State private var draftName = ""

    var body: some View {
        NavigationStack {
            Screen(title: "Проекты") {
                if store.projects.isEmpty {
                    EmptyProjects()
                } else {
                    VStack(spacing: 10) {
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
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                }
                .buttonStyle(.plain)
                .glassSurface(cornerRadius: 20)
                .padding(.top, 12)
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
    }
}

struct EmptyProjects: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.system(size: 28))
                .foregroundStyle(.white.opacity(0.55))
            Text("Пока нет проектов")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Проект — это папка: чаты, файлы и рабочая папка агента.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 22)
        .background(.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 24))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
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
        HStack(spacing: 14) {
            Image(systemName: "folder")
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: Theme.iconSide, height: Theme.iconSide)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 3) {
                Text(project.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(16)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Проект

struct ProjectView: View {
    @EnvironmentObject private var store: WorkspaceStore
    let projectID: UUID

    private var project: Project? { store.project(projectID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let project {
                    if project.chats.isEmpty {
                        Text("В проекте пока нет чатов.\nСоздай первый — кнопкой справа сверху.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 28)
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
            .padding(.horizontal, Theme.hPad)
            .padding(.top, 8)
            .padding(.bottom, 100)
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
                        .font(.system(size: 17))
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
        HStack(spacing: 14) {
            Image(systemName: "bubble.left")
                .font(.system(size: 17))
                .foregroundStyle(.white)
                .frame(width: Theme.iconSide, height: Theme.iconSide)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 3) {
                Text(chat.title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text(chat.updatedAt, format: .dateTime.hour().minute())
                .font(.footnote.monospaced())
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(16)
        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: Theme.cardRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
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
                    VStack(alignment: .leading, spacing: 14) {
                        if messages.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Чат создан")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("Напиши первое сообщение. Модель пока не подключена к чату — ответы появятся, когда проведём ключ в ядро.")
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .padding(18)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 20))
                        }

                        ForEach(messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
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
        HStack(spacing: 10) {
            TextField("Что сделать?", text: $draft, axis: .vertical)
                .focused($focused)
                .font(.body)
                .foregroundStyle(.white)
                .lineLimit(1...5)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 40, height: 40)
                    .background(.white, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1)
            .padding(.trailing, 8)
        }
        .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 26))
        .overlay(
            RoundedRectangle(cornerRadius: 26)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        )
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
                .font(.body)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    .white.opacity(message.role == .user ? 0.11 : 0.04),
                    in: RoundedRectangle(cornerRadius: 20)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                )

            if message.role == .user { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Остальные вкладки

struct AppsView: View {
    var body: some View {
        Screen(title: "Свои штуки") {
            VStack(spacing: 14) {
                Image(systemName: "square.grid.2x2")
                    .font(.system(size: 28))
                    .foregroundStyle(.white.opacity(0.6))
                Text("Пока пусто")
                    .font(.headline)
                Text("Скажи агенту в чате — он соберёт мини-апп и положит сюда.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(36)
            .overlay(
                RoundedRectangle(cornerRadius: 26)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    .foregroundStyle(.white.opacity(0.16))
            )
        }
    }
}

struct AgentsView: View {
    var body: some View {
        Screen(title: "Кто работает") {
            VStack(spacing: 10) {
                Row(icon: "sparkle", title: "Основной", subtitle: "Универсальный · deepseek-chat")
                Row(icon: "chevron.left.forwardslash.chevron.right", title: "Кодер", subtitle: "Пишет и правит код")
                Row(icon: "house", title: "Дом", subtitle: "Бытовые задачи и списки")
            }
        }
    }
}

struct TasksView: View {
    var body: some View {
        Screen(title: "Задачи") {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Text("В работе 0")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.white, in: Capsule())
                        .foregroundStyle(.black)
                    Text("Ждут 0")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .overlay(Capsule().stroke(.white.opacity(0.17)))
                        .foregroundStyle(.white.opacity(0.64))
                    Spacer()
                }

                Text("Задач пока нет. Они появятся, когда агент начнёт работать.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject private var models: ModelStore
    @StateObject private var core = CoreRuntime.shared
    @State private var showSetup = false

    private var coreSubtitle: String {
        switch core.phase {
        case .ready(let node): return "Node \(node) · на связи"
        case .starting: return "запускается…"
        case .failed(let reason): return reason
        case .idle: return "не запущено"
        }
    }

    var body: some View {
        NavigationStack {
            Screen(title: "Настройки") {
                VStack(spacing: 10) {
                    Button {
                        showSetup = true
                    } label: {
                        Row(
                            icon: "key",
                            title: "Модель и ключ",
                            subtitle: models.hasKey
                                ? "\(models.provider.title) · \(models.model)"
                                : "не подключено"
                        )
                    }
                    .buttonStyle(.plain)

                    Row(icon: "square.stack.3d.up", title: "Ядро", subtitle: coreSubtitle)
                    Row(icon: "lock.shield", title: "Разрешения", subtitle: "Файлы, календарь, микрофон")
                    Row(icon: "shippingbox", title: "Версия", subtitle: "0.1 · сборка из GitHub Actions")
                }
            }
            .sheet(isPresented: $showSetup) {
                ModelSetupView()
            }
        }
    }
}
