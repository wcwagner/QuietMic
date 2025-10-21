//
//  QuietMicIntentsPackage.swift
//  QuietMicIntents
//
//  Registers App Intent metadata for targets that consume this package.
//  See WWDC25 “Get to know App Intents” (docs/app-intents-ios26/sources/wwdc/wwdc2025-244-get-to-know-app-intents.md:730)
//  for background on AppIntentsPackage requirements.
//

import AppIntents

@available(iOS 26, *)
public struct QuietMicIntentsPackage: AppIntentsPackage {
    public init() {}
}
