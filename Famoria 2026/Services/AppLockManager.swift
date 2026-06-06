//
//  AppLockManager.swift
//  Famoria 2026
//
//  Optional Face ID / Touch ID gate that wraps the whole app. When
//  enabled, the user is challenged whenever the app comes back to the
//  foreground or after the device is unlocked.
//
//  Required Info.plist key: NSFaceIDUsageDescription (already added
//  alongside the Reminders / Photo Library strings).
//

import Foundation
import os
import Combine
import LocalAuthentication
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class AppLockManager: ObservableObject {

    /// Whether the user has opted in to Face ID / Touch ID. Persisted in
    /// UserDefaults so the choice survives launches.
    @AppStoragePublished("famoria.appLock.enabled", defaultValue: false)
    var isEnabled: Bool

    /// True when the app is currently locked and the user must auth.
    @Published var isLocked: Bool = false

    /// Display label for the available biometric (Face ID / Touch ID /
    /// Passcode). Used by the Profile toggle for accurate copy.
    let biometryLabel: String

    private var foregroundObserver: NSObjectProtocol?

    init() {
        biometryLabel = Self.detectBiometryLabel()
        // If the user enabled lock previously, present the lock screen
        // immediately at launch.
        if isEnabled { isLocked = true }
        installForegroundObserver()
    }

    deinit {
        if let token = foregroundObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - Public API

    /// Asks LocalAuthentication for Face ID / Touch ID. On success, the
    /// lock screen dismisses. On failure, the user can retry.
    func authenticate() async {
        let context = LAContext()
        context.localizedFallbackTitle = "Use passcode"

        var error: NSError?
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        guard canEvaluate else {
            // No biometrics + no passcode — unlock so the user isn't
            // trapped on the lock screen.
            isLocked = false
            return
        }

        do {
            let ok = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Famoria"
            )
            if ok { isLocked = false }
        } catch {
            Log.appState.error("biometric auth failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Manually locks (e.g. for the Profile "Lock now" button).
    func lock() {
        guard isEnabled else { return }
        isLocked = true
    }

    /// Called from the Profile toggle. When disabling we also clear the
    /// in-memory lock so the user isn't suddenly stranded.
    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled { isLocked = false }
    }

    // MARK: - Foreground hook

    private func installForegroundObserver() {
        #if canImport(UIKit)
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                if self.isEnabled { self.isLocked = true }
            }
        }
        #endif
    }

    // MARK: - Helpers

    private static func detectBiometryLabel() -> String {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        switch context.biometryType {
        case .faceID:  return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        default:       return "Device passcode"
        }
    }
}

// MARK: - @AppStoragePublished

/// Tiny wrapper that combines `UserDefaults` persistence with `@Published`
/// behaviour so the value can drive SwiftUI bindings even though we live
/// in an ObservableObject (not a View). One-way write-through; reads come
/// from UserDefaults so the value survives relaunches.
@propertyWrapper
struct AppStoragePublished<Value> {
    let key: String
    let defaultValue: Value

    var wrappedValue: Value {
        get { UserDefaults.standard.object(forKey: key) as? Value ?? defaultValue }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }

    init(_ key: String, defaultValue: Value) {
        self.key = key
        self.defaultValue = defaultValue
    }
}
