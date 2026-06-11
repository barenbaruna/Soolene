//
//  ViewfinderExposureScale.swift
//  Photograph
//
//  Horizontal EV scale overlay at the bottom of the viewfinder (design reference).
//

import SwiftUI

struct ViewfinderExposureScale: View {
    @Binding var exposureBias: Float
    let onDismiss: () -> Void

    @State private var dragStart: Float?

    private let tickCount = 31

    var body: some View {
        VStack(spacing: Spacing.small) {
            Text(formattedValue)
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(AppColors.controlActive)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    HStack(spacing: 0) {
                        ForEach(0..<tickCount, id: \.self) { index in
                            Rectangle()
                                .fill(AppColors.secondary.opacity(index % 5 == 0 ? 1 : 0.45))
                                .frame(width: 1, height: index % 5 == 0 ? 16 : 10)
                            if index < tickCount - 1 {
                                Spacer(minLength: 0)
                            }
                        }
                    }

                    Circle()
                        .strokeBorder(AppColors.controlActive, lineWidth: 2)
                        .background(Circle().fill(Color.black.opacity(0.35)))
                        .frame(width: 14, height: 14)
                        .offset(x: knobOffset(in: geo.size.width) - 7)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if dragStart == nil { dragStart = exposureBias }
                            guard let start = dragStart else { return }
                            let delta = Float(value.translation.width / 80)
                            exposureBias = min(max(start + delta, -2), 2)
                        }
                        .onEnded { _ in dragStart = nil }
                )
            }
            .frame(height: 20)
        }
        .padding(.horizontal, Spacing.large)
        .padding(.vertical, Spacing.small)
        .background(Color.black.opacity(0.35))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Exposure")
        .accessibilityValue(formattedValue)
    }

    private func knobOffset(in width: CGFloat) -> CGFloat {
        let normalized = (CGFloat(exposureBias) + 2) / 4
        return normalized * width
    }

    private var formattedValue: String {
        if abs(exposureBias) < 0.05 { return "0.0" }
        return exposureBias > 0
            ? String(format: "+%.1f", exposureBias)
            : String(format: "%.1f", exposureBias)
    }
}
