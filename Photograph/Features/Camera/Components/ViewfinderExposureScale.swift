//
//  ViewfinderExposureScale.swift
//  Photograph
//
//  Continuous EV ruler — tap outside to dismiss (no Done button).
//

import SwiftUI

struct ViewfinderExposureScale: View {
    @Binding var exposureBias: Float

    @State private var isDragging = false
    @State private var hapticEngine = RulerHapticEngine()
    @State private var lastDragValue: CGFloat = 0

    var body: some View {
        ViewfinderRulerPanel {
            LiquidGlassRuler(
                value: CGFloat(exposureBias),
                range: ExposureRulerLayout.range,
                formattedValue: formattedEV,
                activeColor: AppColors.accent,
                isDragging: isDragging,
                onValueChanged: { newValue in
                    let previous = lastDragValue
                    exposureBias = Float(newValue)
                    hapticEngine.handleValueChange(
                        from: previous,
                        to: newValue,
                        majorBoundaries: ExposureRulerLayout.majorBoundaries,
                        minorStep: ExposureRulerLayout.minorStep
                    )
                    lastDragValue = newValue
                },
                onDragBegan: {
                    isDragging = true
                    lastDragValue = CGFloat(exposureBias)
                    hapticEngine.prepareForDrag()
                    hapticEngine.resetDragState()
                },
                onDragEnded: {
                    isDragging = false
                    hapticEngine.resetDragState()
                }
            )
        }
        .animation(.snappy, value: isDragging)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Exposure compensation")
        .accessibilityValue(formattedEV)
    }

    private var formattedEV: String {
        if abs(exposureBias) < 0.05 { return "0.00" }
        return exposureBias > 0
            ? String(format: "+%.2f", exposureBias)
            : String(format: "%.2f", exposureBias)
    }
}
