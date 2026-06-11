//
//  ZoomRulerView.swift
//  Photograph
//
//  Ruler-style zoom indicator above the shutter row (design reference).
//

import SwiftUI

struct ZoomRulerView: View {
    let lenses: [LensType]
    let selectedLens: LensType
    let onSelect: (LensType) -> Void

    private let tickCount = 21

    var body: some View {
        VStack(spacing: Spacing.tiny) {
            Text(selectedLens.rawValue)
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(AppColors.controlActive)

            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(0..<tickCount, id: \.self) { index in
                            Rectangle()
                                .fill(AppColors.secondary.opacity(tickOpacity(for: index)))
                                .frame(
                                    width: index % 5 == 0 ? 2 : 1,
                                    height: index % 5 == 0 ? 14 : 8
                                )
                            if index < tickCount - 1 {
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .frame(width: width)

                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: 8, height: 8)
                        .offset(x: knobOffset(in: width) - 4)
                }
            }
            .frame(height: 18)

            if lenses.count > 1 {
                HStack(spacing: Spacing.standard) {
                    ForEach(lenses) { lens in
                        Button {
                            HapticManager.selection()
                            onSelect(lens)
                        } label: {
                            Text(lens.rawValue)
                                .font(.caption2.weight(selectedLens == lens ? .bold : .regular))
                                .monospacedDigit()
                                .foregroundStyle(
                                    selectedLens == lens ? AppColors.controlActive : AppColors.textGuide
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: 280)
        .padding(.horizontal, Spacing.standard)
    }

    private func tickOpacity(for index: Int) -> Double {
        let center = Double(tickCount - 1) / 2
        let distance = abs(Double(index) - center) / center
        return max(0.25, 1.0 - distance * 0.6)
    }

    private func knobOffset(in width: CGFloat) -> CGFloat {
        guard lenses.count > 1,
              let idx = lenses.firstIndex(of: selectedLens)
        else { return width / 2 }
        let fraction = CGFloat(idx) / CGFloat(max(lenses.count - 1, 1))
        return fraction * width
    }
}
