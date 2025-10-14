//
//  Logger.swift
//  QuietMic
//
//  Agent-friendly logging infrastructure
//

import Foundation
import OSLog

let log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "agent")

func loadAgentRunID() -> String {
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("agent.json")

    guard let data = try? Data(contentsOf: url),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let runID = json["run_id"] as? String
    else {
        return "unknown"
    }

    return runID
}

private func getPersistentLogFileHandle() -> FileHandle? {
    let fm = FileManager.default
    let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
    let logsDir = docsURL.appendingPathComponent("logs")
    
    try? fm.createDirectory(at: logsDir, withIntermediateDirectories: true)
    
    let logFile = logsDir.appendingPathComponent("app.jsonl")
    if !fm.fileExists(atPath: logFile.path) {
        fm.createFile(atPath: logFile.path, contents: nil)
    }
    
    return try? FileHandle(forWritingTo: logFile)
}

func agentPrint(_ ev: String, _ fields: [String: String] = [:]) {
    let rid = loadAgentRunID()
    var dict = fields
    dict["ev"] = ev
    dict["run_id"] = rid
    dict["ts"] = ISO8601DateFormatter().string(from: Date())

    if let jsonData = try? JSONSerialization.data(withJSONObject: dict),
       let jsonString = String(data: jsonData, encoding: .utf8) {
        print(jsonString)
        
        if let handle = getPersistentLogFileHandle(),
           let logLine = (jsonString + "\n").data(using: .utf8) {
            try? handle.seekToEnd()
            try? handle.write(contentsOf: logLine)
            try? handle.close()
        }
    }

    log.info("[\(rid, privacy: .public)] \(ev, privacy: .public) \(fields.description, privacy: .public)")
}
