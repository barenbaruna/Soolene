//
//  GuidanceTipView.swift
//  Photograph
//
//  Centered guidance label — always driven by `tip`; glass scrim for readability.
//

import SwiftUI

struct GuidanceTipView: View {
    let phase: GuidancePhase
    let tip: String
    let composition: CompositionType?
    let isCaptureReady: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        labelContent
            .id(phaseIdentity)
            .transition(phaseTransition)
            .padding(.horizontal, Spacing.standard)
            .padding(.vertical, Spacing.small)
            .background { pillBackground }
            .animation(phaseAnimation, value: phaseIdentity)
            .accessibilityLabel(accessibilityText)
    }

    private var labelContent: some View {
        HStack(spacing: Spacing.small) {
            if showsReadyIcon {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.gridlineGreen)
                    .accessibilityHidden(true)
                    .transition(.scale.combined(with: .opacity))
            }

            Text(displayText)
                .font(.headline.weight(.medium))
                .foregroundStyle(foregroundColor)
                .multilineTextAlignment(.center)
                .lineLimit(3)
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
            return "guiding-\(composition.rawValue)"
        case .perfect(let composition):
            return "perfect-\(composition.rawValue)-\(isCaptureReady)"
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
        switch phase {
        case .perfect where isCaptureReady:
            return AppColors.gridlineGreen
        case .perfect:
            return AppColors.controlActive
        case .guiding:
            return AppColors.textOnCamera
        default:
            return AppColors.textGuide
        }
    }

    private var showsReadyIcon: Bool {
        phase.isPerfect && isCaptureReady
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
