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
    var showsIntersectionMarkers: Bool = true

    @State private var orientation: UIDeviceOrientation = UIDevice.current.orientation

    private var rotationAngle: Double {
        switch orientation {
        case .landscapeLeft: return 90
        case .landscapeRight: return -90
        case .portraitUpsideDown: return 180
        default: return 0
        }
    }

    private var drawRect: CGRect {
        if orientation.isLandscape {
            // Swap width and height, preserving origin
            return CGRect(x: rect.minX, y: rect.minY, width: rect.height, height: rect.width)
        }
        return rect
    }

    var body: some View {
        ZStack {
            switch composition {
            case .ruleOfThirds:
                RuleOfThirdsGrid(
                    rect: rect,
                    color: color,
                    geometry: geometry,
                    lockedTarget: lockedTarget,
                    isPerfect: isPerfect,
                    showsIntersectionMarkers: showsIntersectionMarkers
                )
            case .center:
                CenterGrid(rect: rect, color: color, isPerfect: isPerfect)
            case .horizontal:
                HorizontalGrid(rect: drawRect, color: color, isPerfect: isPerfect)
                    .frame(width: drawRect.width, height: drawRect.height)
                    .rotationEffect(.degrees(rotationAngle))
            case .vertical:
                VerticalGrid(rect: drawRect, color: color, isPerfect: isPerfect)
                    .frame(width: drawRect.width, height: drawRect.height)
                    .rotationEffect(.degrees(rotationAngle))
            case .diagonal:
                DiagonalGrid(rect: rect, color: color, isPerfect: isPerfect)
            }

            if showSubjectBox {
                SubjectBox(faceRect: geometry.faceRects.first, frameRect: rect, color: color)
            }
        }
        .frame(width: rect.width, height: rect.height)
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            withAnimation(.spring(response: 0.3)) {
                orientation = UIDevice.current.orientation
            }
        }
    }
}
