//
//  AuthService.swift
//  PayTrack
//
//  Created by bmtech on 26.08.2026.
//

import Foundation
import Combine
import Supabase

@MainActor
final class AuthService: ObservableObject {

    static let shared = AuthService()

    private let client = SupabaseManager.shared.client

    @Published private(set) var user: User?

    private init() {
    }

    func loadCurrentUser() async {

        do {

            user = try await client.auth.session.user

            AppLogger.shared.info(
                "Current user loaded: \(user?.email ?? "unknown")"
            )

        } catch {

            user = nil
        }
    }

    func signUp(email: String, password: String) async throws {

        let response = try await client.auth.signUp(
            email: email,
            password: password
        )

        user = response.user

        AppLogger.shared.info(
            "Registration successful: \(user?.email ?? email)"
        )

        // Якщо після реєстрації вже є активна сесія —
        // синхронізуємо локальні дані.
        do {

            _ = try await client.auth.session

            AppLogger.shared.info(
                "Registration sync started"
            )

            await SyncService.shared.syncAll()

        } catch {

            AppLogger.shared.info(
                "Registration sync skipped: no active session"
            )
        }
    }

    func signIn(email: String, password: String) async throws {

        let session = try await client.auth.signIn(
            email: email,
            password: password
        )

        user = session.user

        AppLogger.shared.info(
            "Login successful: \(user?.email ?? email)"
        )

        AppLogger.shared.info(
            "Login sync started"
        )

        await SyncService.shared.syncAll()
    }

    func signOut() async throws {

        try await client.auth.signOut()

        user = nil

        AppLogger.shared.info(
            "Logout successful"
        )
    }
}
