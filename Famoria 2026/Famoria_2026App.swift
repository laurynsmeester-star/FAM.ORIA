//
//  Famoria_2026App.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 3/20/26.
//

import SwiftUI

@main
struct Famoria_2026App: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

// Root view extracted from previous inline content
struct RootView: View {
    var body: some View {
        ZStack {
            Color(.mint)
                .ignoresSafeArea()

            VStack {
                // LOG_INSTALL
                
                
                Text("Famoria")

                Image("icon 1")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 300)

                HStack {
                }
            }
        }
    }
}
#Preview("RootView") {
    RootView()
}

