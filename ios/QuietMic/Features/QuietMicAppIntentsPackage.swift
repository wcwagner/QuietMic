//
//  QuietMicAppIntentsPackage.swift
//  QuietMic
//
//  Registers the packaged intents per WWDC25 guidance
//  (docs/app-intents-ios26/sources/wwdc/wwdc2025-244-get-to-know-app-intents.md:739).
//

import AppIntents
import QuietMicIntents

@available(iOS 26, *)
public struct QuietMicAppPackage: AppIntentsPackage {
    public static var includedPackages: [any AppIntentsPackage.Type] {
        [QuietMicIntentsPackage.self]
    }

    public init() {}
}
