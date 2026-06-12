//
//  LensSelectorView.swift
//  Photograph
//
//  Discrete zoom lens chips — matches native Camera discrete levels (not a slider).
//

import SwiftUI

/// Horizontal lens selector for supported zoom levels (0.5×, 1×, 2×, 3×).
struct LensSelectorView: View {
    let availableLenses: [LensType]
    let selectedLens: LensType
    let onSelect: (LensType) -> Void
    var iconRotation: Double = 0
    var isEnabled: Bool = true

    var body: some View {
        if availableLenses.count > 1 {
            lensChipRow
        }
    }

    @ViewBuilder
    private var lensChipRow: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: Spacing.small) {
                chipButtons
            }
        } else {
            chipButtons
                .padding(.horizontal, Spacing.small)
                .padding(.vertical, Spacing.tiny)
                .background(.ultraThinMaterial, in: Capsule())
        }
    }

    private var chipButtons: some View {
        HStack(spacing: Spacing.small) {
            ForEach(availableLenses) { lens in
                lensButton(for: lens)
            }
        }
    }

    private func lensButton(for lens: LensType) -> some View {
        let isSelected = selectedLens == lens

        return Button {
            guard isEnabled else { return }
            onSelect(lens)
        } label: {
            Text(lens.rawValue)
                .font(.subheadline.weight(isSelected ? .bold : .medium))
                .monospacedDigit()
                .foregroundStyle(isSelected ? AppColors.controlActive : AppColors.textGuide)
                .rotationEffect(.degrees(iconRotation))
                .frame(minWidth: ControlMetrics.compactIconButton, minHeight: ControlMetrics.compactIconButton)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .lensChipBackground(isSelected: isSelected)
        .accessibilityLabel("\(lens.rawValue) zoom")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .disabled(!isEnabled)
    }
}

// MARK: - Chip background (availability-gated)

private extension View {
    @ViewBuilder
    func lensChipBackground(isSelected: Bool) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(
                isSelected
                    ? .regular.tint(AppColors.controlActive.opacity(0.2)).interactive()
                    : .regular.interactive(),
                in: .capsule
            )
        } else {
            self
                .background(
                    Capsule()
                        .fill(isSelected
                            ? AnyShapeStyle(AppColors.controlActive.opacity(0.15))
                            : AnyShapeStyle(Color.white.opacity(0.08)))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? AppColors.controlActive.opacity(0.55) : Color.clear,
                            lineWidth: 1.5
                        )
                )
        }
    }
}
