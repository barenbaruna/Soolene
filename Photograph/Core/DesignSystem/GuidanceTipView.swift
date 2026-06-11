//
//  GuidanceTipView.swift
//  Photograph
//
//  Centered guidance label matching design references.
//

import SwiftUI

struct GuidanceTipView: View {
    let phase: GuidancePhase
    let tip: String
    let composition: CompositionType?

    var body: some View {
        Text(displayText)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(foregroundColor)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, Spacing.standard)
            .padding(.vertical, Spacing.small)
            .background {
                if showsPillBackground {
                    Capsule()
                        .fill(Color.black.opacity(0.45))
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: displayText)
            .accessibilityLabel(displayText)
    }

    private var displayText: String {
        switch phase {
        case .scanning:
            return tip
        case .subjectLocked:
            if let composition {
                return composition.shortLabel
            }
            return tip
        case .guiding:
            return guidingCopy
        case .perfect:
            return "You're all set!"
        }
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
        case .perfect:
            return AppColors.gridlineGreen
        case .guiding:
            return AppColors.textOnCamera
        default:
            return AppColors.textGuide
        }
    }

    private var showsPillBackground: Bool {
        switch phase {
        case .subjectLocked, .scanning:
            return true
        default:
            return false
        }
    }
}
