//
//  PhotoSlideshowView.swift
//  Famoria Update 2026
//
//  Full-screen photo slideshow with:
//    • Auto-play with configurable speed (2 s / 3 s / 5 s)
//    • Play / Pause toggle
//    • Previous / Next navigation
//    • Caption + date overlay
//    • Progress dots (≤ 20 photos)
//    • Photo counter  "3 / 12"
//    • Swipe-left / swipe-right gesture support
//    • Close button
//
//  Mirrors PhotoSlideshow.jsx from the web reference.
//
//  Present via .fullScreenCover(isPresented:) from AlbumDetailView.
//

import SwiftUI

// MARK: - Slideshow Speed

enum SlideshowSpeed: Double, CaseIterable, Identifiable {
    case fast   = 2.0
    case normal = 3.0
    case slow   = 5.0

    var id: Double { rawValue }
    var label: String {
        switch self {
        case .fast:   return "Fast  (2 s)"
        case .normal: return "Normal (3 s)"
        case .slow:   return "Slow  (5 s)"
        }
    }
}

// MARK: - PhotoSlideshowView

struct PhotoSlideshowView: View {

    let photos: [FamoriaPhoto]
    let startIndex: Int
    @Binding var isPresented: Bool

    // Playback state
    @State private var currentIndex: Int    = 0
    @State private var isPlaying:    Bool   = false
    @State private var speed:        SlideshowSpeed = .normal

    // Animation direction tracking
    @State private var direction: Int = 1   // +1 forward, -1 backward

    // Timer
    @State private var timer: Timer? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // ── Main Image ───────────────────────────────────────────
            if !photos.isEmpty {
                let photo = photos[currentIndex]
                AsyncImage(url: URL(string: photo.imageURL)) { phase in
                    switch phase {
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    case .failure:
                        VStack(spacing: 12) {
                            Image(systemName: "photo.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.4))
                            Text("Could not load photo")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    default:
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    }
                }
                .id(currentIndex)               // forces re-render with animation
                .transition(
                    .asymmetric(
                        insertion: .move(edge: direction > 0 ? .trailing : .leading).combined(with: .opacity),
                        removal:   .move(edge: direction > 0 ? .leading  : .trailing).combined(with: .opacity)
                    )
                )
                .animation(.easeInOut(duration: 0.35), value: currentIndex)
            }

            // ── Swipe Gesture ────────────────────────────────────────
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 40)
                        .onEnded { value in
                            if value.translation.width < 0 { advance() }
                            else                           { retreat() }
                        }
                )

            // ── Left / Right Navigation Arrows ───────────────────────
            if photos.count > 1 {
                HStack {
                    navButton(systemName: "chevron.left",  action: retreat)
                    Spacer()
                    navButton(systemName: "chevron.right", action: advance)
                }
                .padding(.horizontal, 16)
            }

            // ── Top Bar (close) ──────────────────────────────────────
            VStack {
                HStack {
                    Spacer()
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.55))
                            .clipShape(Circle())
                    }
                    .padding(.top, 16)
                    .padding(.trailing, 16)
                }
                Spacer()
            }

            // ── Bottom Controls ──────────────────────────────────────
            VStack {
                Spacer()
                bottomControls
            }
        }
        .onAppear  { currentIndex = max(0, min(startIndex, photos.count - 1)) }
        .onDisappear { stopTimer() }
        .onChange(of: isPlaying) { _, playing in
            playing ? startTimer() : stopTimer()
        }
        .onChange(of: speed) { _, _ in
            if isPlaying { stopTimer(); startTimer() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 12) {
            // Caption / date
            if let photo = photos[safe: currentIndex], !photo.caption.isEmpty {
                VStack(spacing: 4) {
                    Text(photo.caption)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .shadow(radius: 4)
                    Text(photo.dateTaken, style: .date)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.65))
                }
                .padding(.horizontal, 24)
                .transition(.opacity)
            }

            // Play controls row
            HStack(alignment: .center) {
                // Play / Pause + Speed picker
                HStack(spacing: 10) {
                    Button {
                        withAnimation { isPlaying.toggle() }
                    } label: {
                        Label(isPlaying ? "Pause" : "Play",
                              systemImage: isPlaying ? "pause.fill" : "play.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.15))
                            .cornerRadius(20)
                    }

                    // Speed Menu
                    Menu {
                        ForEach(SlideshowSpeed.allCases) { s in
                            Button(s.label) { speed = s }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "gauge.medium")
                            Text(speed.label)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.15))
                        .cornerRadius(20)
                    }
                }

                Spacer()

                // Counter
                Text("\(currentIndex + 1) / \(photos.count)")
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.8))
                    .monospacedDigit()
            }
            .padding(.horizontal, 20)

            // Progress dots (≤ 20 photos)
            if photos.count <= 20 {
                progressDots
            }
        }
        .padding(.bottom, 30)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<photos.count, id: \.self) { idx in
                Capsule()
                    .fill(idx == currentIndex ? Color.white : Color.white.opacity(0.35))
                    .frame(width: idx == currentIndex ? 22 : 6, height: 6)
                    .onTapGesture { jumpTo(idx) }
                    .animation(.spring(response: 0.3), value: currentIndex)
            }
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Navigation Helpers

    private func navButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(Color.black.opacity(0.45))
                .clipShape(Circle())
        }
    }

    private func advance() {
        guard photos.count > 1 else { return }
        direction = 1
        withAnimation { currentIndex = (currentIndex + 1) % photos.count }
    }

    private func retreat() {
        guard photos.count > 1 else { return }
        direction = -1
        withAnimation { currentIndex = (currentIndex - 1 + photos.count) % photos.count }
    }

    private func jumpTo(_ idx: Int) {
        direction = idx > currentIndex ? 1 : -1
        withAnimation { currentIndex = idx }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        guard photos.count > 1 else { return }
        timer = Timer.scheduledTimer(withTimeInterval: speed.rawValue, repeats: true) { _ in
            Task { @MainActor in advance() }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - Safe Array Subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
