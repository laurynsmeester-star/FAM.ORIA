//
//  AppLockOverlay.swift
//  Famoria 2026
//
//  Full-screen lock screen rendered above the app content while
//  `AppLockManager.isLocked` is true. Auto-prompts for Face ID on
//  appear, with a retry button if the user dismisses.
//

import SwiftUI

struct AppLockOverlay: View {
    @EnvironmentObject var lockManager: AppLockManager
    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.95), Color.pink.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundColor(.white)
                Text("Famoria is locked")
                    .font(.title2.bold())
                    .foregroundColor(.white)
                Text("Authenticate with \(lockManager.biometryLabel) to continue.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button {
                    Task {
                        isAuthenticating = true
                        await lockManager.authenticate()
                        isAuthenticating = false
                    }
                } label: {
                    HStack(spacing: 8) {
                        if isAuthenticating {
                            ProgressView().tint(.purple)
                        } else {
                            Image(systemName: "faceid")
                        }
                        Text("Unlock")
                    }
                    .font(.headline)
                    .foregroundColor(.purple)
                    .padding(.horizontal, 28).padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(14)
                }
                .disabled(isAuthenticating)
            }
        }
        .task {
            await lockManager.authenticate()
        }
    }
}
