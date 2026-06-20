//
//  LiquidGlassRuler.swift
//  Soolene
//
//  Shared horizontal ruler components for exposure (knob) and zoom (center-pinned).
//

import SwiftUI

// MARK: - Panel chrome

/// Centers ruler content at the shared panel width — glass wraps track only.
struct ViewfinderRulerPanel<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(maxWidth: ControlMetrics.rulerPanelWidth)
            .frame(maxWidth: .infinity)
    }
}

/// Tap-outside scrim — dismisses expandable ruler panels (exposure).
struct RulerPanelDismissScrim: View {
    let onDismiss: () -> Void

    var body: some View {
        Color.black.opacity(0.18)
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture { onDismiss() }
            .accessibilityLabel("Dismiss")
            .accessibilityAddTraits(.isButton)
    }
}

/// Light capsule glass behind the tick track only — avoids a heavy full-panel box.
struct RulerTrackGlassBackground: ViewModifier {
    var isDragging: Bool = false
    var glassID: String? = nil
    var glassNamespace: Namespace.ID? = nil

    func body(content: Content) -> some View {
        content.background {
            if #available(iOS 26, *) {
                let glass: Glass = isDragging
                    ? .clear.tint(Color.black.opacity(0.15)).interactive()
                    : .clear.tint(Color.black.opacity(0.15))
                
                let base = Color.clear
                    .glassEffect(glass, in: .rect(cornerRadius: 30))
                    .allowsHitTesting(false)
                
                if let id = glassID, let ns = glassNamespace {
                    base.glassEffectID(id, in: ns)
                } else {
                    base
                }
            } else {
                RoundedRectangle(cornerRadius: 30)
                    .fill(.ultraThinMaterial)
                    .allowsHitTesting(false)
            }
        }
    }
}

/// Animated value label — shared typography and content transition.
struct RulerValueLabel: View {
    let text: String
    let color: Color
    let numericValue: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(.caption.monospacedDigit().weight(.semibold))
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.45), radius: 4, y: 0)
            .contentTransition(.numericText(value: numericValue))
            .animation(reduceMotion ? .none : .snappy, value: numericValue)
    }
}

// MARK: - Exposure ruler (knob tracks value)

/// Horizontal ruler with floating knob (exposure EV).
struct LiquidGlassRuler: View {
    let value: CGFloat
    let range: ClosedRange<CGFloat>
    let formattedValue: String
    let activeColor: Color
    let isDragging: Bool
    let onValueChanged: (CGFloat) -> Void
    var onDragBegan: (() -> Void)?
    var onDragEnded: (() -> Void)?
    var glassID: String? = nil
    var glassNamespace: Namespace.ID? = nil

    @State private var dragStart: CGFloat?

    private let tickCount = 41

    var body: some View {
        HStack(spacing: Spacing.small) {
            RulerValueLabel(
                text: formattedValue,
                color: activeColor,
                numericValue: Double(value)
            )
            .padding(.leading, Spacing.standard)

            rulerTrack(width: nil) { width in
                let knobX = knobOffset(in: width)
                let fillWidth = max(0, knobX)

                ZStack(alignment: .leading) {
                    tickRow(width: width, fillWidth: fillWidth)
                    glassKnob
                        .offset(x: knobX - 11)
                }
            }
            .padding(.trailing, ControlMetrics.rulerTrackHorizontalPadding)
        }
        .padding(.vertical, ControlMetrics.rulerTrackVerticalPadding)
        .modifier(RulerTrackGlassBackground(isDragging: isDragging, glassID: glassID, glassNamespace: glassNamespace))
    }

    private var glassKnob: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        activeColor.opacity(0.85),
                        activeColor.opacity(0.35),
                        Color.black.opacity(0.6)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 22, height: 36)
            .overlay {
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.35), lineWidth: 1)
            }
            .shadow(color: activeColor.opacity(0.45), radius: 8, y: 2)
    }

    private func tickRow(width: CGFloat, fillWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<tickCount, id: \.self) { index in
                let x = CGFloat(index) / CGFloat(tickCount - 1) * width
                let isMajor = index % 5 == 0
                let height: CGFloat = isMajor ? 18 : tickHeight(at: index, centerX: width / 2, x: x)
                let isActive = x <= fillWidth + 1

                Rectangle()
                    .fill(isActive ? activeColor : Color.primary.opacity(0.22))
                    .frame(width: isMajor ? 1.5 : 1, height: height)
                    .frame(maxHeight: .infinity, alignment: .center)

                if index < tickCount - 1 {
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func tickHeight(at index: Int, centerX: CGFloat, x: CGFloat) -> CGFloat {
        let distance = abs(x - centerX)
        let maxDist = centerX
        let falloff = 1 - min(distance / maxDist, 1)
        return 8 + falloff * 6
    }

    private func knobOffset(in width: CGFloat) -> CGFloat {
        let normalized = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
        return min(max(normalized, 0), 1) * width
    }

    private func dragGesture(in width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if dragStart == nil {
                    dragStart = value
                    onDragBegan?()
                }
                guard let start = dragStart else { return }
                let delta = gesture.translation.width / width
                let span = range.upperBound - range.lowerBound
                let next = start + delta * span
                let clamped = min(max(next, range.lowerBound), range.upperBound)
                onValueChanged(clamped)
            }
            .onEnded { _ in
                dragStart = nil
                onDragEnded?()
            }
    }

    @ViewBuilder
    private func rulerTrack<Content: View>(
        width: CGFloat?,
        @ViewBuilder content: @escaping (CGFloat) -> Content
    ) -> some View {
        GeometryReader { geo in
            let trackWidth = width ?? geo.size.width
            content(trackWidth)
                .frame(height: ControlMetrics.rulerTrackHeight)
                .contentShape(Rectangle())
                .gesture(dragGesture(in: trackWidth))
        }
        .frame(height: ControlMetrics.rulerTrackHeight)
    }
}

