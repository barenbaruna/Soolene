//
//  CompositionGridView.swift
//  Soolene
//

import SwiftUI

/// Shared composition guide drawing for live camera and gallery replay.
struct CompositionGridView: View {
    let composition: CompositionType
    let fullRect: CGRect
    let aspectRect: CGRect
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

    var body: some View {
        ZStack {
            // Draw grids centered inside aspectRect
            ZStack {
                switch composition {
                case .ruleOfThirds:
                    RuleOfThirdsGrid(
                        size: aspectRect.size,
                        color: color,
                        fullRect: fullRect,
                        aspectRect: aspectRect,
                        geometry: geometry,
                        lockedTarget: lockedTarget,
                        isPerfect: isPerfect,
                        showsIntersectionMarkers: showsIntersectionMarkers
                    )
                case .center:
                    CenterGrid(size: aspectRect.size, color: color, isPerfect: isPerfect)
                case .horizontal:
                    let isLandscape = orientation.isLandscape
                    let gridW = isLandscape ? aspectRect.height : aspectRect.width
                    let gridH = isLandscape ? aspectRect.width : aspectRect.height
                    HorizontalGrid(size: CGSize(width: gridW, height: gridH), color: color, isPerfect: isPerfect)
                        .frame(width: gridW, height: gridH)
                        .rotationEffect(.degrees(rotationAngle))
                case .vertical:
                    let isLandscape = orientation.isLandscape
                    let gridW = isLandscape ? aspectRect.height : aspectRect.width
                    let gridH = isLandscape ? aspectRect.width : aspectRect.height
                    VerticalGrid(size: CGSize(width: gridW, height: gridH), color: color, isPerfect: isPerfect)
                        .frame(width: gridW, height: gridH)
                        .rotationEffect(.degrees(rotationAngle))
                case .diagonal:
                    DiagonalGrid(size: aspectRect.size, color: color, isPerfect: isPerfect)
                }
            }
            .frame(width: aspectRect.width, height: aspectRect.height)
            .position(x: aspectRect.midX, y: aspectRect.midY)

            if showSubjectBox {
                SubjectBox(faceRect: geometry.faceRects.first, frameRect: fullRect, color: color)
            }
        }
        .frame(width: fullRect.width, height: fullRect.height)
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            withAnimation(.spring(response: 0.3)) {
                orientation = UIDevice.current.orientation
            }
        }
    }
}
