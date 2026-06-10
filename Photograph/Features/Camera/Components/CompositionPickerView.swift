//
//  CompositionPickerView.swift
//  Photograph
//
//  Horizontal composition picker that appears when the user locks a subject.
//  Each composition is a Liquid Glass pill with SF Symbol icon and label.
//  The ML-suggested composition gets a ★ badge.
//
//  Design: iOS 26 HIG — .glassEffect(.regular.interactive()),
//  GlassEffectContainer for morphing, staggered entrance animation.
//
//  Created by Baren Baruna Harahap on 10/06/26.
//

import SwiftUI

// MARK: - CompositionPickerView

struct CompositionPickerView: View {
    let selectedComposition: CompositionType?
    let mlSuggestion: CompositionType?
    let onSelect: (CompositionType) -> Void

    @State private var hasAppeared = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.small) {
                ForEach(Array(CompositionType.allCases.enumerated()), id: \.element) { index, comp in
                    CompositionPill(
                        composition: comp,
                        isSelected: selectedComposition == comp,
                        isRecommended: mlSuggestion == comp,
                        onTap: { onSelect(comp) }
                    )
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 20)
                    .animation(
                        .spring(response: 0.45, dampingFraction: 0.75)
                            .delay(Double(index) * 0.06),
                        value: hasAppeared
                    )
                }
            }
            .padding(.horizontal, Spacing.standard)
        }
        .frame(height: ControlMetrics.compositionPickerHeight)
        .onAppear {
            withAnimation {
                hasAppeared = true
            }
        }
        .onDisappear {
            hasAppeared = false
        }
    }
}

// MARK: - CompositionPill

/// A single composition option in the picker.
/// Frosted glass pill with icon, label, and optional recommendation badge.
private struct CompositionPill: View {
    let composition: CompositionType
    let isSelected: Bool
    let isRecommended: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: composition.symbolName)
                        .font(.title3)
                        .foregroundStyle(isSelected ? AppColors.primary : .white.opacity(0.8))
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: 32, height: 32)

                    // ML recommendation badge
                    if isRecommended {
                        RecommendationBadge()
                            .offset(x: 8, y: -4)
                    }
                }

                Text(composition.shortLabel)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(width: ControlMetrics.compositionPillWidth, height: ControlMetrics.compositionPillHeight)
            .background(pillBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.medium)
                    .strokeBorder(
                        isSelected ? AppColors.primary.opacity(0.6) : .white.opacity(0.1),
                        lineWidth: isSelected ? 1.5 : 0.5
                    )
            )
            .scaleEffect(isPressed ? 0.92 : (isSelected ? 1.0 : 0.95))
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
            .animation(.spring(response: 0.15, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel("\(composition.rawValue) composition")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isRecommended ? "AI recommended" : "")
    }

    @ViewBuilder
    private var pillBackground: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.medium)
                        .fill(AppColors.primary.opacity(0.12))
                )
        } else {
            RoundedRectangle(cornerRadius: AppRadius.medium)
                .fill(.ultraThinMaterial.opacity(0.5))
        }
    }
}

// MARK: - RecommendationBadge

/// Shimmering ★ badge for the ML-suggested composition.
private struct RecommendationBadge: View {
    @State private var shimmer = false

    var body: some View {
        Text("★")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(AppColors.primary)
            .padding(3)
            .background(
                Circle()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Circle()
                            .fill(AppColors.primary.opacity(shimmer ? 0.3 : 0.1))
                    )
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    shimmer = true
                }
            }
    }
}

// MARK: - Short Label Extension

extension CompositionType {
    /// Short label for the composition picker pill.
    var shortLabel: String {
        switch self {
        case .ruleOfThirds: return "Thirds"
        case .center:       return "Center"
        case .horizontal:   return "Horizon"
        case .vertical:     return "Vertical"
        case .diagonal:     return "Diagonal"
        }
    }
}
