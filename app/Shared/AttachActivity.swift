import ActivityKit
import Foundation

/// Общие данные для приложения и виджета: что показывать в Dynamic Island.
struct AttachActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var status: String
        var startedAt: Date
    }

    var chatTitle: String
}
