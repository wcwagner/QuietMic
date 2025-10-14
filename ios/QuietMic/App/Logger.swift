//
//  Logger.swift
//  QuietMic
//
//  Agent-friendly logging infrastructure
//

import Foundation
import OSLog

let log = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "agent")

struct AgentConfig: Codable {
    let run_id: String
    let ts: String
}

func loadAgentRunID() -> String {
    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("agent.json")

    guard let data = try? Data(contentsOf: url),
          let config = try? JSONDecoder().decode(AgentConfig.self, from: data)
    else {
        return "unknown"
    }

    return config.run_id
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
        // One line JSON to stdout; devicectl --console captures this.
        print(jsonString)
        
        // Also persist to on-device file to survive app restarts
        if let handle = getPersistentLogFileHandle(),
           let logLine = (jsonString + "\n").data(using: .utf8) {
            try? handle.seekToEnd()
            try? handle.write(contentsOf: logLine)
            try? handle.close()
        }
    }

    // Also log to OSLog for unified log collection
    log.info("[\(rid, privacy: .public)] \(ev, privacy: .public) \(fields.description, privacy: .public)")
}