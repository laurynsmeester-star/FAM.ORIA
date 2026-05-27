//
//  FamilyAdminRegistrationFlow.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 4/3/26.
//  Copyright © 2026 LS. All rights reserved.
//

import SwiftUI

/// Complete registration flow for Family Admins (creates family + gets invite code)
struct FamilyAdminRegistrationFlow: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var currentStep = 0
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var familyName = ""
    @State private var generatedInviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var registrationComplete = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack {
                    // Progress indicator
                    RegistrationProgressBar(currentStep: min(currentStep, 2), totalSteps: 3)
                        .padding()
                    
                    // Content based on current step
                    TabView(selection: $currentStep) {
                        // Step 1: Personal Information
                        PersonalInfoStepView(
                            name: $name,
                            email: $email,
                            password: $password,
                            confirmPassword: $confirmPassword,
                            errorMessage: $errorMessage
                        )
                        .tag(0)

                        // Step 2: Family Information
                        FamilyInfoStepView(
                            familyName: $familyName,
                            errorMessage: $errorMessage
                        )
                        .tag(1)

                        // Step 3: Review
                        ReviewStepView(
                            name: name,
                            email: email,
                            familyName: familyName
                        )
                        .tag(2)

                        // Step 4: Invite Code
                        FamilyCreatedStepView(inviteCode: generatedInviteCode)
                        .tag(3)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .scrollDisabled(true)
                    
                    // Navigation buttons
                    HStack(spacing: 16) {
                        if currentStep > 0 && !registrationComplete {
                            Button {
                                withAnimation {
                                    currentStep -= 1
                                }
                            } label: {
                                Text("Back")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.gray.opacity(0.2))
                                    .foregroundColor(.primary)
                                    .cornerRadius(10)
                            }
                        }

                        Button {
                            handleNextOrComplete()
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else {
                                Text(registrationComplete ? "Done" : (currentStep == 2 ? "Create Account" : "Next"))
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            }
                        }
                        .background(isCurrentStepValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(!isCurrentStepValid || isLoading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Family Admin Registration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !registrationComplete {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            .interactiveDismissDisabled(registrationComplete)
        }
    }
    
    private var isCurrentStepValid: Bool {
        switch currentStep {
        case 0:
            return !name.isEmpty && !email.isEmpty && email.contains("@") &&
                   !password.isEmpty && password.count >= 6 && password == confirmPassword
        case 1:
            return !familyName.isEmpty
        case 2, 3:
            return true
        default:
            return false
        }
    }

    private func handleNextOrComplete() {
        errorMessage = nil

        if registrationComplete {
            dismiss()
        } else if currentStep < 2 {
            withAnimation {
                currentStep += 1
            }
        } else {
            completeRegistration()
        }
    }

    private func completeRegistration() {
        isLoading = true

        Task {
            do {
                try await appState.handleSignUp(name: name, email: email, password: password)
                try await appState.createFamily(name: familyName)
                let code = try await appState.generateInviteCode()

                await MainActor.run {
                    generatedInviteCode = code
                    registrationComplete = true
                    isLoading = false
                    withAnimation {
                        currentStep = 3
                    }
                }
            } catch {
                await MainActor.run {
                    print("Registration error: \(error.localizedDescription)")
                    print("Full error details: \(error)")
                    if let nsError = error as NSError? {
                        print("Error domain: \(nsError.domain)")
                        print("Error code: \(nsError.code)")
                        print("Error userInfo: \(nsError.userInfo)")
                    }

                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

}

// MARK: - Step Views

struct PersonalInfoStepView: View {
    @Binding var name: String
    @Binding var email: String
    @Binding var password: String
    @Binding var confirmPassword: String
    @Binding var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.purple)
                    
                    Text("Personal Information")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Tell us about yourself")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                VStack(spacing: 16) {
                    RegistrationFormField(label: "Full Name", text: $name, placeholder: "John Doe")
                    
                    RegistrationFormField(label: "Email", text: $email, placeholder: "email@example.com", keyboardType: .emailAddress)
                    
                    RegistrationFormField(label: "Password", text: $password, placeholder: "At least 6 characters", isSecure: true)
                    
                    RegistrationFormField(label: "Confirm Password", text: $confirmPassword, placeholder: "Re-enter password", isSecure: true)
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

struct FamilyInfoStepView: View {
    @Binding var familyName: String
    @Binding var errorMessage: String?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "house.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.purple)
                    
                    Text("Create Your Family")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Choose a name for your family")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                VStack(spacing: 16) {
                    RegistrationFormField(label: "Family Name", text: $familyName, placeholder: "The Smith Family")
                    
                    Text("As a Family Admin, you'll be able to invite members and manage your family's shared content.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

struct ReviewStepView: View {
    let name: String
    let email: String
    let familyName: String

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.green)

                    Text("Review & Complete")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Verify your information")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)

                VStack(spacing: 16) {
                    RegistrationReviewField(label: "Name", value: name)
                    RegistrationReviewField(label: "Email", value: email)
                    RegistrationReviewField(label: "Family Name", value: familyName)
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

struct FamilyCreatedStepView: View {
    let inviteCode: String

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "party.popper.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.purple)

                    Text("Welcome to Famoria!")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Your family has been created")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Your Family Invite Code")
                        .font(.headline)

                    HStack {
                        Text(inviteCode)
                            .font(.system(.title, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.blue)

                        Spacer()

                        Button {
                            UIPasteboard.general.string = inviteCode
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)

                    Text("Share this code with family members so they can join your family. You can find it later in your profile settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Reusable Components

struct RegistrationProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Rectangle()
                    .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .cornerRadius(2)
            }
        }
    }
}

struct RegistrationFormField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var keyboardType: UIKeyboardType = .default
    var isSecure: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textContentType(.password)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(keyboardType == .emailAddress ? .never : .words)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
            }
        }
    }
}

struct RegistrationReviewField: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}

#Preview {
    FamilyAdminRegistrationFlow()
        .environmentObject(AppState())
}
