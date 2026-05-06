//
//  FeedCard.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 4/3/26.
//  Copyright © 2026 LS. All rights reserved.
//

import SwiftUI

/// Reusable card component for displaying posts in the feed
struct FeedCard: View {
    let post: FamilyPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author header
            HStack {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(.headline)
                    
                    Text(post.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Post content
            Text(post.content)
                .font(.body)
                .lineLimit(nil)
            
            // Interaction bar (placeholder for future features)
            HStack(spacing: 20) {
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                        Text("Like")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Button(action: {}) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                        Text("Comment")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

#Preview {
    FeedCard(post: FamilyPost(
        id: "1",
        authorName: "John Doe",
        content: "Had a wonderful family dinner tonight! Looking forward to our upcoming trip.",
        timestamp: Date()
    ))
    .padding()
    .background(Color(.systemGroupedBackground))
}
