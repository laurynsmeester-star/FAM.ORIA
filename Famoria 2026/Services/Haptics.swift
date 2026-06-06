//
//  Haptics.swift
//  Famoria 2026
//
//  Tiny haptic vocabulary used app-wide. Call-sites express intent
//  (`.send`, `.success`) and we map that to the right
//  `UIImpactFeedbackGenerator` / `UINotificationFeedbackGenerator` style
//  in one place — so changing the feel of the app later is a one-file
//  edit.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum Haptics {
    /// User completed an affirmative action (send message, post update,
    /// add task). Light tap.
    static func send() { tap(.light) }

    /// User tapped a reaction emoji, swipe-to-reply, etc. Subtle.
    static func selection() {
        #if canImport(UIKit)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    /// Task marked complete, RSVP saved — the big "yes I did the thing"
    /// confirmation. Uses notification feedback (success pattern).
    static func success() { notify(.success) }

    /// Something failed — invalid input, permission denied.
    static func warning() { notify(.warning) }

    /// Light bump for things like long-press triggering a menu.
    static func tap(_ style: HapticStyle = .light) {
        #if canImport(UIKit)
        let generator: UIImpactFeedbackGenerator
        switch style {
        case .light:  generator = UIImpactFeedbackGenerator(style: .light)
        case .medium: generator = UIImpactFeedbackGenerator(style: .medium)
        case .heavy:  generator = UIImpactFeedbackGenerator(style: .heavy)
        case .rigid:
            if #available(iOS 13.0, *) {
                generator = UIImpactFeedbackGenerator(style: .rigid)
            } else {
                generator = UIImpactFeedbackGenerator(style: .heavy)
            }
        case .soft:
            if #available(iOS 13.0, *) {
                generator = UIImpactFeedbackGenerator(style: .soft)
            } else {
                generator = UIImpactFeedbackGenerator(style: .light)
            }
        }
        generator.impactOccurred()
        #endif
    }

    private static func notify(_ kind: NotifyKind) {
        #if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        switch kind {
        case .success: generator.notificationOccurred(.success)
        case .warning: generator.notificationOccurred(.warning)
        case .error:   generator.notificationOccurred(.error)
        }
        #endif
    }

    enum HapticStyle { case light, medium, heavy, rigid, soft }
    private enum NotifyKind { case success, warning, error }
}
