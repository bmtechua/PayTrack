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
    @State private var showForgotPassword = false
    
    @State private var showChangePassword = false

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

        // MARK: - Forgot password

        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(email: email)
        }
        .sheet(isPresented: $showChangePassword) {
            NavigationStack {
                ChangePasswordView()
            }
        }
        .onChange(of: authService.isPasswordRecovery) { _, isRecovery in
            if isRecovery {
                showChangePassword = true
            }
        }

        // MARK: - Error alert

        .alert(
            "error",
            isPresented: Binding(
                get: {
                    errorMessage != nil
                },
                set: {
                    if !$0 {
                        errorMessage = nil
                    }
                }
            )
        ) {

            if errorMessage == String(
                localized: "invalid_login_credentials"
            ) {

                Button("forgot_password") {

                    AppLogger.shared.info(
                        "Forgot password selected from login error"
                    )

                    errorMessage = nil
                    showForgotPassword = true
                }

                Button("ok", role: .cancel) {
                    errorMessage = nil
                }

            } else {

                Button("ok", role: .cancel) {
                    errorMessage = nil
                }
            }

        } message: {

            Text(errorMessage ?? "")
        }
    }

    // MARK: - Logged in

    private func loggedInView(user: User) -> some View {

        Form {

            Section("account") {

                Text(user.email ?? "")
            }

            Section {

                NavigationLink {

                    ChangePasswordView()

                } label: {

                    Text("change_password")
                }

                Button("sign_out", role: .destructive) {

                    AppLogger.shared.info(
                        "Logout attempt"
                    )

                    Task {
                        await signOut()
                    }
                }
                .disabled(isLoading)
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

                    AppLogger.shared.info(
                        isRegistering
                        ? "Registration mode selected"
                        : "Login mode selected"
                    )

                } label: {

                    Text(
                        isRegistering
                        ? "already_have_account_sign_in"
                        : "create_account"
                    )
                }
            }
        }
    }

    // MARK: - Authentication

    private func authenticate() async {

        isLoading = true
        errorMessage = nil

        let cleanEmail = email
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()

        if isRegistering {

            AppLogger.shared.info(
                "Registration attempt: \(cleanEmail)"
            )

        } else {

            AppLogger.shared.info(
                "Login attempt: \(cleanEmail)"
            )
        }

        do {

            if isRegistering {

                try await authService.signUp(
                    email: cleanEmail,
                    password: password
                )

                AppLogger.shared.info(
                    "Registration completed: \(cleanEmail)"
                )

            } else {

                try await authService.signIn(
                    email: cleanEmail,
                    password: password
                )

                AppLogger.shared.info(
                    "Login completed: \(cleanEmail)"
                )
            }

        } catch {

            AppLogger.shared.error(
                isRegistering
                ? "Registration failed: \(error.localizedDescription)"
                : "Login failed: \(error.localizedDescription)"
            )

            if !isRegistering {

                errorMessage = String(
                    localized: "invalid_login_credentials"
                )

            } else {

                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    // MARK: - Sign out

    private func signOut() async {

        isLoading = true
        errorMessage = nil

        do {

            try await authService.signOut()

            AppLogger.shared.info(
                "Logout successful"
            )

        } catch {

            AppLogger.shared.error(
                "Logout failed: \(error.localizedDescription)"
            )

            errorMessage = error.localizedDescription
        }

        isLoading = false
    }
}
