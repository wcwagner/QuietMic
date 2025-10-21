//
//  RecordingIntents.swift
//  QuietMicIntents
//

import AppIntents

@available(iOS 26, *)
public struct StartRecordingIntent: AppIntent {
    public static let title: LocalizedStringResource = "Start Recording"
    public static let description = IntentDescription("Start background audio recording in QuietMic.")
    public static var supportedModes: IntentModes { .background }

    @Dependency
    private var services: QuietMicIntentServices

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        services.logger.log(event: "INTENT_START_RECORDING", metadata: ["phase": "begin"])
        let sessionID = try await services.recorder.startRecordingSession()
        services.logger.log(event: "INTENT_START_RECORDING", metadata: ["phase": "end", "session_id": sessionID])
        return .result(dialog: IntentDialog("Started recording."))
    }
}

@available(iOS 26, *)
public struct StopRecordingIntent: AppIntent {
    public static let title: LocalizedStringResource = "Stop Recording"
    public static let description = IntentDescription("Stop background audio recording in QuietMic.")
    public static var supportedModes: IntentModes { .background }

    @Dependency
    private var services: QuietMicIntentServices

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        services.logger.log(event: "INTENT_STOP_RECORDING", metadata: ["phase": "begin"])
        await services.recorder.stopRecordingSession()
        services.logger.log(event: "INTENT_STOP_RECORDING", metadata: ["phase": "end"])
        return .result(dialog: IntentDialog("Stopped recording."))
    }
}