// MARK: - Center-pinned ruler (zoom)

/// Center-fixed indicator — ticks scroll underneath (system Camera style).
struct LiquidGlassCenterRuler: View {
    let value: CGFloat
    let range: ClosedRange<CGFloat>
    let formattedValue: String
    let activeColor: Color
    let tickLayout: ZoomRulerTickLayout
    let isDragging: Bool
    let onValueChanged: (CGFloat) -> Void
    var onDragBegan: (() -> Void)?
    var onDragEnded: (() -> Void)?
    var glassID: String? = nil
    var glassNamespace: Namespace.ID? = nil

    @State private var dragStart: CGFloat?
    @State private var didBeginDrag = false

    var body: some View {
        HStack(spacing: Spacing.small) {
            RulerValueLabel(
                text: formattedValue,
                color: activeColor,
                numericValue: Double(value)
            )
            .frame(minWidth: 44, alignment: .leading)
            .padding(.leading, Spacing.standard)

            GeometryReader { geo in
                let width = geo.size.width
                let centerX = width / 2
                let trackMidY = ControlMetrics.rulerTrackHeight / 2

                ZStack {
                    centerTickLayer(width: width, centerX: centerX, trackMidY: trackMidY)
                    centerIndicator(centerX: centerX, trackMidY: trackMidY)
                }
                .frame(height: ControlMetrics.rulerTrackHeight)
                .contentShape(Rectangle())
                .gesture(dragGesture(in: width))
            }
            .frame(height: ControlMetrics.rulerTrackHeight)
            .padding(.trailing, ControlMetrics.rulerTrackHorizontalPadding)
        }
        .padding(.vertical, ControlMetrics.rulerTrackVerticalPadding)
        .modifier(RulerTrackGlassBackground(isDragging: isDragging, glassID: glassID, glassNamespace: glassNamespace))
    }

    private func centerIndicator(centerX: CGFloat, trackMidY: CGFloat) -> some View {
        Capsule()
            .fill(activeColor)
            .frame(width: 2.5, height: 22)
            .overlay {
                Capsule()
                    .strokeBorder(Color.primary.opacity(0.45), lineWidth: 0.5)
            }
            .shadow(color: activeColor.opacity(0.65), radius: 5, y: 0)
            .position(x: centerX, y: trackMidY)
    }

    private func centerTickLayer(width: CGFloat, centerX: CGFloat, trackMidY: CGFloat) -> some View {
        let span = range.upperBound - range.lowerBound
        let minorStep = tickLayout.minorStep

        return ZStack {
            ForEach(tickLayout.tickValues, id: \.self) { tick in
                let x = centerX + (tick - value) / span * width
                if x >= -4, x <= width + 4 {
                    let isMajor = tickLayout.isMajor(tick)
                    let isCenter = abs(tick - value) < minorStep * 0.5
                    let height: CGFloat = isCenter ? 22 : (isMajor ? 16 : 9)

                    Rectangle()
                        .fill(isMajor || isCenter ? activeColor : Color.primary.opacity(0.25))
                        .frame(width: isMajor ? 1.5 : 1, height: height)
                        .shadow(
                            color: isMajor ? activeColor.opacity(0.45) : .clear,
                            radius: 3,
                            y: 0
                        )
                        .position(x: x, y: trackMidY)
                }
            }
        }
    }

    private func dragGesture(in width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if !didBeginDrag {
                    didBeginDrag = true
                    onDragBegan?()
                }
                if dragStart == nil { dragStart = value }
                guard let start = dragStart else { return }
                let delta = -gesture.translation.width / width
                let span = range.upperBound - range.lowerBound
                let next = start + delta * span
                let clamped = min(max(next, range.lowerBound), range.upperBound)
                onValueChanged(clamped)
            }
            .onEnded { _ in
                dragStart = nil
                didBeginDrag = false
                onDragEnded?()
            }
    }
}

// MARK: - Shared layout tokens

extension ControlMetrics {
    static let rulerPanelWidth: CGFloat = exposureControlWidth
    static let rulerTrackHorizontalPadding: CGFloat = Spacing.standard
    static let rulerTrackVerticalPadding: CGFloat = Spacing.small
    static let rulerPanelContentHeight: CGFloat = rulerTrackHeight + rulerTrackVerticalPadding * 2
}
