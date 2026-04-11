//
//  InviteComposer.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 4/3/26.
//  Copyright © 2026 LS. All rights reserved.
//

import SwiftUI

/// Helper view for composing and sending invites
struct InviteComposer: View {
    @EnvironmentObject var appState: AppState
    @State private var email = ""
    @State private var showSuccess = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                TextField("Email address", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.roundedBorder)
                
                Button("Send") {
                    sendInvite()
                }
                .buttonStyle(.borderedProminent)
                .disabled(email.isEmpty || !email.contains("@"))
            }
            
            if showSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Invite sent!")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
    }
    
    private func sendInvite() {
        appState.createInvite(for: email)
        email = ""
        showSuccess = true
        
        // Hide success message after 2 seconds
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                showSuccess = false
            }
        }
    }
}

#Preview {
    InviteComposer()
        .environmentObject(AppState())
}
