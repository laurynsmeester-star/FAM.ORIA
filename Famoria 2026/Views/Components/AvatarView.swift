//
//  AvatarView.swift
//  Famoria 2026
//
//  One small Circle avatar component used everywhere a user's headshot
//  shows up — posts, replies, chat rows, family member chips, profile
//  header, etc. When the user has uploaded a photo to Cloud Storage we
//  load it via AsyncImage; otherwise we fall back to their initials on
//  the supplied tint.
//

import SwiftUI

struct AvatarView: View {
    let name: String
    let imageURL: String?
    var size: CGFloat = 36
    var tint: Color = .purple

    var body: some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.18))

            if let imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        initials
                    }
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                initials
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }

    private var initials: some View {
        Text(Self.initials(for: name))
            .font(.system(size: size * 0.40, weight: .bold))
            .foregroundColor(tint)
    }

    static func initials(for name: String) -> String {
        let parts = name.split(separator: " ", omittingEmptySubsequences: true)
        let letters = parts.compactMap { $0.first.map(String.init) }.prefix(2)
        let result = letters.joined().uppercased()
        return result.isEmpty ? "?" : result
    }
}
