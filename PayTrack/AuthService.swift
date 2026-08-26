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
    }

    func signIn(email: String, password: String) async throws {
        let session = try await client.auth.signIn(
            email: email,
            password: password
        )

        user = session.user
    }

    func signOut() async throws {
        try await client.auth.signOut()
        user = nil
    }
}
