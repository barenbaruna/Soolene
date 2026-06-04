//
//  CompositionOverlayView.swift
//  Photograph
//
//  Draws composition guide overlays using pure SwiftUI View Decomposition.
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import SwiftUI

/// Main Organism for the Composition Overlay.
/// Drives color logic based on scene alignment score and switches between
/// different composition molecules.
struct CompositionOverlayView: View {
    let composition: CompositionType
    let geometry: SceneGeometry
    let aspectRatio: AspectRatioMode
    let subjectOffset: CGVector
    let isPerfect: Bool
    let sceneAlignmentScore: Float
    let hasSceneData: Bool
    
    // MARK: - Color Logic
    
    /// Returns the current guide color based on scene alignment score.
    ///
    /// - White:  No Vision data yet (score == 0.0)
    /// - Red:    Vision data present, composition not yet aligned (score < 0.8)
    /// - Green:  Vision data present, composition is aligned (score >= 0.8)
    private var guideColor: Color {
        if !hasSceneData { return Color(uiColor: .gridlineWhite) }
        return sceneAlignmentScore >= 0.8 ? Color(uiColor: .gridlineGreen) : Color(uiColor: .gridlineRed)
    }
    
    // MARK: - Body
    
    var body: some View {
        GeometryReader { proxy in
            let fullRect = proxy.frame(in: .local)
            let drawRect = aspectMaskedRect(in: fullRect)
            
            ZStack {
                // Dim area outside the chosen aspect ratio
                if aspectRatio != .free {
                    AspectMask(fullRect: fullRect, contentRect: drawRect)
                }
                
                // Draw the per-composition guide
                switch composition {
                case .ruleOfThirds:
                    RuleOfThirdsGrid(rect: drawRect, color: guideColor, geometry: geometry, isPerfect: isPerfect)
                case .center:
                    CenterGrid(rect: drawRect, color: guideColor, isPerfect: isPerfect)
                case .horizontal:
                    HorizontalGrid(rect: drawRect, color: guideColor, isPerfect: isPerfect)
                case .vertical:
                    VerticalGrid(rect: drawRect, color: guideColor, isPerfect: isPerfect)
                case .diagonal:
                    DiagonalGrid(rect: drawRect, color: guideColor, isPerfect: isPerfect)
                }
                
                // Draw detected subject indicator (face box)
                SubjectBoxAtom(faceRect: geometry.faceRect, frameRect: drawRect, color: guideColor)
            }
            .allowsHitTesting(false)
        }
    }
    
    // MARK: - Aspect Mask Calculation
    
    private func aspectMaskedRect(in rect: CGRect) -> CGRect {
        guard aspectRatio != .free else { return rect }

        let ratio: CGFloat
        switch aspectRatio {
        case .oneOne:      ratio = 1.0
        case .fourThree:   ratio = 3.0 / 4.0
        case .sixteenNine: ratio = 9.0 / 16.0
        case .free:        return rect
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
