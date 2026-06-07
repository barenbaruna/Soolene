//
//  CaptureButtonView.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import SwiftUI

struct CaptureButton: View {
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
                // Outer ring (SystemGray2)
                Circle()
                    .fill(Color(uiColor: .systemGray2))
                    .frame(width: 76, height: 76)

                // Inner filled circle with primary border
                ZStack {
                    Circle()
                        .fill(.white)
                    Circle()
                        .strokeBorder(AppColors.primary, lineWidth: 2)
                }
                .frame(width: Spacing.cornerRadiusXXLarge, height: Spacing.cornerRadiusXXLarge)
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
        CaptureButton(action: {})
    }
}
