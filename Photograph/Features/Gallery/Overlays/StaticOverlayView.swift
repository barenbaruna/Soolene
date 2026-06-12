//
//  StaticOverlayView.swift
//  Photograph
//

import SwiftUI

/// Composition grid replayed on saved gallery photos.
struct StaticOverlayView: View {
    let composition: CompositionType
    let size: CGSize

    private var drawRect: CGRect {
        CGRect(origin: .zero, size: size)
    }

    var body: some View {
        CompositionGridView(
            composition: composition,
            rect: drawRect,
            color: Color.white.opacity(0.6),
            isPerfect: false,
            showSubjectBox: false
        )
        .frame(width: size.width, height: size.height)
    }
}
