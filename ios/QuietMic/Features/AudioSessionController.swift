//
//  AudioSessionController.swift
//  QuietMic
//

import AVFoundation

actor AudioSessionController {
    static let shared = AudioSessionController()

    func configureForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP])
        try session.setActive(true, options: [])
        agentPrint("AUDIO_SESSION_CONFIGURED")
    }

    func teardown() {
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])
        agentPrint("AUDIO_SESSION_TORN_DOWN")
    }
}
