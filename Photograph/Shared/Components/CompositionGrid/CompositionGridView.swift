//
//  CompositionGridView.swift
//  Photograph
//

import SwiftUI

/// Shared composition guide drawing for live camera and gallery replay.
struct CompositionGridView: View {
    let composition: CompositionType
    let rect: CGRect
    let color: Color
    var geometry: SceneGeometry = SceneGeometry()
    var lockedTarget: CGPoint?
    var isPerfect: Bool = false
    var showSubjectBox: Bool = true

    var body: some View {
        ZStack {
            switch composition {
            case .ruleOfThirds:
                RuleOfThirdsGrid(
                    rect: rect,
                    color: color,
                    geometry: geometry,
                    lockedTarget: lockedTarget,
                    isPerfect: isPerfect
                )
            case .center:
                CenterGrid(rect: rect, color: color, isPerfect: isPerfect)
            case .horizontal:
                HorizontalGrid(rect: rect, color: color, isPerfect: isPerfect)
            case .vertical:
                VerticalGrid(rect: rect, color: color, isPerfect: isPerfect)
            case .diagonal:
                DiagonalGrid(rect: rect, color: color, isPerfect: isPerfect)
            }

            if showSubjectBox {
                SubjectBox(faceRect: geometry.faceRects.first, frameRect: rect, color: color)
            }
        }
    }
}
