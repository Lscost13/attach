import ActivityKit
import SwiftUI
import WidgetKit

struct AttachLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AttachActivityAttributes.self) { context in
            lockScreen(context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(context.attributes.chatTitle)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(context.state.status)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.startedAt, style: .timer)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(width: 54, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.status == "думает" ? "ellipsis" : "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text(context.state.status)
                            .font(.caption2)
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            } compactTrailing: {
                Image(systemName: context.state.status == "думает" ? "ellipsis" : "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, isActive: context.state.status == "думает")
            } minimal: {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .keylineTint(.white)
        }
    }

    private func lockScreen(_ context: ActivityViewContext<AttachActivityAttributes>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.chatTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(context.state.status)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer(minLength: 8)

            Text(context.state.startedAt, style: .timer)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(16)
        .activityBackgroundTint(.black)
        .activitySystemActionForegroundColor(.white)
    }
}
