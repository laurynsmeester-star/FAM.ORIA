//
//  ShareSheet.swift
//  Famoria 2026
//
//  SwiftUI wrapper around `UIActivityViewController` so any view can
//  surface the system share sheet for posts, events, photos, and
//  journal entries. Use the convenience `.familyShareSheet(items:)`
//  modifier or present `ShareSheet(items:)` from a `.sheet` directly.
//

import SwiftUI
import UIKit
import LinkPresentation

struct FamoriaShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var excludedActivityTypes: [UIActivity.ActivityType]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.excludedActivityTypes = excludedActivityTypes
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

/// Pre-rendered link-preview metadata for a Famoria entity so the
/// share sheet shows a proper title + thumbnail instead of "from
/// Famoria 2026". Pass an instance into `ShareSheet(items:)`.
final class FamoriaSharePayload: NSObject, UIActivityItemSource {
    let title: String
    let bodyText: String
    let url: URL?

    init(title: String, bodyText: String = "", url: URL? = nil) {
        self.title = title
        self.bodyText = bodyText
        self.url = url
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        url ?? bodyText as Any
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        if let url { return url }
        let joined = bodyText.isEmpty ? title : "\(title)\n\n\(bodyText)"
        return joined
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let meta = LPLinkMetadata()
        meta.title = title
        if let url { meta.url = url; meta.originalURL = url }
        return meta
    }
}

extension View {
    /// Convenience modifier that wires a Boolean trigger to a
    /// ShareSheet sheet.
    func familyShareSheet(items: [Any], isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) {
            FamoriaShareSheet(items: items)
        }
    }
}
