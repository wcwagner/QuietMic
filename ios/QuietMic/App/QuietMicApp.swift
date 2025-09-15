//
//  QuietMicApp.swift
//  QuietMic
//
//  Created by William Wagner on 9/13/25.
//

import SwiftUI
import SwiftData

@main
struct QuietMicApp: App {
    var sharedModelContainer: ModelContainer = {
        agentPrint("APP_INIT", ["phase": "model_container_setup"])
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            agentPrint("APP_INIT", ["phase": "model_container_ready"])
            return container
        } catch {
            agentPrint("APP_ERROR", ["phase": "model_container_failed", "error": "\(error)"])
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        agentPrint("APP_LAUNCH", ["phase": "scene_building"])
        return WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
