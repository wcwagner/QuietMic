//
//  RecordingLiveActivityWidget.swift
//  QuietMicLiveActivityExtension
//
//  Minimal Live Activity surfaces recording progress for App Intent sessions.
//

import ActivityKit
import QuietMicIntents
import SwiftUI
import WidgetKit

@available(iOS 26, *)
@main
struct RecordingLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        RecordingLiveActivityWidget()
    }
}

@available(iOS 26, *)
struct RecordingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            RecordingLiveActivityLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    RecordingLiveActivityExpandedView(context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    RecordingLiveActivityElapsedLabel(elapsedSeconds: context.state.elapsedSeconds)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.tint)
            } compactTrailing: {
                RecordingLiveActivityElapsedLabel(elapsedSeconds: context.state.elapsedSeconds)
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "mic.fill")
            }
        }
    }
}

@available(iOS 26, *)
private struct RecordingLiveActivityLockScreenView: View {
    let context: ActivityViewContext<RecordingActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("QuietMic")
                .font(.headline)

            Text("Recording in progress")
                .font(.subheadline)

            RecordingLiveActivityElapsedLabel(elapsedSeconds: context.state.elapsedSeconds)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .activityBackgroundTint(.black.opacity(0.25))
        .activitySystemActionForegroundColor(.white)
    }
}

@available(iOS 26, *)
private struct RecordingLiveActivityExpandedView: View {
    let context: ActivityViewContext<RecordingActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recording")
                .font(.headline)

            RecordingLiveActivityElapsedLabel(elapsedSeconds: context.state.elapsedSeconds)
                .font(.title3.monospacedDigit())
                .foregroundStyle(.tint)

            Text("Session \(context.state.sessionID.prefix(8))")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Session \(context.state.sessionID)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

@available(iOS 26, *)
private struct RecordingLiveActivityElapsedLabel: View {
    let elapsedSeconds: Double

    var body: some View {
        Text(elapsedSeconds.formattedRecordingDuration)
            .accessibilityLabel("\(elapsedSeconds.formattedRecordingDuration) elapsed")
    }
}

@available(iOS 26, *)
private extension Double {
    var formattedRecordingDuration: String {
        let clamped = max(0, self)
        let formatter = RecordingLiveActivityDurationFormatter.shared
        return formatter.string(from: clamped) ?? "0:00"
    }
}

@available(iOS 26, *)
private enum RecordingLiveActivityDurationFormatter {
    static let shared: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        formatter.unitsStyle = .positional
        return formatter
    }()
}
