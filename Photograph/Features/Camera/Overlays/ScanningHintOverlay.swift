//
//  ScanningHintOverlay.swift
//  Photograph
//
//  Displayed during the `.scanning` phase to invite the user to long-press a subject.
//
//  Visual elements:
//  - Center viewfinder icon with gentle wiggle animation
//  - Saliency hint circle: when Vision detects a prominent area, a faint circle
//    appears to suggest "you can tap here"
//  - Breathing opacity animation on the viewfinder
//
//  Created by Baren Baruna Harahap on 10/06/26.
//

import SwiftUI

struct ScanningHintOverlay: View {
    let saliencyCentroid: CGPoint?
    let faceDetected: Bool

    @State private var breathing = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Center viewfinder icon — "I'm ready, tap something"
                Image(systemName: "viewfinder")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundStyle(.white.opacity(breathing ? 0.25 : 0.12))
                    .position(x: w / 2, y: h / 2)

                // Saliency hint — subtle circle where Vision found something interesting
                if let centroid = saliencyCentroid {
                    let px = CGPoint(x: centroid.x * w, y: centroid.y * h)

                    Circle()
                        .strokeBorder(.white.opacity(breathing ? 0.2 : 0.08), lineWidth: 1)
                        .frame(width: 80, height: 80)
                        .position(px)

                    // Inner dot
                    Circle()
                        .fill(.white.opacity(0.1))
                        .frame(width: 12, height: 12)
                        .position(px)
                }

                // Face hint — if a face is detected, show a subtle indicator
                if faceDetected, let centroid = saliencyCentroid {
                    let px = CGPoint(x: centroid.x * w, y: centroid.y * h)

                    Image(systemName: "person.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.2))
                        .position(x: px.x, y: px.y - 50)
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
    }
}
