//
//  VoiceNotePlayer.swift
//  Famoria 2026
//
//  One shared player instance used by chat bubbles. Calling
//  `play(url:)` stops any other voice note that's currently playing so
//  the user never hears two at once. ObservableObject so the UI can
//  bind to `isPlaying` + `progress`.
//

import Foundation
import AVFoundation
import Combine

@MainActor
final class VoiceNotePlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {

    static let shared = VoiceNotePlayer()

    @Published private(set) var currentURL: URL?
    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var duration: TimeInterval = 0

    private var player: AVAudioPlayer?
    private var timer: Timer?

    private override init() { super.init() }

    /// Toggles playback: starts the given URL fresh, pauses if the same
    /// URL is already playing, resumes if it was paused.
    func toggle(url: URL) {
        if currentURL == url, let player {
            if player.isPlaying {
                player.pause()
                isPlaying = false
            } else {
                player.play()
                isPlaying = true
            }
            return
        }
        play(url: url)
    }

    func play(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            return
        }

        stop()

        do {
            let p = try AVAudioPlayer(contentsOf: url)
            p.delegate = self
            p.prepareToPlay()
            self.player = p
            self.currentURL = url
            self.duration = p.duration
            self.progress = 0
            self.isPlaying = p.play()
            startTimer()
        } catch {
            return
        }
    }

    func stop() {
        player?.stop()
        timer?.invalidate()
        timer = nil
        player = nil
        currentURL = nil
        isPlaying = false
        progress = 0
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 1
            self.timer?.invalidate()
            self.timer = nil
        }
    }

    // MARK: - Private

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    @MainActor
    private func tick() {
        guard let player else { return }
        progress = player.duration > 0 ? player.currentTime / player.duration : 0
    }
}
