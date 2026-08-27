//
//  AccountView.swift
//  PayTrack
//
//  Created by bmtech on 26.08.2026.
//

import SwiftUI
import Supabase

struct AccountView: View {

    @ObservedObject private var authService = AuthService.shared

    @State private var email = ""
    @State private var password = ""

    @State private var isRegistering = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {

        Group {

            if let user = authService.user {
                loggedInView(user: user)

            } else {
                authenticationView
            }
        }
        .navigationTitle("Акаунт")
        .task {
            await authService.loadCurrentUser()

            if authService.user != nil {
            }
        }
    }

    // MARK: - Logged in

    private func loggedInView(user: User) -> some View {
        Form {
            Section("Акаунт") {
                Text(user.email ?? "")
            }

            Section {
                Button("Вийти", role: .destructive) {
                    Task {
                        await signOut()
                    }
                }
                .disabled(isLoading)
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Login / Registration

    private var authenticationView: some View {
        Form {

            Section {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()

                SecureField("Password", text: $password)
            }

            Section {
                Button {
                    Task {
                        await authenticate()
                    }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text(
                            isRegistering
                            ? "Зареєструватися"
                            : "Увійти"
                        )
                    }
                }
                .disabled(
                    email.isEmpty ||
                    password.isEmpty ||
                    isLoading
                )
            }

            Section {
                Button {
                    isRegistering.toggle()
                    errorMessage = nil
                } label: {
                    Text(
                        isRegistering
                        ? "Вже маєте акаунт? Увійти"
                        : "Створити акаунт"
                    )
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    // MARK: - Authentication

    private func authenticate() async {

        isLoading = true
        errorMessage = nil

        do {
            if isRegistering {
                try await authService.signUp(
                    email: email,
                    password: password
                )
            } else {
                try await authService.signIn(
                    email: email,
                    password: password
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    // MARK: - Sign out

    private func signOut() async {

        isLoading = true
        errorMessage = nil

        do {
            try await authService.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
