//
//  ScanningCoachOverlay.swift
//  Soolene
//
//  Scanning-phase coach: optional viewfinder hint, debounced saliency pulse.
//

import SwiftUI

struct ScanningCoachOverlay: View {
    let saliencyCentroid: CGPoint?
    let faceDetected: Bool
    let showsViewfinderHint: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var breathing = false
    @State private var saliencyPulse = false
    @State private var confirmedCentroid: CGPoint?
    @State private var lastHapticCentroid: CGPoint?
    @State private var stabilityTask: Task<Void, Never>?

    private let stabilityDelayNs: UInt64 = 2_500_000_000
    private let stabilityThreshold: CGFloat = 0.04

    var body: some View {
        GeometryReader { geo in
            let size = geo.size

            ZStack {
                if showsViewfinderHint {
                    ScanningViewfinderHint(isAnimating: breathing && !reduceMotion)
                        .position(x: size.width / 2, y: size.height / 2)
                }

                if let centroid = confirmedCentroid ?? saliencyCentroid {
                    let point = pixelPoint(centroid, in: size)

                    SaliencyCoachMarker(
                        isStable: confirmedCentroid != nil,
                        isPulsing: saliencyPulse && !reduceMotion,
                        faceDetected: faceDetected
                    )
                    .position(point)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear {
            if showsViewfinderHint {
                startBreathing()
            }
        }
        .onDisappear {
            stabilityTask?.cancel()
            stabilityTask = nil
        }
        .onChange(of: saliencyCentroid) { _, newValue in
            handleSaliencyChange(newValue)
        }
    }

    private func startBreathing() {
        guard !reduceMotion else { return }
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            breathing = true
        }
    }

    private func handleSaliencyChange(_ centroid: CGPoint?) {
        stabilityTask?.cancel()
        confirmedCentroid = nil
        saliencyPulse = false

        guard let centroid else { return }

        stabilityTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: stabilityDelayNs)
            guard !Task.isCancelled else { return }

            withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                confirmedCentroid = centroid
            }

            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    saliencyPulse = true
                }
            }

            if shouldPlaySaliencyHaptic(for: centroid) {
                HapticManager.selection()
                lastHapticCentroid = centroid
            }
        }
    }

    private func shouldPlaySaliencyHaptic(for centroid: CGPoint) -> Bool {
        guard let last = lastHapticCentroid else { return true }
        return distance(centroid, last) > stabilityThreshold
    }

    private func pixelPoint(_ normalized: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: normalized.x * size.width, y: normalized.y * size.height)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}

// MARK: - Viewfinder hint

private struct ScanningViewfinderHint: View {
    let isAnimating: Bool

    var body: some View {
        Image(systemName: "viewfinder")
            .font(.system(size: 52, weight: .ultraLight))
            .foregroundStyle(AppColors.textGuide.opacity(isAnimating ? 0.55 : 0.3))
            .accessibilityHidden(true)
    }
}

// MARK: - Saliency marker

private struct SaliencyCoachMarker: View {
    let isStable: Bool
    let isPulsing: Bool
    let faceDetected: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(
                    ringColor.opacity(isPulsing ? 0.85 : 0.45),
                    lineWidth: isStable ? GridMetrics.secondary : 1.5
                )
                .frame(width: ringSize, height: ringSize)
                .scaleEffect(isPulsing ? 1.06 : 1.0)

            Circle()
                .fill(ringColor.opacity(0.25))
                .frame(width: 14, height: 14)

            if faceDetected {
                Image(systemName: "person.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textOnCamera.opacity(0.7))
                    .offset(y: -36)
            }
        }
        .shadow(color: .black.opacity(0.35), radius: 2, y: 1)
    }

    private var ringColor: Color {
        isStable ? AppColors.controlActive : AppColors.textOnCamera
    }

    private var ringSize: CGFloat {
        isStable ? 92 : 80
    }
}
