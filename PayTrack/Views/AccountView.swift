import SwiftUI
import Supabase

struct AccountView: View {

    @ObservedObject
    private var authService = AuthService.shared

    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
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
        .navigationTitle("account")
        .task {
            await authService.loadCurrentUser()
        }
    }

    // MARK: - Logged in

    private func loggedInView(user: User) -> some View {

        Form {

            Section("account") {

                Text(user.email ?? "")
            }

            Section {

                Button("sign_out", role: .destructive) {

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

                TextField(
                    "email",
                    text: $email
                )
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()

                HStack {

                    if isPasswordVisible {

                        TextField(
                            "password",
                            text: $password
                        )

                    } else {

                        SecureField(
                            "password",
                            text: $password
                        )
                    }

                    Button {

                        isPasswordVisible.toggle()

                    } label: {

                        Image(
                            systemName:
                                isPasswordVisible
                                ? "eye.slash"
                                : "eye"
                        )
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
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
                            ? "register"
                            : "sign_in"
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
                        ? "already_have_account_sign_in"
                        : "create_account"
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

