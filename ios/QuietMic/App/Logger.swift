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
    }

    // Also log to OSLog for unified log collection
    log.info("[\(rid, privacy: .public)] \(ev, privacy: .public) \(fields.description, privacy: .public)")
}