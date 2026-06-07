//
//  PinnedSubjectBadge.swift
//  Photograph
//
//  A small pill-shaped indicator shown when the user has manually pinned
//  a subject. Displays instructions on how to reset the pin.
//  Positioned at the bottom center to avoid colliding with the composition
//  guidance tip in the upper middle of the screen.
//
//  Created by Baren Baruna Harahap on 06/06/26.
//

import SwiftUI

struct PinnedSubjectBadge: View {
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.focus")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(AppColors.primary)
                .scaleEffect(isPulsing ? 1.1 : 1.0)

            Text("Focus Locked")
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(.white)

            Text("•")
                .foregroundStyle(.white.opacity(0.4))

            Text("Double-tap to reset")
                .font(Typography.caption)
                .foregroundStyle(.white.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(AppColors.primary.opacity(isPulsing ? 0.6 : 0.2), lineWidth: 1.5)
                )
                .shadow(color: AppColors.primary.opacity(isPulsing ? 0.3 : 0), radius: isPulsing ? 8 : 0)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black
        PinnedSubjectBadge()
    }
}
