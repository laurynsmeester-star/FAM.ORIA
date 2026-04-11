//
//  NameInputStep.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 3/31/26.
//  Copyright © 2026 LS. All rights reserved.
//

import SwiftUI

struct NameInputStep: View {
    @Binding var name: String
    
    var body: some View {
        VStack(spacing: 20) {
            Text("What should we call you?")
                .font(.title2)
                .fontWeight(.bold)
            
            TextField("Your name", text: $name)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .padding(.horizontal, 30)
        }
    }
}
