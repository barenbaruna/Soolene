//
//  CameraTopRow.swift
//  Photograph
//
//  Centered phase guidance label below the top toolbar.
//

import SwiftUI

struct CameraTopRow: View {
    let viewModel: CameraViewModel
    let isCountingDown: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !isCountingDown {
            GuidanceTipView(
                phase: viewModel.guidancePhase,
                tip: viewModel.guidanceTip,
                composition: viewModel.userSelectedComposition
                    ?? viewModel.mlSuggestion
                    ?? viewModel.resolvedComposition,
                captureReadiness: viewModel.captureReadiness
            )
            .walkthroughAnchor(.guidanceTip)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.standard)
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.82),
                       value: viewModel.guidancePhase)
        }
    }
}
