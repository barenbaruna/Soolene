//
//  CompositionDirectionOverlay.swift
//  Photograph
//
//  Dual-Anchor guidance overlay rendered on top of the camera preview.
//
//  Visual design — Three proximity states:
//
//  ┌─────────────────────────────────────────────────────────┐
//  │ FAR (distance > 0.12)                                   │
//  │   Subject Bracket [ ]  ─ ─ ─ ─ ─ ➤ ─ ─ ─  ○ Target    │
//  │        white            dashed connector     white      │
//  │   Directional arrow at connector midpoint               │
//  ├─────────────────────────────────────────────────────────┤
//  │ CLOSE (distance 0.06–0.12)                              │
//  │   Subject Bracket [ ]              ◉ Target             │
//  │        golden             connector fades     golden    │
//  │   Golden glow halo behind target socket                 │
//  ├─────────────────────────────────────────────────────────┤
//  │ PERFECT (distance < 0.06)                               │
//  │               ✓  merged green checkmark                 │
//  │          green glow ring expanding outward               │
//  └─────────────────────────────────────────────────────────┘
//
//  Spring parameters:
//  - Subject bracket: stiffness 180, damping 18 (momentum-preserving)
//  - Target socket:   stiffness 120, damping 14 (slightly softer, "magnetic")
//  - Color:           .easeInOut(0.35) (smooth, no bounce)
//  - Size:            spring(0.25, 0.65) (quick with subtle overshoot)
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import SwiftUI

// MARK: - CompositionDirectionOverlay

struct CompositionDirectionOverlay: View {
    let composition: CompositionType
    let subjectPoint: CGPoint?
    let targetPoint: CGPoint?
    let isPerfect: Bool
    var showsGreenCelebration: Bool = false
    let hasSceneData: Bool
    let hasMLData: Bool
    let alignmentScore: Float
    let guidanceDistance: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Proximity State

    private enum ProximityState {
        case far, close, perfect
    }

    private var proximity: ProximityState {
        if isPerfect || guidanceDistance < 0.06 { return .perfect }
        if guidanceDistance < 0.12 { return .close }
        return .far
    }

    // MARK: - Anchor Colours

    private var anchorColor: Color {
        switch proximity {
        case .perfect:
            return showsGreenCelebration ? AppColors.gridlineGreen : AppColors.controlActive
        case .close:   return AppColors.primary
        case .far:     return Color.white.opacity(0.85)
        }
    }

    private var showsCelebration: Bool {
        proximity == .perfect && showsGreenCelebration
    }

    private var bracketLineWidth: CGFloat {
        switch proximity {
        case .perfect: return GridMetrics.targetRing
        case .close:   return GridMetrics.crosshair
        case .far:     return GridMetrics.secondary
        }
    }

    private var socketSize: CGFloat {
        switch proximity {
        case .perfect: return ControlMetrics.dualAnchorSocketClose
        case .close:   return ControlMetrics.dualAnchorSocketClose
        case .far:     return ControlMetrics.dualAnchorSocketFar
        }
    }

    private var dotSize: CGFloat {
        switch proximity {
        case .perfect: return 12
        case .close:   return 10
        case .far:     return 6
        }
    }

    // MARK: - Body

