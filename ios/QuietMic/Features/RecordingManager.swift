//
//  RecordingManager.swift
//  QuietMic
//

import ActivityKit
import Foundation
import QuietMicIntents

actor RecordingManager {
    static let shared = RecordingManager()

    enum RecordingError: Swift.Error, LocalizedError {
        case liveActivitiesDisabled
        case liveActivityRequestFailed

        var errorDescription: String? {
            switch self {
            case .liveActivitiesDisabled:
                return "Live Activities are disabled for QuietMic."
            case .liveActivityRequestFailed:
                return "QuietMic couldn’t start the Live Activity."
            }
        }
    }

    private(set) var isRecording = false
    private var currentSessionID: String?
    private var currentActivity: Activity<RecordingActivityAttributes>?
    private var sessionStartedAt: Date?

    func start() async throws -> String {
        if isRecording { return currentSessionID ?? "unknown" }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            agentPrint("LIVE_ACTIVITY_BLOCKED", ["reason": "disabled"])
            throw RecordingError.liveActivitiesDisabled
        }

        let sessionID = UUID().uuidString
        let attributes = RecordingActivityAttributes(runID: loadAgentRunID())
        let initialContent = RecordingActivityAttributes.ContentState(
            sessionID: sessionID,
            elapsedSeconds: 0
        )

        do {
            let activity = try Activity<RecordingActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(state: initialContent, staleDate: nil, relevanceScore: 100)
            )
            currentActivity = activity
            agentPrint("LIVE_ACTIVITY_START", ["session_id": sessionID, "activity_id": activity.id])
        } catch {
            agentPrint("LIVE_ACTIVITY_ERROR", [
                "phase": "request_failed",
                "session_id": sessionID,
                "error": "\(error)"
            ])
            throw RecordingError.liveActivityRequestFailed
        }

        currentSessionID = sessionID
        sessionStartedAt = Date()
        isRecording = true
        agentPrint("RECORDING_START", ["session_id": sessionID, "impl": "mvp"])
        return sessionID
    }

    func stop() async {
        guard isRecording else { return }

        let sessionID = currentSessionID ?? "unknown"
        let elapsed = sessionStartedAt.map { Date().timeIntervalSince($0) } ?? 0

        if let activity = currentActivity {
            let finalContent = RecordingActivityAttributes.ContentState(
                sessionID: sessionID,
                elapsedSeconds: elapsed
            )

            await activity.end(
                ActivityContent(state: finalContent, staleDate: nil),
                dismissalPolicy: .immediate
            )

            agentPrint("LIVE_ACTIVITY_END", [
                "session_id": sessionID,
                "activity_id": activity.id,
                "elapsed_s": String(format: "%.2f", elapsed)
            ])
        }

        agentPrint("RECORDING_STOP", [
            "session_id": sessionID,
            "impl": "mvp",
            "elapsed_s": String(format: "%.2f", elapsed)
        ])

        isRecording = false
        currentSessionID = nil
        currentActivity = nil
        sessionStartedAt = nil
    }
}
