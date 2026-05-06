//
//  GeneralUserRegistrationFlow.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 4/3/26.
//  Copyright © 2026 LS. All rights reserved.
//

import SwiftUI

/// Complete registration flow for General Users (requires invite code to join existing family)
struct GeneralUserRegistrationFlow: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var currentStep = 0
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var matchedFamily: Family?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack {
                    // Progress indicator
                    ProgressBar(currentStep: currentStep, totalSteps: 3)
                        .padding()
                    
                    // Content based on current step
                    TabView(selection: $currentStep) {
                        // Step 1: Personal Information
                        GeneralUserPersonalInfoStepView(
                            name: $name,
                            email: $email,
                            password: $password,
                            confirmPassword: $confirmPassword,
                            errorMessage: $errorMessage
                        )
                        .tag(0)
                        
                        // Step 2: Invite Code
                        InviteCodeStepView(
                            inviteCode: $inviteCode,
                            errorMessage: $errorMessage,
                            matchedFamily: $matchedFamily,
                            validateCode: validateInviteCode
                        )
                        .tag(1)
                        
                        // Step 3: Review & Complete
                        GeneralUserReviewStepView(
                            name: name,
                            email: email,
                            familyName: matchedFamily?.name ?? "Unknown Family",
                            isLoading: $isLoading
                        )
                        .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .scrollDisabled(true)
                    
                    // Navigation buttons
                    HStack(spacing: 16) {
                        if currentStep > 0 {
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
                                Text(currentStep == 2 ? "Complete" : "Next")
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
            .navigationTitle("General User Registration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var isCurrentStepValid: Bool {
        switch currentStep {
        case 0:
            return !name.isEmpty && !email.isEmpty && email.contains("@") &&
                   !password.isEmpty && password.count >= 6 && password == confirmPassword
        case 1:
            return !inviteCode.isEmpty && inviteCode.count == 6 && matchedFamily != nil
        case 2:
            return true
        default:
            return false
        }
    }
    
    private func handleNextOrComplete() {
        errorMessage = nil
        
        if currentStep < 2 {
            withAnimation {
                currentStep += 1
            }
        } else {
            // Complete registration
            completeRegistration()
        }
    }
    
    private func validateInviteCode() {
        errorMessage = nil
        
        // Validate invite code with Firebase
        Task {
            do {
                let (familyId, familyName) = try await appState.validateInviteCode(inviteCode)
                
                await MainActor.run {
                    // Create a temporary family object for display
                    matchedFamily = Family(
                        id: familyId,
                        name: familyName,
                        members: []
                    )
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    matchedFamily = nil
                }
            }
        }
    }
    
    private func completeRegistration() {
        isLoading = true
        
        Task {
            do {
                // Step 1: Create user account with Firebase Auth
                try await appState.handleSignUp(name: name, email: email, password: password)
                
                // Step 2: Join family using the validated invite code
                try await appState.joinFamilyWithCode(inviteCode)
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                    currentStep = 0 // Go back to first step on error
                }
            }
        }
    }
}

// MARK: - Step Views

struct GeneralUserPersonalInfoStepView: View {
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
                        .foregroundColor(.blue)
                    
                    Text("Personal Information")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Tell us about yourself")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                VStack(spacing: 16) {
                    FormField(label: "Full Name", text: $name, placeholder: "John Doe")
                    
                    FormField(label: "Email", text: $email, placeholder: "email@example.com", keyboardType: .emailAddress)
                    
                    FormField(label: "Password", text: $password, placeholder: "At least 6 characters", isSecure: true)
                    
                    FormField(label: "Confirm Password", text: $confirmPassword, placeholder: "Re-enter password", isSecure: true)
                    
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

struct InviteCodeStepView: View {
    @Binding var inviteCode: String
    @Binding var errorMessage: String?
    @Binding var matchedFamily: Family?
    let validateCode: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "envelope.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.blue)
                    
                    Text("Enter Invite Code")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Get the code from your family admin")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Invite Code")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("ABC123", text: $inviteCode)
                            .textInputAutocapitalization(.characters)
                            .font(.system(.title3, design: .monospaced))
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .onChange(of: inviteCode) { oldValue, newValue in
                                // Limit to 6 characters and uppercase
                                inviteCode = String(newValue.prefix(6).uppercased())
                                if inviteCode.count == 6 {
                                    validateCode()
                                } else {
                                    matchedFamily = nil
                                }
                            }
                    }
                    
                    if let family = matchedFamily {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Code Valid!")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                
                                Text("You'll join \(family.name)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to get an invite code:")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            InstructionRow(number: 1, text: "Ask your family admin for the invite code")
                            InstructionRow(number: 2, text: "Enter the 6-character code above")
                            InstructionRow(number: 3, text: "Complete registration to join your family")
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())
            
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

struct GeneralUserReviewStepView: View {
    let name: String
    let email: String
    let familyName: String
    @Binding var isLoading: Bool
    
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
                    ReviewField(label: "Name", value: name)
                    ReviewField(label: "Email", value: email)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("You're joining")
                            .font(.headline)
                        
                        HStack {
                            Image(systemName: "house.fill")
                                .foregroundColor(.blue)
                            
                            Text(familyName)
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
                        
                        Text("Once you complete registration, you'll have access to your family's shared calendar, events, and posts.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 24)
            }
        }
    }
}

// MARK: - Shared Components

struct FormField: View {
    let label: String
    @Binding var text: String
    var placeholder: String = ""
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
                    .autocorrectionDisabled(keyboardType == .emailAddress)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
            }
        }
    }
}

struct ReviewField: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
    }
}

struct ProgressBar: View {
    let currentStep: Int
    let totalSteps: Int
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { step in
                RoundedRectangle(cornerRadius: 4)
                    .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                    .frame(height: 4)
            }
        }
    }
}

#Preview {
    GeneralUserRegistrationFlow()
        .environmentObject(AppState())
}
