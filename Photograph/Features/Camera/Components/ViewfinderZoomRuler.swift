//
//  ViewfinderZoomRuler.swift
//  Photograph
//
//  Continuous zoom ruler — floats above gallery / shutter / flip bar.
//

import SwiftUI

struct ViewfinderZoomRuler: View {
    @Bindable var viewModel: CameraViewModel
    let isEnabled: Bool

    @State private var isDragging = false

    private var zoomController: ZoomController { viewModel.zoomController }

    var body: some View {
        ViewfinderRulerPanel {
            LiquidGlassCenterRuler(
                value: zoomController.displayMultiplier,
                range: zoomController.displayRange,
                formattedValue: formattedZoom(zoomController.displayMultiplier),
                activeColor: AppColors.controlActive,
                tickLayout: zoomController.tickLayout,
                isDragging: isDragging,
                onValueChanged: { viewModel.setZoomMultiplier($0, isFinal: false) },
                onDragBegan: {
                    isDragging = true
                    viewModel.onZoomRulerDragBegan()
                },
                onDragEnded: {
                    isDragging = false
                    viewModel.setZoomMultiplier(zoomController.displayMultiplier, isFinal: true)
                }
            )
        }
        .animation(.snappy, value: isDragging)
        .opacity(isEnabled ? 1 : 0.5)
        .allowsHitTesting(isEnabled)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Zoom")
        .accessibilityValue("\(formattedZoom(zoomController.displayMultiplier)) times")
        .accessibilityAdjustableAction { direction in
            let step = zoomController.tickLayout.minorStep
            let next = zoomController.displayMultiplier + (direction == .increment ? step : -step)
            viewModel.setZoomMultiplier(next, isFinal: true)
        }
    }

    private func formattedZoom(_ value: CGFloat) -> String {
        let rounded = (value * 10).rounded() / 10
        if abs(rounded - rounded.rounded()) < 0.05 {
            return String(format: "%.0f×", rounded)
        }
        return String(format: "%.1f×", rounded)
    }
}
