//
//  GuidanceTipView.swift
//  Photograph
//
//  Centered guidance label — driven by `tip` and unified `captureReadiness`.
//

import SwiftUI

struct GuidanceTipView: View {
    let phase: GuidancePhase
    let tip: String
    let composition: CompositionType?
    let captureReadiness: CaptureReadiness

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        labelContent
            .id(phaseIdentity)
            .transition(phaseTransition)
            .padding(.horizontal, Spacing.large)
            .padding(.vertical, Spacing.standard)
            .background { pillBackground }
            .animation(phaseAnimation, value: phaseIdentity)
            .accessibilityLabel(accessibilityText)
    }

    private var labelContent: some View {
        HStack(spacing: Spacing.small) {
            if showsReadyIcon {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColors.gridlineGreen)
                    .accessibilityHidden(true)
                    .transition(.scale.combined(with: .opacity))
            }

            Text(displayText)
                .font(.title3.weight(.medium))
                .foregroundStyle(foregroundColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .contentTransition(reduceMotion ? .identity : .interpolate)
        }
    }

    private var phaseIdentity: String {
        switch phase {
        case .scanning:
            return "scanning"
        case .subjectLocked:
            return "subjectLocked"
        case .guiding(let composition):
            return "guiding-\(composition.rawValue)-\(captureReadiness)"
        case .perfect(let composition):
            return "perfect-\(composition.rawValue)-\(captureReadiness)"
        }
    }

    private var phaseTransition: AnyTransition {
        if reduceMotion { return .opacity }
        return .opacity.combined(with: .scale(scale: 0.94))
    }

    private var phaseAnimation: Animation? {
        reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.82)
    }

    private var displayText: String {
        switch phase {
        case .guiding:
            return guidingCopy
        case .subjectLocked:
            if let composition {
                return composition.shortLabel
            }
            return tip
        case .perfect, .scanning:
            return tip
        }
    }

    private var accessibilityText: String {
        if showsReadyIcon {
            return "Composition ready. \(displayText)"
        }
        return displayText
    }

    private var guidingCopy: String {
        guard let composition else { return tip }
        switch composition {
        case .horizontal:
            return "Align the object with horizontal guide lines"
        case .vertical:
            return "Align the object with the vertical guide line"
        case .ruleOfThirds:
            return "Align the object with the guide lines"
        case .center:
            return "Center the object in the frame"
        case .diagonal:
            return "Align the object with the diagonal guide lines"
        }
    }

    private var foregroundColor: Color {
        if captureReadiness.showsGreenCelebration {
            return AppColors.gridlineGreen
        }
        if captureReadiness.showsStabilizingUI {
            return AppColors.controlActive
        }
        switch phase {
        case .guiding:
            return AppColors.textOnCamera
        default:
            return AppColors.textGuide
        }
    }

    private var showsReadyIcon: Bool {
        captureReadiness.showsGreenCelebration
    }

    @ViewBuilder
    private var pillBackground: some View {
        if #available(iOS 26, *) {
            Capsule()
                .fill(Color.black.opacity(0.35))
                .glassEffect(.regular, in: .capsule)
        } else {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .fill(Color.black.opacity(0.35))
                )
        }
    }
}
