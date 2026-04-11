//
//  FinalStep.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 3/31/26.
//  Copyright © 2026 LS. All rights reserved.
//

import SwiftUI

struct FinalStep: View {
    let name: String
    
    var body: some View {
        
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Welcome, \(name.isEmpty ? "there" : name) 💙")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Your family space is ready.")
                .foregroundColor(.gray)
        }
    }
}
