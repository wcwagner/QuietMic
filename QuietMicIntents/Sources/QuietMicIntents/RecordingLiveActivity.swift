//
//  RecordingLiveActivity.swift
//  QuietMicIntents
//
//  Package-friendly Live Activity types keep UI modules in the host app.
//

import ActivityKit
import Foundation

public struct RecordingActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var sessionID: String
        public var elapsedSeconds: Double

        public init(sessionID: String, elapsedSeconds: Double) {
            self.sessionID = sessionID
            self.elapsedSeconds = elapsedSeconds
        }
    }

    public var runID: String

    public init(runID: String) {
        self.runID = runID
    }
}
