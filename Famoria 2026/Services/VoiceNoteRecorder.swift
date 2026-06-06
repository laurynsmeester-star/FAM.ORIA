//
//  VoiceNoteRecorder.swift
//  Famoria 2026
//
//  Push-to-talk style voice-note recorder used by ChatDetailView. Writes
//  m4a (AAC) to a temp directory while the user is holding the mic
//  button, exposes a live duration + audio level meter, and finalises
//  to a URL when the user releases.
//
//  Required Info.plist key: NSMicrophoneUsageDescription
//

import Foundation
import AVFoundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class VoiceNoteRecorder: ObservableObject {

    @Published private(set) var isRecording = false
    /// 0.0 – 1.0 normalised peak-level used to drive the recording UI.
    @Published private(set) var level: CGFloat = 0
    @Published private(set) var duration: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var startedAt: Date?
    private(set) var currentURL: URL?

    /// Asks for microphone permission, then begins recording. Returns
    /// false if the user denied the prompt or the audio session refused
    /// to start (e.g. a phone call is in progress).
    @discardableResult
    func start() async -> Bool {
        guard !isRecording else { return true }

        let granted = await requestPermission()
        guard granted else { return false }

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default,
                                    options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            return false
        }

        let filename = "voice-\(UUID().uuidString).m4a"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]

        do {
            let rec = try AVAudioRecorder(url: url, settings: settings)
            rec.isMeteringEnabled = true
            rec.prepareToRecord()
            guard rec.record() else { return false }
            self.recorder = rec
            self.currentURL = url
            self.startedAt = Date()
            self.isRecording = true
            self.duration = 0
            startMeterTimer()
            return true
        } catch {
            return false
        }
    }

    /// Stops recording and returns the finished file URL plus duration.
    /// Caller is responsible for moving / uploading the file before the
    /// temp directory is reaped.
    func stop() -> (url: URL, duration: TimeInterval)? {
        guard isRecording, let rec = recorder, let url = currentURL else {
            return nil
        }
        rec.stop()
        let finalDuration = startedAt.map { Date().timeIntervalSince($0) } ?? 0
        cleanupSession()
        return (url, finalDuration)
    }

    /// Cancels in-flight recording and deletes the partial file.
    func cancel() {
        guard isRecording, let rec = recorder, let url = currentURL else {
            cleanupSession()
            return
        }
        rec.stop()
        try? FileManager.default.removeItem(at: url)
        currentURL = nil
        cleanupSession()
    }

    // MARK: - Private

    private func cleanupSession() {
        meterTimer?.invalidate()
        meterTimer = nil
        isRecording = false
        level = 0
        recorder = nil
        startedAt = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickMeter() }
        }
    }

    @MainActor
    private func tickMeter() {
        guard let rec = recorder, isRecording else { return }
        rec.updateMeters()
        // averagePower is in dB, typically -60 (silence) ... 0 (max).
        let dB = rec.averagePower(forChannel: 0)
        let normalised = pow(10, dB / 20)
        level = CGFloat(max(0, min(1, normalised)))
        if let startedAt {
            duration = Date().timeIntervalSince(startedAt)
        }
    }

    private func requestPermission() async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }
    }
}
