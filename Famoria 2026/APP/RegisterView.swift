import SwiftUI
import FirebaseAuth
import FirebaseStorage
import FirebaseCore

struct RegisterView: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var status: String?
    @State private var isLoading: Bool = false
    @State private var didRegister: Bool = false

    @FocusState private var focusedField: Field?
    enum Field { case email, password }

    private let storage = Storage.storage()
    private var sampleFileRef: StorageReference {
        storage.reference(withPath: "samples/hello.txt")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Register Test User")
                    .font(.title2)
                    .bold()

                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .focused($focusedField, equals: .email)

                SecureField("Password (≥ 6 characters)", text: $password)
                    .textContentType(.newPassword)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .focused($focusedField, equals: .password)

                if let status = status {
                    Text(status)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button(action: registerUser) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("Register")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isButtonEnabled ? Color.accentColor : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .disabled(!isButtonEnabled)

                Spacer()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Storage sample path:")
                        .font(.headline)
                    Text(sampleFileRef.fullPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom)
            }
            .padding()
            .navigationTitle("Register")
            .onAppear {
                DispatchQueue.main.async {
                    focusedField = .email
                }
            }
            .fullScreenCover(isPresented: $didRegister) {
                RootView()
            }
        }
    }

    private var isButtonEnabled: Bool {
        !email.isEmpty && password.count >= 6 && !isLoading
    }

    private func registerUser() {
        guard isButtonEnabled else { return }
        status = nil
        isLoading = true

        Task {
            do {
                _ = try await Auth.auth().createUser(withEmail: email, password: password)
                await MainActor.run {
                    status = "Registration successful!"
                    isLoading = false
                    didRegister = true
                    email = ""
                    password = ""
                }
            } catch {
                await MainActor.run {
                    status = "Registration failed: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }

    /*
    // Example async function to upload sample data to Storage (not called by default)
    func uploadSample() async throws {
        let data = "Hello Firebase Storage!".data(using: .utf8)!
        _ = try await sampleFileRef.putDataAsync(data, metadata: nil)
    }
    */
}

#Preview {
    NavigationStack {
        RegisterView()
    }
}
