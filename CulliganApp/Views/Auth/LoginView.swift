import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var viewModel
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    enum Field {
        case email, password
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // App icon and title
                VStack(spacing: 12) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.cyan.gradient)

                    Text("Culligan")
                        .font(.largeTitle.bold())

                    Text("Water Usage Analytics")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Login form
                VStack(spacing: 16) {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .email)
                        .padding()
                        .background(.fill.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
                        .padding()
                        .background(.fill.quaternary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        Task {
                            await viewModel.login(email: email, password: password)
                        }
                    } label: {
                        Group {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.cyan)
                    .disabled(email.isEmpty || password.isEmpty || viewModel.isLoading)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)

                Spacer()
                Spacer()

                Text("Sign in with your Culligan Connect account")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthViewModel())
}
