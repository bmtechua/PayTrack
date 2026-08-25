//
//  AppLogger.swift
//  PayTrack
//
//  Created by bmtech on 22.08.2026.
//

import Foundation
import os

final class AppLogger {

    static let shared = AppLogger()

    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "PayTrack",
        category: "App"
    )

    let fileURL: URL

    private init() {

        let fileManager = FileManager.default

        let folderURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]

        try? fileManager.createDirectory(
            at: folderURL,
            withIntermediateDirectories: true
        )

        fileURL = folderURL.appendingPathComponent("PayTrack.log")
    }

    func info(_ message: String) {

        logger.info("\(message, privacy: .public)")
        writeToFile("INFO", message)
    }

    func debug(_ message: String) {

        logger.debug("\(message, privacy: .public)")
        writeToFile("DEBUG", message)
    }

    func warning(_ message: String) {

        logger.warning("\(message, privacy: .public)")
        writeToFile("WARNING", message)
    }

    func error(_ message: String) {

        logger.error("\(message, privacy: .public)")
        writeToFile("ERROR", message)
    }

    private func writeToFile(
        _ level: String,
        _ message: String
    ) {

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let date = formatter.string(from: Date())

        let line = "[\(date)] \(level): \(message)\n"

        guard let data = line.data(using: .utf8) else {
            return
        }

        do {

            if FileManager.default.fileExists(
                atPath: fileURL.path
            ) {

                let handle = try FileHandle(
                    forWritingTo: fileURL
                )

                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()

            } else {

                try data.write(
                    to: fileURL,
                    options: .atomic
                )
            }

        } catch {

            logger.error(
                "Logger file error: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}

