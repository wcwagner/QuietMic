//
//  QuietMicShortcuts.swift
//  QuietMicIntents
//

import AppIntents

@available(iOS 26, *)
public struct QuietMicShortcuts: AppShortcutsProvider {
    public static let shortcutTileColor: ShortcutTileColor = .purple

    public init() {}

    public static var appShortcuts: [AppShortcut] {
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
