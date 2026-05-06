import SwiftUI

struct AuthView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var email = ""
    @State private var password = ""
    @State private var showFamilyAdminRegistration = false
    @State private var showGeneralUserRegistration = false
    @State private var showRegistrationPicker = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("FamoriaBackgroundTop"), Color("FamoriaBackgroundBottom")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Logo / Identity
                VStack(spacing: 12) {
                    Image(systemName: "house.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Famoria")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                // Card
                VStack(spacing: 16) {
                    Text("Welcome Back")
                        .font(.headline)
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                    
                    Button(action: { Task { await signIn() } }) {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    Button(action: { showRegistrationPicker = true }) {
                        Text("Create an account")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.9))
                )
                .shadow(radius: 20)
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
        .sheet(isPresented: $showRegistrationPicker) {
            RegistrationTypePickerView(
                showFamilyAdminFlow: $showFamilyAdminRegistration,
                showGeneralUserFlow: $showGeneralUserRegistration
            )
        }
        .fullScreenCover(isPresented: $showFamilyAdminRegistration) {
            FamilyAdminRegistrationFlow()
                .environmentObject(appState)
        }
        .fullScreenCover(isPresented: $showGeneralUserRegistration) {
            GeneralUserRegistrationFlow()
                .environmentObject(appState)
        }
    }
    
    private func signIn() async {
        do {
            try await appState.handleSignIn(email: email, password: password)
        } catch {
            // Handle authentication errors
            print("Authentication error: \(error)")
            // You can also add UI feedback here with an @State variable
        }
    }
}
// MARK: - Registration Type Picker

struct RegistrationTypePickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var showFamilyAdminFlow: Bool
    @Binding var showGeneralUserFlow: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Choose Registration Type")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Select how you'd like to join Famoria")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)
                
                VStack(spacing: 16) {
                    // Family Admin Option
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showFamilyAdminFlow = true
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "star.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.yellow)
                                
                                VStack(alignment: .leading) {
                                    Text("Family Admin")
                                        .font(.headline)
                                    
                                    Text("Create a new family")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 6) {
                                RegistrationFeature(text: "Create your family")
                                RegistrationFeature(text: "Get an invite code to share")
                                RegistrationFeature(text: "Manage family settings")
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    // General User Option
                    Button {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            showGeneralUserFlow = true
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.green)
                                
                                VStack(alignment: .leading) {
                                    Text("General User")
                                        .font(.headline)
                                    
                                    Text("Join an existing family")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 6) {
                                RegistrationFeature(text: "Enter an invite code")
                                RegistrationFeature(text: "Join your family")
                                RegistrationFeature(text: "Start connecting")
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
            .navigationTitle("Registration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct RegistrationFeature: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(.blue)
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

