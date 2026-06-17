//
//  CompositionPickerView.swift
//  Photograph
//
//  Horizontal composition picker that appears when the user locks a subject.
//  Each composition is a Liquid Glass pill with SF Symbol icon and label.
//  The ML-suggested composition gets a "Best fit" badge.
//
//  Design: iOS 26 HIG — .glassEffect(.regular.interactive()),
//  GlassEffectContainer for morphing, staggered entrance animation.
//
//  Created by Baren Baruna Harahap on 10/06/26.
//

import SwiftUI
import TipKit

// MARK: - CompositionPickerView

struct CompositionPickerView: View {
    let selectedComposition: CompositionType?
    let mlSuggestion: CompositionType?
    let compositions: [CompositionType]
    let iconRotation: Double
    let onSelect: (CompositionType) -> Void
    var onClearSubject: (() -> Void)?

    @State private var hasAppeared = false
    @State private var scrolledID: CompositionType?

    init(
        selectedComposition: CompositionType?,
        mlSuggestion: CompositionType?,
        compositions: [CompositionType] = Array(CompositionType.allCases),
        iconRotation: Double,
        onSelect: @escaping (CompositionType) -> Void,
        onClearSubject: (() -> Void)? = nil
    ) {
        self.selectedComposition = selectedComposition
        self.mlSuggestion = mlSuggestion
        self.compositions = compositions
        self.iconRotation = iconRotation
        self.onSelect = onSelect
        self.onClearSubject = onClearSubject
    }

    var body: some View {
        VStack(spacing: Spacing.standard) {
            if let onClearSubject {
                ClearSubjectButton(action: onClearSubject)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 10)
                    .popoverTip(SubjectUnlockTip(), arrowEdge: .top)
            }

            GeometryReader { proxy in
                let halfWidth = proxy.size.width / 2
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: Spacing.standard) {
                        ForEach(Array(compositions.enumerated()), id: \.element) { index, comp in
                            CompositionPill(
                                composition: comp,
                                isSelected: selectedComposition == comp,
                                isRecommended: mlSuggestion == comp,
                                iconRotation: iconRotation,
                                onTap: { 
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        onSelect(comp)
                                        scrolledID = comp
                                    }
                                }
                            )
                            .id(comp)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1.0 : 0.85)
                                    .opacity(phase.isIdentity ? 1.0 : 0.6)
                            }
                            .opacity(hasAppeared ? 1 : 0)
                            .offset(y: hasAppeared ? 0 : 20)
                            .animation(
                                .spring(response: 0.45, dampingFraction: 0.75)
                                    .delay(Double(index) * 0.06),
                                value: hasAppeared
                            )
                        }
                    }
                    .padding(.bottom, 12)
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $scrolledID, anchor: .center)
                .scrollTargetBehavior(.viewAligned)
                .safeAreaPadding(.horizontal, max(0, halfWidth - 45))
                .onChange(of: scrolledID) { _, newValue in
                    if let newValue, newValue != selectedComposition {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            onSelect(newValue)
                        }
                    }
                }
                .onChange(of: selectedComposition) { _, newValue in
                    if newValue != scrolledID {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                            scrolledID = newValue
                        }
                    }
                }
                .onAppear {
                    scrolledID = selectedComposition
                }
            }
            .frame(height: 120) // fixed height for GeometryReader
        }
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

private struct CompositionPill: View {
    let composition: CompositionType
    let isSelected: Bool
    let isRecommended: Bool
    let iconRotation: Double
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                if isSelected {
                    selectedPill
                } else {
                    unselectedPill
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.92 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
        .animation(.spring(response: 0.15, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel("\(composition.rawValue) composition")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isRecommended && isSelected ? "Suggested recommendation" : "")
    }

    private var selectedPill: some View {
        VStack(spacing: 8) {
            if isRecommended && isSelected {
                RecommendationBadge()
                    .rotationEffect(.degrees(iconRotation))
            } else {
                Spacer().frame(height: 14)
            }

            Image(systemName: composition.symbolName)
                .font(.title2)
                .foregroundStyle(.white)
                .rotationEffect(.degrees(iconRotation))

            Text(composition.shortLabel)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)
                .rotationEffect(.degrees(iconRotation))
        }
        .padding(.top, 8)
        .padding(.bottom, 12)
        .frame(width: 90)
        .background {
            if #available(iOS 26, *) {
                RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge)
                    .fill(Color.black.opacity(0.35))
                    .glassEffect(.regular, in: .rect(cornerRadius: Spacing.cornerRadiusLarge))
            } else {
                RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge)
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge)
                .strokeBorder(AppColors.controlActive, lineWidth: 1.5)
        )
    }

    private var unselectedPill: some View {
        VStack(spacing: 8) {
            ZStack {
                if #available(iOS 26, *) {
                    RoundedRectangle(cornerRadius: Spacing.cornerRadiusMedium)
                        .fill(Color.black.opacity(0.35))
                        .glassEffect(.regular, in: .rect(cornerRadius: Spacing.cornerRadiusMedium))
                } else {
                    RoundedRectangle(cornerRadius: Spacing.cornerRadiusMedium)
                        .fill(.ultraThinMaterial.opacity(0.5))
                }
                
                Image(systemName: composition.symbolName)
                    .font(.title2)
                    .foregroundStyle(.white)
                    .rotationEffect(.degrees(iconRotation))
            }
            .frame(width: 60, height: 60)

            Text(composition.shortLabel)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .rotationEffect(.degrees(iconRotation))
        }
        .frame(width: 64)
    }
}

// MARK: - ClearSubjectButton

private struct ClearSubjectButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "lock.open.fill")
                    .font(.subheadline.weight(.medium))
                Text("Clear object")
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(AppColors.controlActive)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                if #available(iOS 26, *) {
                    Capsule()
                        .fill(Color.black.opacity(0.35))
                        .glassEffect(.regular, in: .capsule)
                } else {
                    Capsule()
                        .fill(.ultraThinMaterial)
                }
            }
            .overlay(
                Capsule().strokeBorder(AppColors.controlActive.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Clear object")
        .accessibilityHint("Unlocks the current object so you can choose another")
    }
}

// MARK: - RecommendationBadge

private struct RecommendationBadge: View {
    var body: some View {
        Text("Suggested")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.green.opacity(0.3)) // Subtler green background matching design
                    .overlay(Capsule().strokeBorder(Color.green, lineWidth: 0.5))
            )
            .accessibilityLabel("Suggested recommendation")
    }
}

