import Foundation
import Combine
import Supabase

@MainActor
final class AuthService: ObservableObject {

    static let shared = AuthService()

    private let client = SupabaseManager.shared.client

    @Published private(set) var user: User?

    private init() {}

    // MARK: - Load current user

    func loadCurrentUser() async {

        do {

            user = try await client.auth.session.user

            AppLogger.shared.info(
                "Current user loaded: \(user?.email ?? "unknown")"
            )

            if let userID = user?.id {

                await SyncService.shared.prepareForUser(userID)

                await SyncService.shared.startCategoriesRealtime()
                await SyncService.shared.startExpensesRealtime()
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

        let cleanEmail = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let response = try await client.auth.signUp(
            email: cleanEmail,
            password: password
        )

        user = response.user

        AppLogger.shared.info(
            "Registration successful: \(user?.email ?? cleanEmail)"
        )

        await SyncService.shared.prepareForUser(
            response.user.id
        )

        await SyncService.shared.createDefaultCategories(
            for: response.user.id
        )
        await SyncService.shared.startCategoriesRealtime()

        AppLogger.shared.info(
            "Registration sync started"
        )

        await SyncService.shared.syncAll()
    }

    // MARK: - Sign in

    func signIn(
        email: String,
        password: String
    ) async throws {

        let cleanEmail = email
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let session = try await client.auth.signIn(
            email: cleanEmail,
            password: password
        )

        user = session.user

        AppLogger.shared.info(
            "Login successful: \(user?.email ?? cleanEmail)"
        )

        await SyncService.shared.prepareForUser(
            session.user.id
        )
        await SyncService.shared.startCategoriesRealtime()

        AppLogger.shared.info(
            "Login sync started"
        )

        await SyncService.shared.syncAll()
    }

    // MARK: - Sign out

    func signOut() async throws {
        
        await SyncService.shared.stopCategoriesRealtime()

        try await client.auth.signOut()

        user = nil

        AppLogger.shared.info(
            "Logout successful"
        )
    }
}
