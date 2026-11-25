import Foundation
import SwiftUI

// MARK: - Данные

struct ChatMessage: Identifiable, Codable, Hashable {
    enum Role: String, Codable { case user, assistant }

    var id = UUID()
    var role: Role
    var text: String
    var date = Date()
}

struct Chat: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var createdAt = Date()
    var updatedAt = Date()
    var messages: [ChatMessage] = []
    /// Сессия внутри DSH. Появляется при первом сообщении.
    var dshSessionId: String? = nil
}

struct Project: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var createdAt = Date()
    var chats: [Chat] = []
}

struct ChatRoute: Hashable {
    let projectID: UUID
    let chatID: UUID
}

// MARK: - Хранилище

/// Проекты и чаты лежат одним JSON в Application Support.
@MainActor
final class WorkspaceStore: ObservableObject {
    @Published private(set) var projects: [Project] = []

    private let fileURL: URL

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("workspace.json")
        load()
    }

    // MARK: Чтение

    func project(_ id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    func chat(_ route: ChatRoute) -> Chat? {
        guard let project = project(route.projectID) else { return nil }
        return project.chats.first { $0.id == route.chatID }
    }

    // MARK: Проекты

    @discardableResult
    func addProject(name: String) -> Project {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let project = Project(name: trimmed.isEmpty ? "Проект \(projects.count + 1)" : trimmed)
        projects.append(project)
        save()
        return project
    }

    func deleteProject(_ id: UUID) {
        projects.removeAll { $0.id == id }
        save()
    }

    // MARK: Чаты

    @discardableResult
    func addChat(to projectID: UUID) -> Chat? {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else { return nil }
        let chat = Chat(title: "Чат \(projects[index].chats.count + 1)")
        projects[index].chats.insert(chat, at: 0)
        save()
        return chat
    }

    func deleteChat(_ route: ChatRoute) {
        guard let index = projects.firstIndex(where: { $0.id == route.projectID }) else { return }
        projects[index].chats.removeAll { $0.id == route.chatID }
        save()
    }

    func append(_ message: ChatMessage, to route: ChatRoute) {        guard let pIndex = projects.firstIndex(where: { $0.id == route.projectID }),
              let cIndex = projects[pIndex].chats.firstIndex(where: { $0.id == route.chatID })
        else { return }

        projects[pIndex].chats[cIndex].messages.append(message)
        projects[pIndex].chats[cIndex].updatedAt = message.date

        if projects[pIndex].chats[cIndex].title.hasPrefix("Чат "),
           message.role == .user {
            let title = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            projects[pIndex].chats[cIndex].title = String(title.prefix(40))
        }
        save()
    }

    /// Обновляет текст сообщения — так ответ проявляется по мере генерации.
    func updateMessage(_ id: UUID, text: String, in route: ChatRoute, persist: Bool = false) {
        guard let pIndex = projects.firstIndex(where: { $0.id == route.projectID }),
              let cIndex = projects[pIndex].chats.firstIndex(where: { $0.id == route.chatID }),
              let mIndex = projects[pIndex].chats[cIndex].messages.firstIndex(where: { $0.id == id })
        else { return }

        projects[pIndex].chats[cIndex].messages[mIndex].text = text
        if persist {
            projects[pIndex].chats[cIndex].updatedAt = Date()
            save()
        }
    }

    // MARK: DSH

    func engineSession(_ route: ChatRoute) -> String? {
        chat(route)?.dshSessionId
    }

    func setEngineSession(_ id: String, for route: ChatRoute) {
        guard let pIndex = projects.firstIndex(where: { $0.id == route.projectID }),
              let cIndex = projects[pIndex].chats.firstIndex(where: { $0.id == route.chatID })
        else { return }
        projects[pIndex].chats[cIndex].dshSessionId = id
        save()
    }

    // MARK: Диск

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        projects = (try? decoder.decode([Project].self, from: data)) ?? []
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(projects) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

// MARK: - Стекло

extension View {
    /// На iOS 26 — системное жидкое стекло, на старых — тонкий материал.
    @ViewBuilder
    func glassSurface(cornerRadius: CGFloat = 20) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            self.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}
