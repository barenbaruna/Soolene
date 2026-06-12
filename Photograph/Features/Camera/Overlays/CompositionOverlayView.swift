//
//  CompositionOverlayView.swift
//  Photograph
//

import SwiftUI

/// Live camera composition grid with aspect mask and alignment-driven colors.
struct CompositionOverlayView: View {
    let composition: CompositionType
    let geometry: SceneGeometry
    let aspectRatio: AspectRatioMode
    let subjectOffset: CGVector
    let isPerfect: Bool
    var isStabilizing: Bool = false
    let sceneAlignmentScore: Float
    let hasSceneData: Bool

    private var guideColor: Color {
        if !hasSceneData { return Color(uiColor: .gridlineWhite) }
        if isPerfect { return Color(uiColor: .gridlineGreen) }
        if isStabilizing { return AppColors.controlActive }
        return Color(uiColor: .gridlineRed)
    }

    var body: some View {
        GeometryReader { proxy in
            let fullRect = proxy.frame(in: .local)
            let drawRect = aspectMaskedRect(in: fullRect)

            ZStack {
                if aspectRatio != .free {
                    AspectMask(fullRect: fullRect, contentRect: drawRect)
                }

                CompositionGridView(
                    composition: composition,
                    rect: drawRect,
                    color: guideColor,
                    geometry: geometry,
                    lockedTarget: geometry.lockedTargetPoint,
                    isPerfect: isPerfect
                )
            }
            .allowsHitTesting(false)
        }
    }

    private func aspectMaskedRect(in rect: CGRect) -> CGRect {
        guard aspectRatio != .free else { return rect }

        let ratio: CGFloat
        switch aspectRatio {
        case .oneOne: ratio = 1.0
        case .fourThree: ratio = 3.0 / 4.0
        case .sixteenNine: ratio = 9.0 / 16.0
        case .free: return rect
        }

        var w = rect.width
        var h = w / ratio
        if h > rect.height { h = rect.height; w = h * ratio }

        return CGRect(
            x: rect.midX - w / 2,
            y: rect.midY - h / 2,
            width: w,
            height: h
        )
    }
}
