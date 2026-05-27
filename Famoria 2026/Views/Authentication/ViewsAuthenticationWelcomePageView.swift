//
//  WelcomePageView.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 4/3/26.
//  Copyright © 2026 LS. All rights reserved.
//

import SwiftUI
import AuthenticationServices

/// The welcome page where users can sign in or register
struct WelcomePageView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSignIn = false
    @State private var showRegister = false
    @State private var appleSignInError: String?
    @State private var showAppleError = false

    /// Handles the Sign in with Apple flow (translated from appleAuthCallback.ts)
    @StateObject private var appleService = AppleSignInService()

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 40) {
                    Spacer()

                    // App branding
                    VStack(spacing: 16) {
                        Image(systemName: "house.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.blue)

                        Text("Welcome to Famoria")
                            .font(.system(size: 36, weight: .bold))
                            .multilineTextAlignment(.center)

                        Text("Keep your family connected and organized")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    Spacer()

                    // Action buttons
                    VStack(spacing: 14) {
                        // Sign In with Apple
                        // Mirrors the TS redirect logic: new user → Onboarding, existing → Home
                        SignInWithAppleButton(.signIn) { request in
                            let controller = appleService.makeAuthorizationController()
                            // The request is configured inside makeAuthorizationController();
                            // this closure satisfies the SwiftUI API contract.
                            _ = controller
                        } onCompletion: { _ in
                            // Handled via appleService.onCompletion below
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 54)
                        .cornerRadius(12)
                        .onAppear { configureAppleService() }

                        // Divider
                        HStack {
                            Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                            Text("or").font(.caption).foregroundColor(.secondary)
                            Rectangle().fill(Color.secondary.opacity(0.3)).frame(height: 1)
                        }

                        // Email Sign In
                        Button {
                            showSignIn = true
                        } label: {
                            Text("Sign In with Email")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .sheet(isPresented: $showSignIn) {
                            SignInView()
                        }

                        // Register
                        Button {
                            showRegister = true
                        } label: {
                            Text("Register")
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
                        .sheet(isPresented: $showRegister) {
                            RegisterTypeSelectionView()
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 60)
                }
            }
            .alert("Sign In Failed", isPresented: $showAppleError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(appleSignInError ?? "An unknown error occurred.")
            }
        }
    }

    // MARK: - Apple Sign In Wiring

    private func configureAppleService() {
        appleService.onCompletion = { user, isNewUser, error in
            if let error {
                appleSignInError = error.localizedDescription
                showAppleError = true
                return
            }
            guard let user else { return }

            // Update AppState — mirrors the TS session creation + redirect logic
            appState.currentUser = user
            appState.isAuthenticated = true

            if let familyId = user.familyId {
                Task { await appState.loadFamilyData(familyId: familyId) }
            }
            appState.observeChats()
            appState.startListeningToNotifications()

            // isNewUser == true  → AppState/RootView will show Onboarding
            // isNewUser == false → AppState/RootView will show Home
            // (RootView already gates on isAuthenticated + familyId, so no extra
            //  navigation call is needed here)
            if isNewUser {
                appState.deepLinkPage = nil // let RootView detect missing familyId → Onboarding
            }
        }
    }
}

#Preview {
    WelcomePageView()
        .environmentObject(AppState())
}
