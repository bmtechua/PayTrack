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

    private let maxLogSize: UInt64 = 1 * 1024 * 1024

    private let logsFolderURL: URL

    private var currentLogURL: URL

    var fileURL: URL {
        currentLogURL
    }

    // MARK: - Log Category

    enum LogCategory: String {
        case app = "APP"
        case auth = "AUTH"
        case profile = "PROFILE"
        case sync = "SYNC"
        case realtime = "REALTIME"
        case coreData = "CORE DATA"
    }

    // MARK: - Init

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
                "Logger switched to user: \(userID)",
                category: .auth
            )

        } else {
            currentLogURL =
                logsFolderURL.appendingPathComponent(
                    "anonymous.log"
                )

            clearLog()

            info(
                "Logger switched to anonymous session",
                category: .auth
            )
        }
    }

    // MARK: - Logging

    func info(_ message: String) {

        info(
            message,
            category: .app
        )
    }

    func debug(_ message: String) {

        debug(
            message,
            category: .app
        )
    }

    func warning(_ message: String) {

        warning(
            message,
            category: .app
        )
    }

    func error(_ message: String) {

        error(
            message,
            category: .app
        )
    }

    // MARK: - Categorized Logging

    func info(
        _ message: String,
        category: LogCategory
    ) {

        logger.info(
            "[\(category.rawValue)] \(message, privacy: .public)"
        )

        writeToFile(
            "INFO",
            category,
            message
        )
    }

    func debug(
        _ message: String,
        category: LogCategory
    ) {

        logger.debug(
            "[\(category.rawValue)] \(message, privacy: .public)"
        )

        writeToFile(
            "DEBUG",
            category,
            message
        )
    }

    func warning(
        _ message: String,
        category: LogCategory
    ) {

        logger.warning(
            "[\(category.rawValue)] \(message, privacy: .public)"
        )

        writeToFile(
            "WARNING",
            category,
            message
        )
    }

    func error(
        _ message: String,
        category: LogCategory
    ) {

        logger.error(
            "[\(category.rawValue)] \(message, privacy: .public)"
        )

        writeToFile(
            "ERROR",
            category,
            message
        )
    }

    // MARK: - Read Log

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

    // MARK: - Clear Log

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
        _ category: LogCategory,
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
            "[\(date)] \(level) [\(category.rawValue)]: \(message)\n"

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
