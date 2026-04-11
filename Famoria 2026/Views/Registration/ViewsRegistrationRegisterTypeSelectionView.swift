//
//  RegisterTypeSelectionView.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 4/3/26.
//  Copyright © 2026 LS. All rights reserved.
//

import SwiftUI

/// View where users select if they want to register as Family Admin or General User
struct RegisterTypeSelectionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var showFamilyAdminRegistration = false
    @State private var showGeneralUserRegistration = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.blue)
                        
                        Text("How would you like to register?")
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text("Choose the registration type that fits your needs")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 60)
                    
                    // Registration options
                    VStack(spacing: 20) {
                        // Family Admin option
                        Button {
                            showFamilyAdminRegistration = true
                        } label: {
                            RegistrationTypeCard(
                                icon: "crown.fill",
                                title: "Family Admin",
                                description: "Create a new family and get an invite code to share with family members",
                                color: .purple
                            )
                        }
                        .fullScreenCover(isPresented: $showFamilyAdminRegistration) {
                            FamilyAdminRegistrationFlow()
                        }
                        
                        // General User option
                        Button {
                            showGeneralUserRegistration = true
                        } label: {
                            RegistrationTypeCard(
                                icon: "person.fill",
                                title: "General User",
                                description: "Join an existing family using an invite code from your family admin",
                                color: .blue
                            )
                        }
                        .fullScreenCover(isPresented: $showGeneralUserRegistration) {
                            GeneralUserRegistrationFlow()
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
            }
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
}

/// Reusable card component for registration type selection
struct RegistrationTypeCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundColor(color)
                    .frame(width: 60, height: 60)
                    .background(color.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }
}

#Preview {
    RegisterTypeSelectionView()
}
