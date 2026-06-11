//
//  LensSelectorView.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import SwiftUI

/// Horizontal lens selector showing available zoom levels (0.5×, 1×, 2×, 3×).
/// Only shows lenses that the current device actually supports.
struct LensSelectorView: View {
    let availableLenses: [LensType]
    @Binding var selectedLens: LensType
    var iconRotation: Double = 0

    var body: some View {
        if self.availableLenses.count > 1 {
            HStack(spacing: 6) {
                ForEach(self.availableLenses) { lens in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            self.selectedLens = lens
                        }
                    } label: {
                        Text(lens.rawValue)
                            .font(.caption)
                            .fontWeight(self.selectedLens == lens ? .bold : .medium)
                            .monospacedDigit()
                            .foregroundStyle(self.selectedLens == lens ? AppColors.controlActive : .white)
                            .rotationEffect(.degrees(iconRotation))
                            .frame(width: ControlMetrics.settingsButton, height: ControlMetrics.settingsButton)
                    }
                    .lensChipBackground(isSelected: self.selectedLens == lens)
                    .accessibilityLabel("\(lens.rawValue) zoom")
                    .accessibilityAddTraits(self.selectedLens == lens ? .isSelected : [])
                }
            }
        }
    }
}

// MARK: - Chip background (availability-gated)

private extension View {
    @ViewBuilder
    func lensChipBackground(isSelected: Bool) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(
                isSelected ? .regular.tint(AppColors.controlActive.opacity(0.15)).interactive() : .regular.interactive(),
                in: .circle
            )
        } else {
            self
                .background(
                    Circle()
                        .fill(isSelected
                            ? AnyShapeStyle(.ultraThinMaterial)
                            : AnyShapeStyle(Color.white.opacity(0.1)))
                )
                .overlay(
                    Circle()
                        .strokeBorder(isSelected ? AppColors.controlActive.opacity(0.6) : Color.clear, lineWidth: 1)
                )
        }
    }
}
