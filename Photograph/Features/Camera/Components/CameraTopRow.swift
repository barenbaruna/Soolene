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

    var body: some View {
        if !isCountingDown {
            GuidanceTipView(
                phase: viewModel.guidancePhase,
                tip: viewModel.guidanceTip,
                composition: viewModel.userSelectedComposition
                    ?? viewModel.mlSuggestion
                    ?? viewModel.resolvedComposition
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Spacing.standard)
        }
    }
}
