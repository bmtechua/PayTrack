import SwiftUI

struct ChangePasswordView: View {

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject
    private var authService = AuthService.shared

    @State private var newPassword = ""
    @State private var confirmPassword = ""

    @State private var isNewPasswordVisible = false
    @State private var isConfirmPasswordVisible = false

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {

        Form {

            Section {

                HStack {

                    if isNewPasswordVisible {

                        TextField(
                            "new_password",
                            text: $newPassword
                        )

                    } else {

                        SecureField(
                            "new_password",
                            text: $newPassword
                        )
                    }

                    Button {

                        isNewPasswordVisible.toggle()

                    } label: {

                        Image(
                            systemName:
                                isNewPasswordVisible
                                ? "eye.slash"
                                : "eye"
                        )
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                HStack {

                    if isConfirmPasswordVisible {

                        TextField(
                            "confirm_password",
                            text: $confirmPassword
                        )

                    } else {

                        SecureField(
                            "confirm_password",
                            text: $confirmPassword
                        )
                    }

                    Button {

                        isConfirmPasswordVisible.toggle()

                    } label: {

                        Image(
                            systemName:
                                isConfirmPasswordVisible
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
                        await changePassword()
                    }

                } label: {

                    if isLoading {

                        ProgressView()

                    } else {

                        Text("change_password")
                            .frame(
                                maxWidth: .infinity
                            )
                    }
                }
                .disabled(
                    newPassword.isEmpty ||
                    confirmPassword.isEmpty ||
                    isLoading
                )
            }

            if let errorMessage {

                Section {

                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
        }

        .navigationTitle("change_password")
        .navigationBarTitleDisplayMode(.inline)

        .toolbar {

            ToolbarItem(
                placement: .cancellationAction
            ) {

                Button("cancel") {
                    dismiss()
                }
            }
        }

        .alert(
            "password_recovery",
            isPresented: $showSuccess
        ) {

            Button("ok") {
                dismiss()
            }

        } message: {

            Text("password_changed")
        }
    }

    // MARK: - Change password

    private func changePassword() async {

        errorMessage = nil

        let password = newPassword
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard password.count >= 6 else {

            errorMessage = String(
                localized: "password_too_short"
            )

            AppLogger.shared.error(
                "Password change failed: password too short"
            )

            return
        }

        guard password == confirmPassword else {

            errorMessage = String(
                localized: "passwords_do_not_match"
            )

            AppLogger.shared.error(
                "Password change failed: passwords do not match"
            )

            return
        }

        isLoading = true

        AppLogger.shared.info(
            "Password change attempt"
        )

        do {

            try await authService.changePassword(
                newPassword: password
            )

            AppLogger.shared.info(
                "Password changed successfully"
            )

            newPassword = ""
            confirmPassword = ""

            isLoading = false
            showSuccess = true

        } catch {

            AppLogger.shared.error(
                "Password change failed: \(error.localizedDescription)"
            )

            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
