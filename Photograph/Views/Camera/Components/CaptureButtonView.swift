//
//  CaptureButtonView.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import SwiftUI

struct CaptureButtonView: View {
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.easeIn(duration: 0.05)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeOut(duration: 0.15)) { isPressed = false }
            }
            action()
        }) {
            ZStack {
                // Outer ring
                Circle()
                    .strokeBorder(.white.opacity(0.9), lineWidth: 3)
                    .frame(width: 76, height: 76)

                // Inner filled circle
                Circle()
                    .fill(.white)
                    .frame(width: 62, height: 62)
                    .scaleEffect(isPressed ? 0.85 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: isPressed)
            }
        }
        .accessibilityLabel("Capture Photo")
        .accessibilityHint("Takes a photo with the current composition overlay")
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        CaptureButtonView(action: {})
    }
}
