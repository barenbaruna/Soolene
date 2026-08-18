//
//  CameraInteractionOverlays.swift
//  Soolene
//

import SwiftUI

/// Tap indicator, lock animation, and focus/exposure controls above the preview.
struct CameraInteractionOverlays: View {
    let lockRingPoint: CGPoint?
    let lockRingAnimating: Bool
    let showLockIcon: Bool
    let showTapIndicator: Bool
    let tapIndicatorPoint: CGPoint?
    let tapIndicatorStyle: TapIndicatorStyle
    let isShowingFocusExposure: Bool
    let focusedPoint: CGPoint?
    @Binding var exposureBias: Float
    let onResetExposure: () -> Void
    let onDragExposure: () -> Void

    var body: some View {
        ZStack {
            if let lockPoint = lockRingPoint {
                LockAnimationRing(isAnimating: lockRingAnimating, showIcon: showLockIcon)
                    .position(lockPoint)
                    .allowsHitTesting(false)
            }

            if showTapIndicator, let pt = tapIndicatorPoint {
                TapIndicator(style: tapIndicatorStyle)
                    .position(pt)
                    .transition(.opacity.combined(with: .scale(scale: 0.5)))
                    .allowsHitTesting(false)
            }

            if isShowingFocusExposure, let focusedPoint {
                FocusExposureOverlay(
                    point: focusedPoint,
                    exposureBias: $exposureBias,
                    onReset: onResetExposure,
                    onDrag: onDragExposure
                )
                .transition(.opacity.combined(with: .scale(scale: 0.92)))
            }
        }
    }
}

// MARK: - Focus Exposure

struct FocusExposureOverlay: View {
    let point: CGPoint
    @Binding var exposureBias: Float
    let onReset: () -> Void
    let onDrag: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let clampedPoint = clampedFocusPoint(in: proxy.size)

            ZStack {
                FocusBox()
                    .position(clampedPoint)

                ExposureRail(
                    value: $exposureBias,
                    onReset: onReset,
                    onDrag: onDrag
                )
                .position(
                    x: railX(focusPoint: clampedPoint, in: proxy.size),
                    y: clampedPoint.y
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .allowsHitTesting(true)
    }

    private func clampedFocusPoint(in size: CGSize) -> CGPoint {
        let margin = ControlMetrics.focusBox / 2 + Spacing.standard
        return CGPoint(
            x: min(max(point.x, margin), size.width - margin - ControlMetrics.exposureRailWidth),
            y: min(max(point.y, margin + Spacing.large), size.height - margin - ControlMetrics.cameraBottomBandHeight)
        )
    }

    private func railX(focusPoint: CGPoint, in size: CGSize) -> CGFloat {
        let preferred = focusPoint.x + ControlMetrics.focusBox / 2 + Spacing.medium
        if preferred + ControlMetrics.exposureRailWidth / 2 < size.width - Spacing.small {
            return preferred
        }
        return focusPoint.x - ControlMetrics.focusBox / 2 - Spacing.medium
    }
}

private struct FocusBox: View {
    var body: some View {
        ZStack {
            Rectangle()
                .strokeBorder(AppColors.controlActive, lineWidth: 1)
                .frame(width: ControlMetrics.focusBox, height: ControlMetrics.focusBox)

            VStack {
                tick
                Spacer()
                tick
            }
            .frame(width: ControlMetrics.focusBox, height: ControlMetrics.focusBox + Spacing.medium)

            HStack {
                tick.rotationEffect(.degrees(90))
                Spacer()
                tick.rotationEffect(.degrees(90))
            }
            .frame(width: ControlMetrics.focusBox + Spacing.medium, height: ControlMetrics.focusBox)
        }
        .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
    }

    private var tick: some View {
        Rectangle()
            .fill(AppColors.controlActive)
            .frame(width: Spacing.medium, height: 1)
    }
}

private struct ExposureRail: View {
    @Binding var value: Float
    let onReset: () -> Void
    let onDrag: () -> Void
    @State private var dragStartValue: Float?

    var body: some View {
        Color.clear
            .frame(width: ControlMetrics.exposureRailWidth, height: ControlMetrics.exposureRailHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        onDrag()
                        if dragStartValue == nil {
                            dragStartValue = value
                        }
                        if let start = dragStartValue {
                            let delta = Float(-gesture.translation.height / 100.0)
                            value = min(max(start + delta, -2), 2)
                        }
                    }
                    .onEnded { _ in
                        dragStartValue = nil
                    }
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Exposure")
            .accessibilityValue(formattedValue)
            .accessibilityAdjustableAction { direction in
                onDrag()
                switch direction {
                case .increment:
                    value = min(value + 0.1, 2)
                case .decrement:
                    value = max(value - 0.1, -2)
                @unknown default:
                    break
                }
            }
    }

    private var formattedValue: String {
        if abs(value) < 0.05 {
            return "0,0"
        }
        let number = Double(value).formatted(.number.precision(.fractionLength(1)))
        return number.replacingOccurrences(of: ".", with: ",")
    }
}

// MARK: - Tap Indicator

enum TapIndicatorStyle {
    case focus
    case pin

    var symbolName: String {
        switch self {
        case .focus: return "viewfinder"
        case .pin: return "plus"
        }
    }
}

struct TapIndicator: View {
    let style: TapIndicatorStyle
    @State private var isExpanded = false

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(AppColors.primary, lineWidth: 2)
                .frame(
                    width: isExpanded ? ControlMetrics.focusIndicator : ControlMetrics.compactIconButton,
                    height: isExpanded ? ControlMetrics.focusIndicator : ControlMetrics.compactIconButton
                )
                .opacity(isExpanded ? 0 : 1)

            Circle()
                .fill(AppColors.primary.opacity(0.3))
                .frame(width: Spacing.standard, height: Spacing.standard)

            Image(systemName: style.symbolName)
                .font(.headline)
                .foregroundStyle(AppColors.primary)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) { isExpanded = true }
        }
    }
}
