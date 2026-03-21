import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var showPassword = false

    private let auth = AuthService.shared

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                // Logo / Brand
                VStack(spacing: 8) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accentColor)

                    Text("SDAL")
                        .font(.system(size: 32, weight: .bold, design: .rounded))

                    Text("Social Directory")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Login form
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Username")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Enter your username", text: $username)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.username)
                            .onSubmit { focusPassword() }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Group {
                                if showPassword {
                                    TextField("Enter your password", text: $password)
                                } else {
                                    SecureField("Enter your password", text: $password)
                                }
                            }
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.password)
                            .onSubmit { login() }

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let error {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundStyle(.red)
                            Text(error)
                                .font(.callout)
                                .foregroundStyle(.red)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        login()
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            }
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.accentColor)
                    .disabled(username.isEmpty || password.isEmpty || isLoading)
                    .keyboardShortcut(.defaultAction)
                }
                .frame(width: 320)
            }

            Spacer()

            // Footer
            Text("sdalsosyal.mywire.org")
                .font(.caption)
                .foregroundStyle(.quaternary)
                .padding(.bottom, 20)
        }
        .frame(minWidth: 480, minHeight: 400)
        .background(.background)
    }

    private func focusPassword() {
        // Focus shifts naturally with tab
    }

    private func login() {
        guard !username.isEmpty, !password.isEmpty else { return }
        isLoading = true
        error = nil

        Task {
            do {
                try await auth.login(username: username, password: password)
            } catch {
                self.error = auth.error ?? error.localizedDescription
            }
            isLoading = false
        }
    }
}

#Preview {
    LoginView()
}
