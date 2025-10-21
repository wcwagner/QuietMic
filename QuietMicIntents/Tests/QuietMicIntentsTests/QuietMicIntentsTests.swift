import XCTest
@testable import QuietMicIntents

import AppIntents

@available(iOS 26, *)
final class QuietMicIntentsTests: XCTestCase {
    func testStartIntentInvokesRecorder() async throws {
        let recorder = RecordingControllerSpy()
        let logger = LoggerSpy()
        AppDependencyManager.shared.add {
            QuietMicIntentServices(recorder: recorder, logger: logger)
        }

        let intent = StartRecordingIntent()
        let result = try await intent.perform()

        XCTAssertTrue(result is ProvidesDialog, "Expected ProvidesDialog conformance")
        XCTAssertEqual(recorder.startCallCount, 1)
        XCTAssertEqual(logger.loggedEvents.first?.event, "INTENT_START_RECORDING")
    }
}

private final class RecordingControllerSpy: RecordingControlling, @unchecked Sendable {
    private var startCalls = 0
    private var stopCalls = 0

    func startRecordingSession() async throws -> String {
        startCalls += 1
        return "test-session"
    }

    func stopRecordingSession() async {
        stopCalls += 1
    }

    var startCallCount: Int {
        startCalls
    }
}

private final class LoggerSpy: QuietMicIntentsLogging, @unchecked Sendable {
    private(set) var loggedEvents: [(event: String, metadata: [String: String])] = []

    func log(event: String, metadata: [String: String]) {
        loggedEvents.append((event, metadata))
    }
}
