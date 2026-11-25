import SwiftUI

// MARK: - Тема

enum Theme {
    static let hPad: CGFloat = 20
    static let cardRadius: CGFloat = 22
    static let iconSide: CGFloat = 42
}

// MARK: - Каркас экрана

struct Screen<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Theme.hPad)
                .padding(.top, 10)
                .padding(.bottom, 100)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
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
            Screen {
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
    @State private var isSending = false
    @State private var activeSession: String?

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
                                Text("Напиши первое сообщение — его примет движок на телефоне.")
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
                .scrollDismissesKeyboard(.interactively)
            }

            if isSending {
                HStack(spacing: 8) {
                    ProgressView().tint(.white).scaleEffect(0.8)
                    Text("DSH работает…")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer(minLength: 0)
                    Button {
                        stop()
                    } label: {
                        Text("Остановить")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.white.opacity(0.08), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 6)
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
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Готово") { focused = false }
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

    /// Останавливает ход: ядро прекращает работу, очередь сообщений не теряется.
    private func stop() {
        guard let sessionId = activeSession else {
            isSending = false
            return
        }
        Task { @MainActor in
            if let info = CoreRuntime.shared.info, let baseURL = URL(string: info.url) {
                let client = DSHClient(base: baseURL)
                try? await client.handshake(token: info.token ?? "")
                try? await client.cancel(sessionId: sessionId)
            }
            store.append(ChatMessage(role: .assistant, text: "Остановлено"), to: route)
            isSending = false
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }

        withAnimation(.snappy(duration: 0.25)) {
            store.append(ChatMessage(role: .user, text: text), to: route)
        }
        draft = ""
        isSending = true
        LiveActivityController.shared.start(chatTitle: chat?.title ?? "Чат")

        Task { @MainActor in
            var rendered: [Int: UUID] = [:]

            let apply: ([ChatSegment]) -> Void = { segments in
                for (index, segment) in segments.enumerated() {
                    switch segment {
                    case .text(let text):
                        if let id = rendered[index] {
                            store.updateMessage(id, text: text, in: route)
                        } else {
                            let message = ChatMessage(role: .assistant, text: text)
                            store.append(message, to: route)
                            rendered[index] = message.id
                        }

                    case .tool(let name, let detail, let failed):
                        let text = detail.isEmpty ? name : "\(name) · \(detail)"
                        if let id = rendered[index] {
                            store.updateMessage(id, text: text, failed: failed, in: route)
                        } else {
                            var message = ChatMessage(role: .tool, text: text)
                            message.failed = failed
                            store.append(message, to: route)
                            rendered[index] = message.id
                        }
                    }
                }
            }

            do {
                guard let info = CoreRuntime.shared.info,
                      let baseURL = URL(string: info.url)
                else { throw DSHError.engine("ядро не запущено") }

                let client = DSHClient(base: baseURL)
                try await client.handshake(token: info.token ?? "")

                let sessionId: String
                if let existing = store.engineSession(route) {
                    sessionId = existing
                } else {
                    sessionId = try await client.createSession()
                    store.setEngineSession(sessionId, for: route)
                }
                activeSession = sessionId

                let before = (try? await client.page(sessionId: sessionId).count) ?? 0
                try await client.prompt(sessionId: sessionId, text: text)

                var reply = DSHReply()
                var signature = ""
                var lastProgress = Date()
                var hinted = false
                for _ in 0..<1200 {
                    try await Task.sleep(nanoseconds: 500_000_000)
                    let records = try await client.page(sessionId: sessionId)
                    let tail = Array(records.dropFirst(before))
                    reply = DSHParse.lastTurn(from: tail)
                    let segments = DSHParse.segments(from: tail)
                    apply(segments)

                    let fresh = "\(segments.count):\(reply.text.count)"
                    if fresh != signature {
                        signature = fresh
                        lastProgress = Date()
                    } else if !hinted, !reply.finished,
                              Date().timeIntervalSince(lastProgress) > 45 {
                        // Движок молчит: скорее всего агент ждёт ответа,
                        // а показать вопрос пока негде.
                        hinted = true
                        store.append(
                            ChatMessage(
                                role: .assistant,
                                text: "Агент ждёт ответа на вопрос, а показать его здесь пока нельзя. Нажми «Остановить» и переформулируй."
                            ),
                            to: route
                        )
                    }

                    if reply.finished { break }
                }

                if let error = reply.error {
                    store.append(ChatMessage(role: .assistant, text: "Ошибка: \(error)"), to: route)
                } else if rendered.isEmpty {
                    store.append(ChatMessage(role: .assistant, text: "Движок не ответил"), to: route)
                } else {
                    store.saveNow()
                }
                LiveActivityController.shared.finish(
                    status: reply.error == nil ? "готово" : "ошибка"
                )
            } catch {
                store.append(ChatMessage(role: .assistant, text: "Ошибка: \(error.localizedDescription)"), to: route)
                LiveActivityController.shared.finish(status: "ошибка")
            }
            activeSession = nil
            isSending = false
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        if message.role == .tool {
            toolRow
        } else {
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

    /// Строка о том, что делает агент: вызов инструмента и его исход.
    private var toolRow: some View {
        HStack(spacing: 8) {
            Image(systemName: message.failed == true ? "xmark.circle" : "arrow.turn.down.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(message.failed == true ? 0.75 : 0.4))

            Text(message.text)
                .font(.footnote.monospaced())
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(3)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(.white.opacity(message.failed == true ? 0.18 : 0.08), lineWidth: 1)
        )
    }
}

// MARK: - Остальные вкладки

struct AppsView: View {
    var body: some View {
        Screen {
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
        Screen {
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
        Screen {
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
