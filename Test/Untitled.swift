import SwiftUI

struct DetailView: View {
    var body: some View {
        Text("Welcome to the Detail Page!")
            .navigationTitle("Detail")
    }
}

import SwiftUI

    struct ContentView: View {
        var body: some View {
            NavigationStack {
                VStack(spacing: 20) {
                    NavigationLink(destination: DetailView()) {
                        Text("Go to Detail View")
                }
                .buttonStyle(.borderedProminent) // Optional: styles the link as a button

                Text("This is the main content.")
            }
            .navigationTitle("Main View")
        }
    }
}
//
//  Untitled.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 3/26/26.
//

