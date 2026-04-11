//
//  LaunchScreen.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 4/3/26.
//  Copyright © 2026 LS. All rights reserved.
//

import SwiftUI

/// The initial launch screen that appears when the app opens
struct LaunchScreen: View {
    @State private var animate = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // App logo or image
                Image(systemName: "house.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .foregroundColor(.white)
                    .scaleEffect(animate ? 1.1 : 0.8)
                    .opacity(animate ? 1 : 0.5)
                
                Text("Famoria")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(animate ? 1 : 0)
                
                Text("Your Family, Connected")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                    .opacity(animate ? 1 : 0)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5)) {
                animate = true
            }
        }
    }
}

#Preview {
    LaunchScreen()
}
