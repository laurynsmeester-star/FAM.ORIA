//
//  ContentView.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 3/20/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading) {
            Image("icon 1")
                .resizable()
                .scaledToFill()

            HStack {
                Text("FAMORIA")
                    .font(.title)
                    .bold()

                Image(systemName: "star.fill")
            }
        }
    }
}
