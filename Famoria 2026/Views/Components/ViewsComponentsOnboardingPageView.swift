//
//  OnboardingPageView.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 4/3/26.
//  Copyright © 2026 LS. All rights reserved.
//

import SwiftUI

/// Wrapper view for onboarding - now redirects to registration flows
struct OnboardingPageView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        RegisterTypeSelectionView()
    }
}

/// Model for onboarding page content
struct FamoriaOnboardingPage: Identifiable {
    let id = UUID()
    let image: String
    let title: String
    let subtitle: String
}

#Preview {
    OnboardingPageView()
        .environmentObject(AppState())
}
