import SwiftUI

struct ForgotPasswordView: View {

    @Environment(\.dismiss)
    private var dismiss

    @ObservedObject
    private var authService = AuthService.shared

    @State private var email: String

    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    init(email: String = "") {

        _email = State(
            initialValue: email
        )
    }

    var body: some View {

        NavigationStack {

            Form {

                Section {

                    TextField(
                        "email",
                        text: $email
                    )
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                }

                Section {

                    Button {

                        Task {
                            await sendResetEmail()
                        }

                    } label: {

                        if isLoading {

                            ProgressView()

                        } else {

                            Text("send_reset_email")
                                .frame(
                                    maxWidth: .infinity
                                )
                        }
                    }
                    .disabled(
                        email
                            .trimmingCharacters(
                                in: .whitespacesAndNewlines
                            )
                            .isEmpty ||
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

            .navigationTitle("forgot_password")
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
        }

        .alert(
            "password_recovery",
            isPresented: $showSuccess
        ) {

            Button("ok") {
                dismiss()
            }

        } message: {

            Text("password_reset_email_sent")
        }

        .presentationDetents([.medium])
    }

    // MARK: - Send reset email

    private func sendResetEmail() async {

        errorMessage = nil
        isLoading = true

        let cleanEmail = email
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            .lowercased()

        AppLogger.shared.info(
            "Password recovery attempt: \(cleanEmail)"
        )

        do {

            try await authService.resetPassword(
                email: cleanEmail
            )

            AppLogger.shared.info(
                "Password recovery request successful: \(cleanEmail)"
            )

            isLoading = false
            showSuccess = true

        } catch {

            AppLogger.shared.error(
                "Password recovery failed: \(error.localizedDescription)"
            )

            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
