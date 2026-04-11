//
//  FeedCard.swift
//  Famoria 2026
//
//  Created by Lauryn Smeester on 4/1/26.
//  Copyright © 2026 LS. All rights reserved.
//


struct FeedCard: View {
    
    let post: FamilyPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            Text(post.authorName)
                .font(.headline)
            
            Text(post.content)
            
            Text(post.timestamp.formatted())
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.9))
        )
        .shadow(radius: 5)
    }
}