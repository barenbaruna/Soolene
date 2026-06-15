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
    var showsIntersectionMarkers: Bool = true

    private var guideColor: Color {
        if !hasSceneData { return Color(uiColor: .gridlineWhite) }
        if isPerfect { return Color(uiColor: .gridlineGreen) }
        if isStabilizing { return AppColors.controlActive }
        return Color(uiColor: .gridlineRed)
    }

    var body: some View {
        GeometryReader { proxy in
            let fullRect = proxy.frame(in: .local)
            // Aspect mask was moved to CameraGuidanceOverlayStack so it's always visible
            
            CompositionGridView(
                composition: composition,
                rect: fullRect,
                color: guideColor,
                geometry: geometry,
                lockedTarget: geometry.lockedTargetPoint,
                isPerfect: isPerfect,
                showSubjectBox: false,
                showsIntersectionMarkers: showsIntersectionMarkers
            )
            .allowsHitTesting(false)
        }
    }
}
