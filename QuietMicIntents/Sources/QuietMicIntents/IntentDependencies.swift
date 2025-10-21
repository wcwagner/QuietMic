//
//  IntentDependencies.swift
//  QuietMicIntents
//
//  Hosts dependency surface for App Intents. Consumers register implementations via
//  AppDependencyManager as described in WWDC25 “Get to know App Intents”.
//

import Foundation

/// Behavior expected from any recorder implementation used by App Intents.
public protocol RecordingControlling: Sendable {
    func startRecordingSession() async throws -> String
    func stopRecordingSession() async
}

/// Lightweight logging surface the host app can back with structured output.
public protocol QuietMicIntentsLogging: Sendable {
    func log(event: String, metadata: [String: String])
}

/// Aggregates all services App Intents rely on, registered with `AppDependencyManager`.
public struct QuietMicIntentServices: Sendable {
    public var recorder: any RecordingControlling
    public var logger: any QuietMicIntentsLogging

    public init(recorder: any RecordingControlling, logger: any QuietMicIntentsLogging) {
        self.recorder = recorder
        self.logger = logger
    }
}
