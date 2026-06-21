//
//  CameraHandoffOverlay.swift
//  Soolene
//
//  Frozen preview + status during AR ↔ AV session handoff.
//

import SwiftUI

struct CameraHandoffOverlay: View {
    let frozenPreview: UIImage?
    let message: String
    let aspectRatio: AspectRatioMode
    let displayMultiplier: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let fullRect = proxy.frame(in: .local)
            let drawRect = aspectMaskedRect(in: fullRect, aspectRatio: aspectRatio)
            
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                if let frozenPreview {
                    Image(uiImage: frozenPreview)
                        .resizable()
                        .scaledToFill()
                        // 1. Scale image based on user's zoom factor
                        .scaleEffect(displayMultiplier)
                        // 2. Crop to the aspect ratio mask
                        .frame(width: drawRect.width, height: drawRect.height)
                        .clipped()
                        // Position exactly over the camera preview area
                        .position(x: fullRect.midX, y: fullRect.midY)
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
        }
        .allowsHitTesting(true)
        .transition(reduceMotion ? .opacity : .opacity.animation(.easeInOut(duration: 0.2)))
    }
    
    private func aspectMaskedRect(in rect: CGRect, aspectRatio: AspectRatioMode) -> CGRect {
        let ratio: CGFloat
        switch aspectRatio {
        case .oneOne: ratio = 1.0
        case .sixteenNine: ratio = 9.0 / 16.0
        case .fourThree: ratio = 3.0 / 4.0
        }

        var w = rect.width
        var h = w / ratio
        if h > rect.height { h = rect.height; w = h * ratio }
        return CGRect(x: (rect.width - w) / 2, y: (rect.height - h) / 2, width: w, height: h)
    }
}
