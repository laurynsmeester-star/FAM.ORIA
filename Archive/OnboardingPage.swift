//
//  OnboardingPage.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 3/31/26.
//  Copyright © 2026 LS. All rights reserved.
//

import SwiftUI

struct OnboardingContent {
    let imageName: String
    let title: String
    let subtitle: String
}

struct OnboardingPage: View {
    let content: OnboardingContent
    var skip: () -> Void = {}

    var body: some View {
        OnboardingCardView(content: content)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
            .padding(.top, 20)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: skip) {
                        Text("Skip")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Onboarding")
                        .font(.headline)
                }
            }
    }
}

struct OnboardingCardView: View {
    let content: OnboardingContent

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: content.imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 150)
                .foregroundColor(.blue)

            Text(content.title)
                .font(.title)
                .fontWeight(.bold)

            Text(content.subtitle)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal)

            Spacer()
        }
    }
}
#Preview("Onboarding Page") {
    NavigationStack {
        OnboardingPage(
            content: OnboardingContent(
                imageName: "sparkles",
                title: "Welcome to Famoria",
                subtitle: "Organize your family life with shared tasks, events, and more."
            ),
            skip: {}
        )
    }
}

