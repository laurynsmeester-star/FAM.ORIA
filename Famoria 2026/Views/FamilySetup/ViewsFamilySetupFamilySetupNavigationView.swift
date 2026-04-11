//
//  FamilySetupNavigationView.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 4/3/26.
//  Copyright © 2026 LS. All rights reserved.
//

import SwiftUI

/// View shown when user is authenticated but doesn't have a family yet
struct FamilySetupNavigationView: View {
    @EnvironmentObject var appState: AppState
    @State private var showCreateFamily = false
    @State private var showJoinFamily = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Image(systemName: "house.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.blue)
                        
                        Text("One More Step!")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Create a family or join an existing one")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    VStack(spacing: 16) {
                        Button {
                            showCreateFamily = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Create a Family")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .sheet(isPresented: $showCreateFamily) {
                            CreateFamilyView()
                        }
                        
                        Button {
                            showJoinFamily = true
                        } label: {
                            HStack {
                                Image(systemName: "person.2.fill")
                                Text("Join a Family")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.white)
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                        }
                        .sheet(isPresented: $showJoinFamily) {
                            JoinFamilyView()
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    Spacer()
                    
                    Button("Sign Out") {
                        Task {
                            await appState.signOut()
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

/// View for creating a new family
struct CreateFamilyView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var familyName = ""
    @State private var generatedCode = ""
    @State private var showCode = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    if !showCode {
                        VStack(spacing: 16) {
                            Image(systemName: "house.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.blue)
                            
                            Text("Create Your Family")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        .padding(.top, 60)
                        
                        FormField(label: "Family Name", text: $familyName, placeholder: "The Smith Family")
                            .padding(.horizontal, 24)
                        
                        Spacer()
                        
                        Button {
                            createFamily()
                        } label: {
                            Text("Create Family")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(!familyName.isEmpty ? Color.blue : Color.gray)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                        .disabled(familyName.isEmpty)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                    } else {
                        VStack(spacing: 24) {
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.green)
                            
                            Text("Family Created!")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your Invite Code")
                                    .font(.headline)
                                
                                HStack {
                                    Text(generatedCode)
                                        .font(.system(.title, design: .monospaced))
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                    
                                    Spacer()
                                    
                                    Button {
                                        UIPasteboard.general.string = generatedCode
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(10)
                                
                                Text("Share this code with family members so they can join. You can find it later in settings.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 24)
                            
                            Spacer()
                            
                            Button {
                                dismiss()
                            } label: {
                                Text("Continue")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                        }
                        .padding(.top, 60)
                    }
                }
            }
            .navigationTitle(showCode ? "" : "Create Family")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !showCode {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    private func createFamily() {
        guard let user = appState.currentUser else { return }
        
        let family = Family(
            id: UUID().uuidString,
            name: familyName.isEmpty ? "My Family" : familyName,
            members: [user]
        )
        
        var updatedUser = user
        updatedUser.familyId = family.id
        updatedUser.role = .admin
        
        // Generate invite code
        let letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        generatedCode = String((0..<6).map { _ in letters.randomElement()! })
        
        appState.currentFamily = family
        appState.currentUser = updatedUser
        
        withAnimation {
            showCode = true
        }
    }
}

/// View for joining an existing family
struct JoinFamilyView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    
    @State private var inviteCode = ""
    @State private var matchedFamily: Family?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .foregroundColor(.blue)
                        
                        Text("Join a Family")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Enter the invite code from your family admin")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 60)
                    
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
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                    
                    Button {
                        joinFamily()
                    } label: {
                        Text("Join Family")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(matchedFamily != nil ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(matchedFamily == nil)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Join Family")
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
    
    private func validateCode() {
        // In a real app, query backend for family with this code
        // For demo, create a mock family
        if inviteCode.count == 6 {
            matchedFamily = Family(
                id: "family-\(inviteCode.lowercased())",
                name: "The Smith Family",
                members: []
            )
        }
    }
    
    private func joinFamily() {
        guard var family = matchedFamily, var user = appState.currentUser else { return }
        
        user.familyId = family.id
        user.role = .member
        family.members.append(user)
        
        appState.currentUser = user
        appState.currentFamily = family
        
        dismiss()
    }
}

#Preview {
    FamilySetupNavigationView()
        .environmentObject(AppState())
}
