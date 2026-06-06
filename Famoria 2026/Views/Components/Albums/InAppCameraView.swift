//
//  InAppCameraView.swift
//  Famoria 2026
//
//  Lightweight SwiftUI wrapper around `UIImagePickerController` so the
//  user can grab a photo or video without leaving the album. The picker
//  hands back either a UIImage or a media file URL via the
//  `onCapture` callback.
//
//  Required Info.plist key: NSCameraUsageDescription.
//

import SwiftUI
import UIKit
import AVFoundation
import UniformTypeIdentifiers

/// One captured media item — a photo or a video file URL.
enum CapturedMedia {
    case photo(UIImage)
    case video(URL)
}

struct InAppCameraView: UIViewControllerRepresentable {

    /// Whether to allow video capture in addition to stills.
    var allowsVideo: Bool = true
    let onCapture: (CapturedMedia) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        var types: [String] = [UTType.image.identifier]
        if allowsVideo { types.append(UTType.movie.identifier) }
        picker.mediaTypes = types
        picker.videoQuality = .typeHigh
        picker.videoMaximumDuration = 300 // 5 minutes — sane upper bound.
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: InAppCameraView
        init(_ parent: InAppCameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let url = info[.mediaURL] as? URL {
                parent.onCapture(.video(url))
            } else if let image = info[.originalImage] as? UIImage {
                parent.onCapture(.photo(image))
            } else {
                parent.onCancel()
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onCancel()
        }
    }
}
