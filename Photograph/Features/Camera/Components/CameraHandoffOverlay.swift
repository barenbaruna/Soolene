//
//  CameraHandoffOverlay.swift
//  Photograph
//
//  Frozen preview + status during AR ↔ AV session handoff.
//

import SwiftUI

struct CameraHandoffOverlay: View {
    let frozenPreview: UIImage?
    let message: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let frozenPreview {
                Image(uiImage: frozenPreview)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
            }

            Color.black.opacity(0.25)
                .ignoresSafeArea()

            VStack(spacing: Spacing.standard) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(reduceMotion ? 0.9 : 1.1)

                Text(message)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textOnCamera)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.large)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(message)
        }
        .allowsHitTesting(true)
        .transition(reduceMotion ? .opacity : .opacity.animation(.easeInOut(duration: 0.2)))
    }
}
