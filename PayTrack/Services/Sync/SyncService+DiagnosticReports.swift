//
//  SyncService+DiagnosticReports.swift
//  PayTrack
//
//  Created by bmtech on 08.09.2026.
//


import Foundation
import Supabase

extension SyncService {

    // MARK: - Send diagnostic report

    func sendDiagnosticReport(
        problemDescription: String,
        appVersion: String,
        appBuild: String,
        deviceModel: String,
        systemVersion: String,
        log: String
    ) async throws {

        let user = try await client.auth.session.user

        struct DiagnosticReport: Encodable {

            let user_id: UUID
            let email: String?
            let problem_description: String
            let app_version: String
            let app_build: String
            let device_model: String
            let system_version: String
            let log: String
        }

        let report = DiagnosticReport(
            user_id: user.id,
            email: user.email,
            problem_description: problemDescription,
            app_version: appVersion,
            app_build: appBuild,
            device_model: deviceModel,
            system_version: systemVersion,
            log: log
        )

        try await client
            .from("diagnostic_reports")
            .insert(report)
            .execute()

        AppLogger.shared.info(
            "Diagnostic report sent successfully",
            category: .app
        )
    }
}
