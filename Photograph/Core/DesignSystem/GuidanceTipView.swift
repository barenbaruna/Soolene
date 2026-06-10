//
//  GuidanceTipView.swift
//  Photograph
//
//  Phase-aware guidance tip displayed at the top of the camera HUD.
//  Changes icon, text, border color, and shadow based on the current GuidancePhase.
//
//  Animations:
//  - Icon swaps use .contentTransition(.symbolEffect(.replace))
//  - Text swaps use .contentTransition(.numericText)
//  - Whole-pill entrance uses .transition(.blurReplace)
//
//  Created by Baren Baruna Harahap on 10/06/26.
//

import SwiftUI

/// Displays a composition guidance tip in a phase-aware glass pill.
struct GuidanceTipView: View {
    let phase: GuidancePhase
    let tip: String
    let composition: CompositionType?

    var body: some View {
        HStack(spacing: 8) {
            // Phase-appropriate icon with symbol animation
            Image(systemName: phaseIcon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(phaseIconColor)
                .contentTransition(.symbolEffect(.replace))

            Text(tip)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
                .contentTransition(.interpolate)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(phaseStrokeColor, lineWidth: 1)
        )
        .shadow(color: phaseShadowColor, radius: 8, x: 0, y: 4)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: tip)
        .id(tip)
        .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    // MARK: - Phase Visuals

    private var phaseIcon: String {
        switch phase {
        case .scanning:
            return "viewfinder"
        case .subjectLocked:
            return "lock.fill"
        case .guiding:
            return composition?.symbolName ?? "camera.viewfinder"
        case .perfect:
            return "checkmark.circle.fill"
        }
    }

    private var phaseIconColor: Color {
        switch phase {
        case .scanning:       return .white.opacity(0.6)
        case .subjectLocked:  return AppColors.primary
        case .guiding:        return .white
        case .perfect:        return AppColors.gridlineGreen
        }
    }

    private var phaseStrokeColor: Color {
        switch phase {
        case .scanning:       return .white.opacity(0.1)
        case .subjectLocked:  return AppColors.primary.opacity(0.4)
        case .guiding:        return .white.opacity(0.15)
        case .perfect:        return AppColors.gridlineGreen.opacity(0.5)
        }
    }

    private var phaseShadowColor: Color {
        switch phase {
        case .perfect:  return AppColors.gridlineGreen.opacity(0.3)
        default:        return .black.opacity(0.16)
        }
    }
}
