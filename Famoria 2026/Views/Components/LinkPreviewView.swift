//
//  LinkPreviewView.swift
//  Famoria 2026
//
//  Tiny LinkPresentation-backed preview card that turns the first URL in
//  a piece of text (a post body, a chat message, etc.) into a tappable
//  rich card with the site's title, image, and host. Used wherever the
//  user shares an external link — news articles, social media posts,
//  YouTube videos.
//

import SwiftUI
import LinkPresentation

/// Static URL detection helper used by the rendering sites.
enum LinkExtractor {
    static func firstURL(in text: String) -> URL? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        return detector.firstMatch(in: text, range: range)?.url
    }
}

/// Compact, tappable link preview card. Renders a small spinner while the
/// metadata loads and falls back to a plain "open in Safari" pill if the
/// site doesn't expose Open Graph metadata.
struct LinkPreviewView: View {
    let url: URL
    @State private var metadata: LPLinkMetadata?
    @State private var loadFailed = false

    var body: some View {
        Button {
            #if canImport(UIKit)
            UIApplication.shared.open(url)
            #endif
        } label: {
            HStack(spacing: 10) {
                thumbnail
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(metadata?.title ?? url.host ?? url.absoluteString)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .foregroundColor(.primary)
                    Text(url.host ?? url.absoluteString)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right.square")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .task { await loadMetadata() }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let metadata,
           let provider = metadata.imageProvider {
            AsyncImageProvider(provider: provider) {
                placeholder
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.purple.opacity(0.2), Color.pink.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "link")
                .foregroundColor(.purple)
        }
    }

    private func loadMetadata() async {
        guard metadata == nil, !loadFailed else { return }
        let provider = LPMetadataProvider()
        do {
            let fetched = try await provider.startFetchingMetadata(for: url)
            await MainActor.run { self.metadata = fetched }
        } catch {
            await MainActor.run { self.loadFailed = true }
        }
    }
}

/// SwiftUI wrapper that resolves an `NSItemProvider` into a `UIImage`. Used
/// because `LPLinkMetadata.imageProvider` returns an NSItemProvider rather
/// than a ready-to-display image URL.
private struct AsyncImageProvider<Placeholder: View>: View {
    let provider: NSItemProvider
    let placeholder: () -> Placeholder
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                placeholder()
            }
        }
        .task { await load() }
    }

    private func load() async {
        let img: UIImage? = await withCheckedContinuation { (cont: CheckedContinuation<UIImage?, Never>) in
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                cont.resume(returning: object as? UIImage)
            }
        }
        await MainActor.run { self.image = img }
    }
}
