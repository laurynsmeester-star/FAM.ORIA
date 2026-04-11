//
//  OnboardingPageView.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 3/31/26.
//  Copyright © 2026 LS. All rights reserved.
//


import SwiftUI

struct LegacyOnboardingPageView: View {
    
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false
    
    @State private var step = 0
    @State private var name: String = ""
    @State private var inviteEmail: String = ""
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color("FamoriaBackgroundTop"), Color("FamoriaBackgroundBottom")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                
                Spacer()
                
                // 🔄 Animated Step Transitions
                ZStack {
                    switch step {
                    case 0:
                        WelcomeStep()
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        
                    case 1:
                        NameInputStep(name: $name)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        
                    case 2:
                        InviteStep(phoneNumber: $inviteEmail)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        
                    case 3:
                        FinalStep(name: name)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        
                    default:
                        EmptyView()
                    }
                }
                .animation(.easeInOut, value: step)
                
                Spacer()
                
                // CTA Button Logic
                Button(action: nextStep) {
                    Text(buttonTitle)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                        .padding(.horizontal, 24)
                }
                .padding(.bottom, 30)
            }
        }
    }
    
    var buttonTitle: String {
        switch step {
        case 3: return "Enter Famoria"
        default: return "Continue"
        }
    }
    
    func nextStep() {
        if step < 3 {
            withAnimation {
                step += 1
            }
        } else {
            hasCompletedOnboarding = true
        }
    }
}
