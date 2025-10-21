//
//  QuietMicIntentsBindings.swift
//  QuietMic
//
//  Hooks the app’s runtime into the QuietMicIntents package without defaulting to @MainActor,
//  aligning with SE-0466 guidance (docs/swift-6.2-concurrency/sources/swift-evolution/SE-0466-control-default-actor-isolation.md:42).
//

import AppIntents
import QuietMicIntents

private struct AgentPrintLogger: QuietMicIntentsLogging {
    func log(event: String, metadata: [String: String]) {
        agentPrint(event, metadata)
    }
}

extension RecordingManager: RecordingControlling {
    func startRecordingSession() async throws -> String {
        try await start()
    }

    func stopRecordingSession() async {
        await stop()
    }
}

enum QuietMicIntentsBindings {
    static func configure() {
        // Register dependency once during app launch per AppDependencyManager guidance.
        AppDependencyManager.shared.add {
            QuietMicIntentServices(
                recorder: RecordingManager.shared,
                logger: AgentPrintLogger()
            )
        }
    }
}
