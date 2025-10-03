//
//  Logger.swift
//  VideoMaster Pro
//
//  Created by Sergey on 22.09.2025.
//

import Foundation

class Logger {
    static let shared = Logger()

    private let logFileURL: URL
    private let dateFormatter: DateFormatter

    init() {
        // Create logs directory in Documents
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logsDir = documentsDir.appendingPathComponent("VideoMaster Pro Logs")

        do {
            try FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        } catch {
            print("Error creating logs directory: \(error)")
        }

        let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .none)
        let logFileName = "VideoMaster_Log_\(dateString.replacingOccurrences(of: "/", with: "-")).txt"
        logFileURL = logsDir.appendingPathComponent(logFileName)

        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    }

    func log(_ message: String, level: LogLevel = .info) {
        let timestamp = dateFormatter.string(from: Date())
        let logEntry = "[\(timestamp)] [\(level.rawValue.uppercased())] \(message)\n"

        print(logEntry.trimmingCharacters(in: .newlines)) // Print to console

        // Write to file
        do {
            if !FileManager.default.fileExists(atPath: logFileURL.path) {
                try logEntry.write(to: logFileURL, atomically: true, encoding: .utf8)
            } else {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                fileHandle.seekToEndOfFile()
                try fileHandle.write(contentsOf: logEntry.data(using: .utf8)!)
                fileHandle.closeFile()
            }
        } catch {
            print("Error writing to log file: \(error)")
        }
    }

    func logError(_ message: String, error: Error? = nil) {
        var fullMessage = message
        if let error = error {
            fullMessage += " - Error: \(error.localizedDescription)"
        }
        log(fullMessage, level: .error)
    }

    func getLogFileURL() -> URL {
        return logFileURL
    }

    func getRecentLogs(lines: Int = 50) -> String {
        do {
            let content = try String(contentsOf: logFileURL, encoding: .utf8)
            let allLines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            let recentLines = allLines.suffix(lines)
            return recentLines.joined(separator: "\n")
        } catch {
            return "Error reading log file: \(error.localizedDescription)"
        }
    }

    enum LogLevel: String {
        case info
        case warning
        case error
        case debug
    }
}
