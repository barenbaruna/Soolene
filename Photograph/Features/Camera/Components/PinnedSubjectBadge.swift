//
//  PinnedSubjectBadge.swift
//  Photograph
//
//  A dynamic phase-aware status badge shown below the composition picker.
//  Replaces the static "Focus Locked" badge with contextual status per phase.
//
//  Design:
//  - Uses .ultraThinMaterial capsule with phase-colored border
//  - Icon animates with .contentTransition(.symbolEffect(.replace))
//  - Text swaps smoothly with .contentTransition(.numericText)
//  - Subtle border glow pulse on locked state
//
//  Created by Baren Baruna Harahap on 06/06/26.
//

import SwiftUI

struct PinnedSubjectBadge: View {
    let phase: GuidancePhase
    let composition: CompositionType?

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 8) {
            // Animated status icon
            Image(systemName: statusIcon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(statusColor)
                .scaleEffect(isPulsing && phase.isLocked ? 1.1 : 1.0)

            Text(statusText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)

            if phase.isLocked {
                Text("•")
                    .foregroundStyle(.white.opacity(0.3))

                Text("Double-tap to reset")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(
                            statusColor.opacity(isPulsing ? 0.5 : 0.2),
                            lineWidth: 1.5
                        )
                )
                .shadow(
                    color: statusColor.opacity(isPulsing ? 0.25 : 0),
                    radius: isPulsing ? 8 : 0
                )
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: phase)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    // MARK: - Phase-Driven Properties

    private var statusIcon: String {
        switch phase {
        case .scanning:       return "viewfinder"
        case .subjectLocked:  return "lock.fill"
        case .guiding:        return composition?.symbolName ?? "scope"
        case .perfect:        return "checkmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch phase {
        case .scanning:       return .white.opacity(0.5)
        case .subjectLocked:  return AppColors.primary
        case .guiding:        return AppColors.primary
        case .perfect:        return AppColors.gridlineGreen
        }
    }

    private var statusText: String {
        switch phase {
        case .scanning:       return "Scanning"
        case .subjectLocked:  return "Subject Locked"
        case .guiding:        return composition?.rawValue ?? "Guiding"
        case .perfect:        return "Aligned"
        }
    }
}

#Preview {
    ZStack {
        Color.black
        VStack(spacing: 20) {
            PinnedSubjectBadge(phase: .scanning, composition: nil)
            PinnedSubjectBadge(phase: .subjectLocked(subjectPoint: .zero), composition: nil)
            PinnedSubjectBadge(phase: .guiding(composition: .ruleOfThirds), composition: .ruleOfThirds)
            PinnedSubjectBadge(phase: .perfect(composition: .center), composition: .center)
        }
    }
}
