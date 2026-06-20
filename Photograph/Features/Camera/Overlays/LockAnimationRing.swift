//
//  LockAnimationRing.swift
//  Soolene
//
//  Animated ring burst shown at the subject pin point when the user
//  long-presses to lock a subject. Creates a premium "lock-in" feel.
//
//  Animation sequence:
//  1. Ring expands from 0.5× → 1.5× scale while fading out (0.35s, easeOut)
//  2. Lock icon appears with spring bounce (0.15s delay)
//  3. Golden glow pulses briefly behind the lock icon
//
//  Created by Baren Baruna Harahap on 10/06/26.
//

import SwiftUI

struct LockAnimationRing: View {
    let isAnimating: Bool
    let showIcon: Bool

    var body: some View {
        ZStack {
            // Outer burst ring — scales up and fades
            Circle()
                .strokeBorder(AppColors.primary, lineWidth: 2)
                .frame(width: 80, height: 80)
                .scaleEffect(isAnimating ? 1.6 : 0.5)
                .opacity(isAnimating ? 0 : 0.9)

            // Inner solid ring
            Circle()
                .strokeBorder(AppColors.primary, lineWidth: 2.5)
                .frame(width: 48, height: 48)
                .scaleEffect(isAnimating ? 1.0 : 0.3)
                .opacity(isAnimating ? 0.7 : 0)

            // Golden glow halo
            Circle()
                .fill(AppColors.lockGlow)
                .frame(width: 56, height: 56)
                .blur(radius: 12)
                .opacity(showIcon ? 0.6 : 0)

            // Lock icon
            if showIcon {
                Image(systemName: "lock.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppColors.primary)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
        }
    }
}
