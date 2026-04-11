//
//  FamilyFeedView.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 4/1/26.
//  Copyright © 2026 LS. All rights reserved.
//

import SwiftUI


struct FamilyFeedView: View {
    
    @EnvironmentObject var appState: AppState
    @State private var newPost = ""
    
    var body: some View {
        VStack {
            
            // Create Post
            HStack {
                TextField("Share something...", text: $newPost)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
                
                Button("Post") {
                    addPost()
                }
            }
            .padding()
            
            // Feed
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(appState.posts.reversed())) { post in
                        FeedCard(post: post)
                    }
                }
                .padding()
            }
        }
    }
    
    func addPost() {
        let post = FamilyPost(
            id: UUID().uuidString,
            authorName: appState.currentUser?.name ?? "Unknown",
            content: newPost,
            timestamp: Date()
        )
        
        appState.posts.append(post)
        newPost = ""
    }
}
