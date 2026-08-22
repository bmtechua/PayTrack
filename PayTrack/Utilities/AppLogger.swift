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

    private init() {}

    func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
    }

    func debug(_ message: String) {
        logger.debug("\(message, privacy: .public)")
    }

    func warning(_ message: String) {
        logger.warning("\(message, privacy: .public)")
    }

    func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}

