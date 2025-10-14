//
//  QuietMicShortcuts.swift
//  QuietMic
//

import AppIntents

struct QuietMicShortcuts: AppShortcutsProvider {
    static let shortcutTileColor: ShortcutTileColor = .purple

    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Start recording in ${applicationName}",
                "Start ${applicationName}"
            ],
            shortTitle: "Start Recording",
            systemImageName: "mic.fill"
        )
        
        AppShortcut(
            intent: StopRecordingIntent(),
            phrases: [
                "Stop recording in ${applicationName}",
                "Stop ${applicationName}"
            ],
            shortTitle: "Stop Recording",
            systemImageName: "stop.circle.fill"
        )
    }
}
