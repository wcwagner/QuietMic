//
//  RecordingManager.swift
//  QuietMic
//

import ActivityKit
import AVFoundation
import Foundation
import QuietMicIntents

actor RecordingManager {
    static let shared = RecordingManager()

    enum RecordingError: Swift.Error, LocalizedError {
        case liveActivitiesDisabled
        case liveActivityRequestFailed
        case audioSessionConfigurationFailed(String)
        case recorderSetupFailed(String)
        case recorderStartFailed
        case microphonePermissionDenied
        case cannotInterruptOthers

        var errorDescription: String? {
            switch self {
            case .liveActivitiesDisabled:
                return "Live Activities are disabled for QuietMic."
            case .liveActivityRequestFailed:
                return "QuietMic couldn’t start the Live Activity."
            case .audioSessionConfigurationFailed(let reason):
                return "QuietMic couldn’t configure audio for recording. \(reason)"
            case .recorderSetupFailed(let reason):
                return "QuietMic couldn’t prepare the recorder. \(reason)"
            case .recorderStartFailed:
                return "QuietMic couldn’t start audio capture."
            case .microphonePermissionDenied:
                return "Microphone access hasn’t been granted. Open QuietMic to allow recording."
            case .cannotInterruptOthers:
                return "Audio is currently in use by another app. Stop playback or calls, then try again."
            }
        }
    }

    private(set) var isRecording = false
    private var currentSessionID: String?
    private var currentActivity: Activity<RecordingActivityAttributes>?
    private var sessionStartedAt: Date?
    private var recorder: AVAudioRecorder?
    private var currentFileURL: URL?
    private var elapsedUpdateTask: Task<Void, Never>?

    func start() async throws -> String {
        if isRecording { return currentSessionID ?? "unknown" }

        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            agentPrint("LIVE_ACTIVITY_BLOCKED", ["reason": "disabled"])
            throw RecordingError.liveActivitiesDisabled
        }

        try await ensureRecordPermission()
        try await configureAudioSessionIfNeeded()

        let sessionID = UUID().uuidString
        let attributes = RecordingActivityAttributes(runID: loadAgentRunID())
        let initialContent = RecordingActivityAttributes.ContentState(
            sessionID: sessionID,
            elapsedSeconds: 0
        )

        let fileURL = try prepareRecorder(for: sessionID)

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

        if recorder?.record() != true {
            agentPrint("RECORDING_ERROR", [
                "session_id": sessionID,
                "phase": "record_failed"
            ])
            if let activity = currentActivity {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            recorder?.stop()
            self.recorder = nil
            currentActivity = nil
            cancelElapsedUpdates()
            deactivateAudioSession()
            throw RecordingError.recorderStartFailed
        }

        currentSessionID = sessionID
        sessionStartedAt = Date()
        isRecording = true
        currentFileURL = fileURL
        if let activity = currentActivity {
            startElapsedUpdates(activity: activity, sessionID: sessionID)
        }
        agentPrint("RECORDING_START", [
            "session_id": sessionID,
            "impl": "avfoundation",
            "file": fileURL.lastPathComponent
        ])
        return sessionID
    }

    func stop() async {
        guard isRecording else { return }

        let sessionID = currentSessionID ?? "unknown"
        let elapsed = sessionStartedAt.map { Date().timeIntervalSince($0) } ?? 0
        let fileURL = currentFileURL

        if let activity = currentActivity {
            let finalContent = RecordingActivityAttributes.ContentState(
                sessionID: sessionID,
                elapsedSeconds: elapsed
            )

            cancelElapsedUpdates()
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

        if let recorder {
            recorder.stop()
            self.recorder = nil
        }

        deactivateAudioSession()

        var metadata: [String: String] = [
            "session_id": sessionID,
            "impl": "avfoundation",
            "elapsed_s": String(format: "%.2f", elapsed)
        ]

        if let fileURL,
           let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
           let fileSize = attributes[.size] as? NSNumber {
            metadata["file"] = fileURL.lastPathComponent
            metadata["bytes"] = fileSize.stringValue
        }

        agentPrint("RECORDING_STOP", metadata)

        isRecording = false
        currentSessionID = nil
        currentActivity = nil
        sessionStartedAt = nil
        currentFileURL = nil
        cancelElapsedUpdates()
    }

    private func configureAudioSessionIfNeeded() async throws {
        try await MainActor.run {
            let session = AVAudioSession.sharedInstance()
            do {
                let options: AVAudioSession.CategoryOptions = [
                    .allowBluetooth,
                    .defaultToSpeaker,
                    .mixWithOthers
                ]
                try session.setCategory(
                    .playAndRecord,
                    mode: .default,
                    options: options
                )
                try session.setActive(true, options: [])
            } catch let error as NSError where
                AVAudioSession.ErrorCode(rawValue: error.code) == .cannotInterruptOthers {
                agentPrint("AUDIO_ERROR", [
                    "phase": "cannot_interrupt_others",
                    "error": "\(error)"
                ])
                throw RecordingError.cannotInterruptOthers
            } catch {
                agentPrint("AUDIO_ERROR", [
                    "phase": "configure_session",
                    "error": "\(error)"
                ])
                throw RecordingError.audioSessionConfigurationFailed(error.localizedDescription)
            }
        }
    }

    private func ensureRecordPermission() async throws {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            return
        case .denied:
            agentPrint("AUDIO_ERROR", [
                "phase": "permission_denied"
            ])
            throw RecordingError.microphonePermissionDenied
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                session.requestRecordPermission { continuation.resume(returning: $0) }
            }
            if granted {
                agentPrint("AUDIO_PERMISSION", ["state": "granted_after_prompt"])
                return
            } else {
                agentPrint("AUDIO_ERROR", [
                    "phase": "permission_prompt_declined"
                ])
                throw RecordingError.microphonePermissionDenied
            }
        @unknown default:
            agentPrint("AUDIO_WARN", [
                "phase": "permission_unknown",
                "raw": "\(session.recordPermission.rawValue)"
            ])
            throw RecordingError.microphonePermissionDenied
        }
    }

    private func deactivateAudioSession() {
        Task { @MainActor in
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setActive(false, options: [.notifyOthersOnDeactivation])
            } catch {
                agentPrint("AUDIO_WARN", [
                    "phase": "deactivate_session",
                    "error": "\(error)"
                ])
            }
        }
    }

    private func prepareRecorder(for sessionID: String) throws -> URL {
        let url = try recordingURL(for: sessionID)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            recorder.prepareToRecord()
            self.recorder = recorder
            return url
        } catch {
            agentPrint("RECORDING_ERROR", [
                "session_id": sessionID,
                "phase": "recorder_setup",
                "error": "\(error)"
            ])
            throw RecordingError.recorderSetupFailed(error.localizedDescription)
        }
    }

    private func recordingURL(for sessionID: String) throws -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let recordingsDir = documents.appendingPathComponent("rec", isDirectory: true)

        if !FileManager.default.fileExists(atPath: recordingsDir.path) {
            try FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        }

        return recordingsDir.appendingPathComponent("\(sessionID).m4a")
    }

    private func startElapsedUpdates(activity: Activity<RecordingActivityAttributes>, sessionID: String) {
        cancelElapsedUpdates()
        elapsedUpdateTask = Task { [weak self] in
            guard let self else { return }
            await self.runElapsedUpdateLoop(activity: activity, sessionID: sessionID)
        }
    }

    private func cancelElapsedUpdates() {
        elapsedUpdateTask?.cancel()
        elapsedUpdateTask = nil
    }

    private func runElapsedUpdateLoop(activity: Activity<RecordingActivityAttributes>, sessionID: String) async {
        while !Task.isCancelled {
            await pushElapsedUpdate(activity: activity, sessionID: sessionID)
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                return
            }
        }
    }

    private func pushElapsedUpdate(activity: Activity<RecordingActivityAttributes>, sessionID: String) async {
        guard isRecording, let start = sessionStartedAt else { return }
        let elapsed = Date().timeIntervalSince(start)
        let contentState = RecordingActivityAttributes.ContentState(
            sessionID: sessionID,
            elapsedSeconds: elapsed
        )
        await activity.update(ActivityContent(state: contentState, staleDate: nil))
    }
}
