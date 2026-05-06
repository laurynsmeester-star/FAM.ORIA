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
                Image("Logo1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 320, height: 320)
                    .foregroundColor(.black)
                    .scaleEffect(animate ? 1.5 : 0.5)
                    .opacity(animate ? 1 : 0.5)

            
                
                Text("Famoria")
                    .font(.custom("SnellRoundhand-Bold", size: 48).italic()) // Cursive font
                    .foregroundColor(Color(red: 0, green: 0.4, blue: 0))
                    .opacity(animate ? 1 : 0)

                
                Text("Your Family, Connected")
                    .font(.headline)
                    .foregroundColor(Color(red: 0, green: 0.4, blue: 0))
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