    var body: some View {
        guard hasSceneData, targetPoint != nil else { return AnyView(EmptyView()) }

        return AnyView(
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                if let subjectNorm = subjectPoint, let targetNorm = targetPoint {
                    let subjectPx = toPixel(subjectNorm, width: w, height: h)
                    let targetPx  = toPixel(targetNorm,  width: w, height: h)

                    ZStack {
                        // --- Layer 1: Connector Line ---
                        if proximity == .far {
                            DashedConnectorLine(
                                from: subjectPx,
                                to: targetPx,
                                color: anchorColor
                            )
                            .transition(.opacity)

                            // Directional arrow at midpoint
                            DirectionArrow(from: subjectPx, to: targetPx, color: anchorColor)
                        }

                        // --- Layer 2: Glow Halo (close + perfect) ---
                        if proximity == .close {
                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [AppColors.lockGlow, .clear],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: socketSize
                                    )
                                )
                                .frame(width: socketSize * 2, height: socketSize * 2)
                                .position(targetPx)
                                .transition(.opacity)
                        }

                        if showsCelebration {
                            PerfectBurstRing()
                                .position(targetPx)

                            Circle()
                                .fill(
                                    RadialGradient(
                                        colors: [AppColors.perfectGlow, .clear],
                                        center: .center,
                                        startRadius: 0,
                                        endRadius: socketSize * 1.2
                                    )
                                )
                                .frame(width: socketSize * 2.5, height: socketSize * 2.5)
                                .position(targetPx)
                        }

                        // --- Layer 3: Target Socket ---
                        EnhancedTargetSocket(
                            color: anchorColor,
                            isPerfect: showsCelebration,
                            dotSize: dotSize
                        )
                        .frame(width: socketSize, height: socketSize)
                        .position(targetPx)
                        .allowsHitTesting(false)

                        // --- Layer 4: Subject Bracket ---
                        if showsCelebration {
                            PerfectCheckmark(color: anchorColor)
                                .frame(width: ControlMetrics.dualAnchorBracketSize,
                                       height: ControlMetrics.dualAnchorBracketSize)
                                .position(subjectPx)
                                .transition(.scale(scale: 0.5).combined(with: .opacity))
                        } else {
                            SubjectReticle(
                                color: anchorColor,
                                isPerfect: false,
                                lineWidth: bracketLineWidth
                            )
                            .frame(width: ControlMetrics.dualAnchorBracketSize,
                                   height: ControlMetrics.dualAnchorBracketSize)
                            .position(subjectPx)
                            .allowsHitTesting(false)
                        }
                    }
                    .animation(subjectSpring, value: subjectPx)
                    .animation(targetSpring, value: targetPx)
                    .animation(reduceMotion ? .linear(duration: 0.15) : .easeInOut(duration: 0.35), value: anchorColor)
                    .animation(reduceMotion ? .linear(duration: 0.15) : .spring(response: 0.25, dampingFraction: 0.65), value: socketSize)
                    .animation(reduceMotion ? .linear(duration: 0.15) : .easeInOut(duration: 0.3), value: proximity == .perfect)
                }
            }
            .allowsHitTesting(false)
        )
    }

    private var subjectSpring: Animation {
        reduceMotion
            ? .linear(duration: 0.15)
            : .interpolatingSpring(stiffness: 180, damping: 18)
    }

    private var targetSpring: Animation {
        reduceMotion
            ? .linear(duration: 0.15)
            : .interpolatingSpring(stiffness: 120, damping: 14)
    }

    private func toPixel(_ norm: CGPoint, width: CGFloat, height: CGFloat) -> CGPoint {
        CGPoint(x: norm.x * width, y: norm.y * height)
    }
}

// MARK: - SubjectReticle

/// Corner bracket [ ] marking the current subject position.
private struct SubjectReticle: View {
    let color: Color
    let isPerfect: Bool
    var lineWidth: CGFloat = 1.5

    var body: some View {
        BracketShape()
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .square, lineJoin: .miter))
            .shadow(color: .black.opacity(0.35), radius: 1.5, x: 0, y: 1)
    }
}

/// Draws four corners like a camera viewfinder bracket: [ ]
private struct BracketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let length: CGFloat = rect.width * 0.25

        // Top Left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + length))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + length, y: rect.minY))

        // Top Right
        path.move(to: CGPoint(x: rect.maxX - length, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + length))

        // Bottom Right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - length))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX - length, y: rect.maxY))

        // Bottom Left
        path.move(to: CGPoint(x: rect.minX + length, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - length))

        return path
    }
}

// MARK: - EnhancedTargetSocket

/// Pulsing ring at the ideal composition position with proximity-aware visuals.
private struct EnhancedTargetSocket: View {
    let color: Color
    let isPerfect: Bool
    let dotSize: CGFloat

