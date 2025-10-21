//
//  RecordingActivity+Sendable.swift
//  QuietMic
//

import ActivityKit
import QuietMicIntents

@available(iOS 26, *)
extension Activity: @unchecked Sendable where Attributes == RecordingActivityAttributes {}
