//
//  RecordingIntents.swift
//  QuietMic
//

import AppIntents

struct StartRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Recording"
    static let description = IntentDescription("Start background audio recording in QuietMic.")
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        agentPrint("INTENT_START_RECORDING", ["phase": "begin"])
        let sessionID = try await RecordingManager.shared.start()
        agentPrint("INTENT_START_RECORDING", ["phase": "end", "session_id": sessionID])

        return .result(dialog: IntentDialog("Started recording."))
    }
}

struct StopRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Recording"
    static let description = IntentDescription("Stop background audio recording in QuietMic.")
    static var supportedModes: IntentModes { .background }

    func perform() async throws -> some IntentResult {
        agentPrint("INTENT_STOP_RECORDING", ["phase": "begin"])
        await RecordingManager.shared.stop()
        agentPrint("INTENT_STOP_RECORDING", ["phase": "end"])

        return .result(dialog: IntentDialog("Stopped recording."))
    }
}