    @State private var isPulsing = false

    var body: some View {
        ZStack {
            // Outer pulse ring — continuous for perfect state
            Circle()
                .strokeBorder(color.opacity(isPulsing ? 0 : 0.5), lineWidth: 2)
                .scaleEffect(isPulsing ? 1.5 : 1.0)
                .animation(
                    .easeOut(duration: 1.0).repeatForever(autoreverses: false),
                    value: isPulsing
                )

            // Inner socket ring
            Circle()
                .strokeBorder(color, lineWidth: isPerfect ? 2.5 : 1.5)
                .shadow(color: .black.opacity(0.35), radius: 1.5, x: 0, y: 1)

            // Centre dot — grows on close/perfect
            Circle()
                .fill(color)
                .frame(width: dotSize, height: dotSize)
                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: dotSize)
        }
        .onAppear { isPulsing = true }
    }
}

// MARK: - PerfectCheckmark

/// Green checkmark shown when composition is perfectly aligned.
/// Replaces the subject bracket with a satisfying morph.
private struct PerfectCheckmark: View {
    let color: Color
    @State private var checkScale: CGFloat = 0.3

    var body: some View {
        ZStack {
            // Soft glow background
            Circle()
                .fill(color.opacity(0.2))
                .scaleEffect(1.3)
                .blur(radius: 6)

            // Checkmark circle
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(color)
                .scaleEffect(checkScale)
                .shadow(color: color.opacity(0.5), radius: 6)
        }
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
                checkScale = 1.0
            }
        }
    }
}

// MARK: - PerfectBurstRing

/// Expanding ring that bursts outward when perfect alignment is achieved.
private struct PerfectBurstRing: View {
    @State private var burst = false

    var body: some View {
        ZStack {
            // Primary burst
            Circle()
                .strokeBorder(AppColors.gridlineGreen.opacity(burst ? 0 : 0.6), lineWidth: 2)
                .frame(width: 80, height: 80)
                .scaleEffect(burst ? 2.2 : 0.8)

            // Secondary burst (delayed)
            Circle()
                .strokeBorder(AppColors.gridlineGreen.opacity(burst ? 0 : 0.3), lineWidth: 1.5)
                .frame(width: 60, height: 60)
                .scaleEffect(burst ? 1.8 : 0.6)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                burst = true
            }
        }
    }
}

// MARK: - DashedConnectorLine

/// A dashed line with shadow between subject and target, shown when far.
private struct DashedConnectorLine: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dashPhase: CGFloat = 0

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1.0 : 0.05)) { _ in
            Canvas { context, _ in
                var path = Path()
                path.move(to: from)
                path.addLine(to: to)

                context.stroke(
                    path,
                    with: .color(.black.opacity(0.25)),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                context.stroke(
                    path,
                    with: .color(color.opacity(0.4)),
                    style: StrokeStyle(
                        lineWidth: 1.5,
                        lineCap: .round,
                        dash: [6, 4],
                        dashPhase: reduceMotion ? 0 : dashPhase
                    )
                )
            }
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                dashPhase = 20
            }
        }
    }
}

// MARK: - DirectionArrow

/// Arrow biased toward the target so guidance reads “move subject toward the circle.”
private struct DirectionArrow: View {
    let from: CGPoint
    let to: CGPoint
    let color: Color

    /// Position along connector (0 = subject, 1 = target).
    private let biasTowardTarget: CGFloat = 0.8

    var body: some View {
        let anchorX = from.x + (to.x - from.x) * biasTowardTarget
        let anchorY = from.y + (to.y - from.y) * biasTowardTarget
        let angle = atan2(to.y - from.y, to.x - from.x)

        Image(systemName: "arrowtriangle.forward.fill")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(color.opacity(0.75))
            .rotationEffect(.radians(angle))
            .position(x: anchorX, y: anchorY)
            .shadow(color: .black.opacity(0.35), radius: 1)
    }
}
