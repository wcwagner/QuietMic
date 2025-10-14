//
//  RecordingManager.swift
//  QuietMic
//

import Foundation
import AVFoundation

actor RecordingManager {
    static let shared = RecordingManager()

    private(set) var isRecording = false
    private var currentSessionID: String?

    func start() async throws -> String {
        if isRecording { return currentSessionID ?? "unknown" }

        let id = UUID().uuidString
        currentSessionID = id
        isRecording = true
        agentPrint("RECORDING_START", ["session_id": id, "impl": "mvp"])
        return id
    }

    func stop() async {
        guard isRecording else { return }
        agentPrint("RECORDING_STOP", ["session_id": currentSessionID ?? "unknown", "impl": "mvp"])
        isRecording = false
        currentSessionID = nil
    }
}
