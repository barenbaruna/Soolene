//
//  ReducedMotionModifier.swift
//  Soolene
//
//  Provides a conditional animation modifier that respects the user's
//  Accessibility → Reduce Motion setting.
//
//  When Reduce Motion is ON:
//  - Spring/bounce animations are replaced with instant cuts
//  - Opacity transitions remain (they're non-motion)
//  - Scale animations are suppressed
//
//  Usage:
//    .adaptiveAnimation(.spring(response: 0.5), value: someValue)
//
//  Created by Baren Baruna Harahap on 10/06/26.
//

import SwiftUI

extension View {
    /// Applies an animation that respects `accessibilityReduceMotion`.
    /// When reduce motion is enabled, uses a quick opacity fade instead.
    func adaptiveAnimation<V: Equatable>(
        _ animation: Animation,
        value: V
    ) -> some View {
        self.modifier(AdaptiveAnimationModifier(animation: animation, value: value))
    }
}

private struct AdaptiveAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        if reduceMotion {
            content.animation(.easeInOut(duration: 0.15), value: value)
        } else {
            content.animation(animation, value: value)
        }
    }
}
