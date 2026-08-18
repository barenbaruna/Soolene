//
//  TrackingStabilityMeter.swift
//  Soolene
//
//  Gold tick meter shown while AR tracking stabilizes for capture.
//

import SwiftUI

struct TrackingStabilityMeter: View {
    let progress: Float

    private let tickCount = 5

    var body: some View {
        VStack(spacing: Spacing.tiny) {
            Text("Stabilizing")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.controlActive)

            HStack(spacing: 0) {
                ForEach(0..<tickCount, id: \.self) { index in
                    Rectangle()
                        .fill(tickColor(for: index))
                        .frame(width: index == activeTickIndex ? 2 : 1, height: tickHeight(for: index))
                    if index < tickCount - 1 {
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: 16)
        }
        .frame(maxWidth: 200)
        .accessibilityLabel("Tracking stabilizing")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }

    private var activeTickIndex: Int {
        min(tickCount - 1, max(0, Int(progress * Float(tickCount))))
    }

    private func tickColor(for index: Int) -> Color {
        index <= activeTickIndex
            ? AppColors.controlActive
            : AppColors.textGuide.opacity(0.35)
    }

    private func tickHeight(for index: Int) -> CGFloat {
        index == activeTickIndex ? 14 : 8
    }
}
