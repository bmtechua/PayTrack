//
//  AuthService.swift
//  PayTrack
//

import Foundation
import Combine
import Supabase
import Auth

@MainActor
final class AuthService: ObservableObject {

    static let shared = AuthService()

    private let client = SupabaseManager.shared.client

    @Published private(set) var user: User?

    @Published var isPasswordRecovery = false

    private init() {}

    private var authStateTask: Task<Void, Never>?

    // Prevent duplicate sync after manual login.
    private var hasCompletedAuthSync = false

    // MARK: - Auth state listener

    func startAuthStateListener() {

        authStateTask?.cancel()

        authStateTask = Task { [weak self] in

            guard let self else {
                return
            }

            for await (event, session)
            in client.auth.authStateChanges {

                switch event {

                case .passwordRecovery:

                    AppLogger.shared.info(
                        "Password recovery event received"
                    )

                    self.isPasswordRecovery = true
                    self.user = session?.user

                case .signedIn:

                    AppLogger.shared.info(
                        "Auth signed in event received"
                    )

                    self.user = session?.user

                case .signedOut:

                    AppLogger.shared.info(
                        "Auth signed out event received"
                    )

                    self.user = nil
                    self.isPasswordRecovery = false
                    self.hasCompletedAuthSync = false

                default:
                    break
                }
            }
        }
    }

    // MARK: - Load current user

    func loadCurrentUser() async {

        do {

            user = try await client.auth.session.user

            AppLogger.shared.info(
                "Current user loaded: \(user?.email ?? "unknown")"
            )

            if let userID = user?.id {

                AppLogger.shared.setUser(userID)

                await SyncService.shared.prepareForUser(
                    userID
                )

                await SyncService.shared.startCategoriesRealtime()
                await SyncService.shared.startExpensesRealtime()
                await SyncService.shared.startProfileRealtime()
                
                if !hasCompletedAuthSync {

                    // Load settings from Supabase first.
                    await SyncService.shared.loadProfileSettings()

                    // Then sync categories and expenses.
                    await SyncService.shared.syncAll()

                    hasCompletedAuthSync = true
                }
            }

        } catch {

            user = nil
        }
    }

    // MARK: - Sign up

    func signUp(
        email: String,
        password: String
    ) async throws {

        let cleanEmail =
            email
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        let response =
            try await client.auth.signUp(
                email: cleanEmail,
                password: password
            )

        user = response.user

        AppLogger.shared.setUser(
            response.user.id
        )

        AppLogger.shared.info(
            "Registration successful: \(user?.email ?? cleanEmail)"
        )

        await SyncService.shared.prepareForUser(
            response.user.id
        )

        await SyncService.shared.startCategoriesRealtime()
        await SyncService.shared.startExpensesRealtime()
        await SyncService.shared.startProfileRealtime()
        await PushDeviceService.shared.registerDevice()

        AppLogger.shared.info(
            "Registration sync started"
        )

        // First registration:
        // upload local settings to Supabase first.
        await SyncService.shared.syncProfileSettings()

        // Then sync categories and expenses.
        await SyncService.shared.syncAll()

        hasCompletedAuthSync = true
    }

    // MARK: - Sign in

    func signIn(
        email: String,
        password: String
    ) async throws {

        let cleanEmail =
            email
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        let session =
            try await client.auth.signIn(
                email: cleanEmail,
                password: password
            )

        user = session.user

        AppLogger.shared.setUser(
            session.user.id
        )

        AppLogger.shared.info(
            "Login successful: \(user?.email ?? cleanEmail)"
        )

        await SyncService.shared.prepareForUser(
            session.user.id
        )

        await SyncService.shared.startCategoriesRealtime()
        await SyncService.shared.startExpensesRealtime()
        await SyncService.shared.startProfileRealtime()
        await PushDeviceService.shared.registerDevice()

        AppLogger.shared.info(
            "Login sync started"
        )

        // Existing user:
        // load settings from Supabase first.
        await SyncService.shared.loadProfileSettings()

        // Then sync categories and expenses.
        await SyncService.shared.syncAll()

        hasCompletedAuthSync = true
    }

    // MARK: - Change password

    func changePassword(
        newPassword: String
    ) async throws {

        try await client.auth.update(
            user: UserAttributes(
                password: newPassword
            )
        )

        AppLogger.shared.info(
            "Password changed successfully"
        )
    }

    // MARK: - Sign out

    func signOut() async throws {

        //AppLogger.shared.info(
          //  "Logout attempt"
        //)

        // Cancel any running full sync.
        SyncService.shared.cancelFullSync()

        // Stop Premium realtime.
        await SyncService.shared.stopCategoriesRealtime()
        await SyncService.shared.stopExpensesRealtime()
        await SyncService.shared.stopProfileRealtime()

        // Remove only active Premium session state.
        // Premium local data remains on device.
        await SyncService.shared.clearLocalData()

        try await client.auth.signOut()

        user = nil

        AppLogger.shared.info(
            "Logout successful. Premium local data preserved."
        )

        AppLogger.shared.setUser(nil)
    }


    // MARK: - Reset password

    func resetPassword(
        email: String
    ) async throws {

        let cleanEmail =
            email
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                .lowercased()

        let redirectURL =
            URL(
                string: "paytrack://reset-password"
            )!

        AppLogger.shared.info(
            "Password recovery requested: \(cleanEmail)"
        )

        try await client.auth.resetPasswordForEmail(
            cleanEmail,
            redirectTo: redirectURL
        )

        AppLogger.shared.info(
            "Password recovery email sent: \(cleanEmail)"
        )
    }
}
