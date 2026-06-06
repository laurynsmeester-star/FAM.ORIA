//
//  CachedAsyncImage.swift
//  Famoria 2026
//
//  AsyncImage-style helper backed by an in-process NSCache so gallery
//  grids don't re-download the same thumbnail every time a cell scrolls
//  back into view. Drop-in replacement: pass a URL string and a content
//  builder; we look up the cached UIImage first, then fall back to a
//  URLSession fetch.
//

import SwiftUI

@MainActor
final class FamoriaImageCache {
    static let shared = FamoriaImageCache()

    private let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        // Cap at ~64 MB so the cache never runs the system out of memory.
        c.totalCostLimit = 64 * 1024 * 1024
        return c
    }()

    func image(for key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    func store(_ image: UIImage, for key: String) {
        // Rough cost = pixel count × 4 bytes.
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: key as NSString, cost: cost)
    }
}

/// `CachedAsyncImage` mirrors the `AsyncImage` API surface but checks
/// `FamoriaImageCache` first. The single closure receives a phase
/// enum identical to AsyncImage's so callers can drop it in.
struct CachedAsyncImage<Content: View>: View {
    let url: URL?
    let scale: CGFloat
    let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    init(
        url: URL?,
        scale: CGFloat = 1,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.scale = scale
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: url) { await load() }
    }

    private func load() async {
        guard let url else { phase = .empty; return }
        let key = url.absoluteString

        if let cached = FamoriaImageCache.shared.image(for: key) {
            phase = .success(Image(uiImage: cached))
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let img = UIImage(data: data, scale: scale) {
                FamoriaImageCache.shared.store(img, for: key)
                phase = .success(Image(uiImage: img))
            } else {
                phase = .failure(URLError(.cannotDecodeContentData))
            }
        } catch {
            phase = .failure(error)
        }
    }
}
