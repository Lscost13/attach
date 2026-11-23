import ActivityKit
import Foundation

/// Одна живая активность на приложение: чат «думает» — видно в Dynamic Island.
@MainActor
final class LiveActivityController {
    static let shared = LiveActivityController()

    private var activity: Activity<AttachActivityAttributes>?

    func start(chatTitle: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        if activity != nil {
            update(status: "думает", title: chatTitle)
            return
        }
        let attributes = AttachActivityAttributes(chatTitle: chatTitle)
        let state = AttachActivityAttributes.ContentState(
            title: chatTitle,
            status: "думает",
            startedAt: .now
        )
        activity = try? Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: nil)
        )
    }

    func update(status: String, title: String? = nil) {
        guard let activity else { return }
        let current = activity.content.state
        let state = AttachActivityAttributes.ContentState(
            title: title ?? current.title,
            status: status,
            startedAt: current.startedAt
        )
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func finish(status: String, after seconds: Double = 6) {
        guard let activity else { return }
        update(status: status)
        self.activity = nil
        Task {
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
