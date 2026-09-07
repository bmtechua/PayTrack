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

    private let fileManager = FileManager.default

    private let maxLogSize: UInt64 = 3 * 1024 * 1024

    private let logsFolderURL: URL

    private var currentLogURL: URL

    var fileURL: URL {
        currentLogURL
    }
    

    private init() {

        let applicationSupportURL =
            fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]

        logsFolderURL =
            applicationSupportURL.appendingPathComponent(
                "Logs",
                isDirectory: true
            )

        try? fileManager.createDirectory(
            at: logsFolderURL,
            withIntermediateDirectories: true
        )

        currentLogURL =
            logsFolderURL.appendingPathComponent(
                "anonymous.log"
            )
    }

    // MARK: - User

    func setUser(_ userID: UUID?) {

        if let userID {

            currentLogURL =
                logsFolderURL.appendingPathComponent(
                    "user-\(userID.uuidString).log"
                )

            info(
                "Logger switched to user: \(userID)"
            )

        } else {

            currentLogURL =
                logsFolderURL.appendingPathComponent(
                    "anonymous.log"
                )

            info(
                "Logger switched to anonymous session"
            )
        }
    }

    // MARK: - Logging

    func info(_ message: String) {

        logger.info(
            "\(message, privacy: .public)"
        )

        writeToFile(
            "INFO",
            message
        )
    }

    func debug(_ message: String) {

        logger.debug(
            "\(message, privacy: .public)"
        )

        writeToFile(
            "DEBUG",
            message
        )
    }

    func warning(_ message: String) {

        logger.warning(
            "\(message, privacy: .public)"
        )

        writeToFile(
            "WARNING",
            message
        )
    }

    func error(_ message: String) {

        logger.error(
            "\(message, privacy: .public)"
        )

        writeToFile(
            "ERROR",
            message
        )
    }

    // MARK: - Read log

    func readLog() -> String {

        do {

            return try String(
                contentsOf: currentLogURL,
                encoding: .utf8
            )

        } catch {

            return ""
        }
    }

    // MARK: - Clear log

    func clearLog() {

        do {

            if fileManager.fileExists(
                atPath: currentLogURL.path
            ) {

                try fileManager.removeItem(
                    at: currentLogURL
                )
            }

        } catch {

            logger.error(
                "Logger clear error: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Private

    private func writeToFile(
        _ level: String,
        _ message: String
    ) {

        let formatter = DateFormatter()
        formatter.dateFormat =
            "yyyy-MM-dd HH:mm:ss"

        let date =
            formatter.string(
                from: Date()
            )

        let line =
            "[\(date)] \(level): \(message)\n"

        guard let data =
                line.data(using: .utf8)
        else {
            return
        }

        do {

            if fileManager.fileExists(
                atPath: currentLogURL.path
            ) {

                let handle =
                    try FileHandle(
                        forWritingTo: currentLogURL
                    )

                try handle.seekToEnd()

                try handle.write(
                    contentsOf: data
                )

                try handle.close()

            } else {

                try data.write(
                    to: currentLogURL,
                    options: .atomic
                )
            }

            trimLogIfNeeded()

        } catch {

            logger.error(
                "Logger file error: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func trimLogIfNeeded() {

        guard
            let attributes =
                try? fileManager.attributesOfItem(
                    atPath: currentLogURL.path
                ),
            let fileSize =
                attributes[.size] as? UInt64,
            fileSize > maxLogSize
        else {
            return
        }

        do {

            let data =
                try Data(
                    contentsOf: currentLogURL
                )

            let startIndex =
                data.count / 2

            let trimmedData =
                data.suffix(
                    data.count - startIndex
                )

            guard
                let text =
                    String(
                        data: trimmedData,
                        encoding: .utf8
                    )
            else {
                return
            }

            let lines =
                text.components(
                    separatedBy: "\n"
                )

            let cleanText =
                lines.dropFirst().joined(
                    separator: "\n"
                )

            guard
                let cleanData =
                    cleanText.data(
                        using: .utf8
                    )
            else {
                return
            }

            try cleanData.write(
                to: currentLogURL,
                options: .atomic
            )

        } catch {

            logger.error(
                "Logger trim error: \(error.localizedDescription, privacy: .public)"
            )
        }
    }
}
