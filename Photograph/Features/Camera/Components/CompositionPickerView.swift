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

    private var isPortrait: Bool {
        return abs(iconRotation.truncatingRemainder(dividingBy: 180)) < 45
    }

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
                                    .scaleEffect(phase.isIdentity ? 1.0 : 0.75)
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
            .frame(height: 180) // fixed height to prevent layout jumps during device rotation
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

// MARK: - PillButtonStyle

private struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - CompositionPill

private struct CompositionPill: View {
    let composition: CompositionType
    let isSelected: Bool
    let isRecommended: Bool
    let iconRotation: Double
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // Glass Box containing Icon and Badge
                ZStack {
                    if #available(iOS 26, *) {
                        RoundedRectangle(cornerRadius: isSelected ? Spacing.cornerRadiusLarge : Spacing.cornerRadiusMedium)
                            .fill(Color.black.opacity(isSelected ? 0.35 : 0.2))
                            .glassEffect(.regular, in: .rect(cornerRadius: isSelected ? Spacing.cornerRadiusLarge : Spacing.cornerRadiusMedium))
                    } else {
                        RoundedRectangle(cornerRadius: isSelected ? Spacing.cornerRadiusLarge : Spacing.cornerRadiusMedium)
                            .fill(.ultraThinMaterial.opacity(isSelected ? 1.0 : 0.5))
                    }
                    
                    RotatedLayout(angle: .degrees(iconRotation)) {
                        Image(systemName: composition.symbolName)
                            .font(.title)
                            .foregroundStyle(.white)
                            .rotationEffect(.degrees(iconRotation))
                    }
                    
                    // Recommended Sparkle Badge (Top Right)
                    if isRecommended {
                        Image(systemName: "sparkles")
                            .font(.system(size: isSelected ? 11 : 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Circle().fill(Color.green))
                            .offset(x: 8, y: -8) // Fixed offset since frame is constant
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .zIndex(1)
                    }
                }
                .frame(width: 80, height: 80) // Constant size, scaled smoothly by scrollTransition
                .overlay(
                    RoundedRectangle(cornerRadius: isSelected ? Spacing.cornerRadiusLarge : Spacing.cornerRadiusMedium)
                        .strokeBorder(
                            isRecommended ? Color.green : (isSelected ? Color.yellow : AppColors.controlActive),
                            lineWidth: isSelected ? (isRecommended ? 2.5 : 1.5) : (isRecommended ? 1.5 : 0)
                        )
                )

                // Text Outside (Bottom)
                RotatedLayout(angle: .degrees(iconRotation)) {
                    Text(composition.shortLabel)
                        .font(.system(size: 12, weight: .medium)) // Constant size
                        .foregroundStyle(isRecommended ? .green : (isSelected ? .yellow : .white))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .rotationEffect(.degrees(iconRotation))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(minHeight: 32, alignment: .top) // Consistent height for 1 vs 2 lines
            }
            .frame(width: 90) // Constant overall pill width
        }
        .buttonStyle(PillButtonStyle())
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
        .accessibilityLabel("\(composition.rawValue) composition")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isRecommended ? "Suggested recommendation" : "")
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
