//
//  ContentView.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 3/20/26.
//

import SwiftUI

struct ContentView: View {
    // SwiftUI state replacing the invalid React useState
    @State private var currentUser: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image("Image 2")
                .resizable()
                .scaledToFit()
                .frame(height: 620)
                .clipShape(RoundedRectangle(cornerRadius: 16))
    
            if !currentUser.isEmpty {
                Text("Welcome, \(currentUser)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            } else {
                Text("Welcome")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
                   

        }
        .padding()
        // Example of loading the user in SwiftUI (placeholder)
        .task {
            // TODO: Replace with your real loading logic
            // Simulate setting a current user so the view compiles and runs
            if currentUser.isEmpty {
                currentUser = "Guest"
            }
        }
    }
}

#Preview {
    ContentView()
}

import SwiftUI
import AuthenticationServices // For Apple Sign In
#if canImport(GoogleSignInSwift)
import GoogleSignInSwift       // Requires GoogleSignIn SDK package
#endif

struct LaunchView: View {
    @State private var showOnboarding = false
    @State private var showSignInContainer = false

    var body: some View {
        VStack(spacing: 30) {
            Text("Welcome")
                .font(.system(size: 42, weight: .black))
                .padding(.top, 60)

            Spacer()

            // 1. Social Login Buttons
            VStack(spacing: 12) {
                // Apple Sign In Button
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.email, .fullName]
                } onCompletion: { result in
                    // Logic to handle Apple Login success
                    showOnboarding = true
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .cornerRadius(12)

                // Google Sign In Button (conditionally compiled)
                #if canImport(GoogleSignInSwift)
                GoogleSignInButton(action: {
                    // Logic to trigger GIDSignIn.sharedInstance.signIn
                    showOnboarding = true
                })
                .frame(height: 50)
                #else
                Button {
                    // GoogleSignInSwift not available; provide a fallback or prompt to install SDK
                    showOnboarding = true
                } label: {
                    HStack {
                        Image(systemName: "g.circle.fill")
                        Text("Continue with Google")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(height: 50)
                #endif
            }
            .padding(.horizontal)

            // 2. Original Manual HStack Buttons
            HStack(spacing: 20) {
                Button("Sign In") {
                    showSignInContainer = true
                }
                .buttonStyle(.glass) // iOS 26+ style
                .frame(maxWidth: .infinity)

                Button("Register") {
                    showOnboarding = true
                }
                .buttonStyle(.glassProminent)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
        // Destinations
        .sheet(isPresented: $showSignInContainer) {
            LoginContainerView()
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingPageView()
        }
    }
}







