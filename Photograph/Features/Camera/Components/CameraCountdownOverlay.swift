//
//  CameraCountdownOverlay.swift
//  Soolene
//
//  Timer countdown displayed over the viewfinder.
//

import SwiftUI

struct CameraCountdownOverlay: View {
    let value: Int

    var body: some View {
        Text("\(value)")
            .font(.system(size: 72, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(AppColors.primary)
            .shadow(color: .black.opacity(0.4), radius: 8)
            .transition(.scale.combined(with: .opacity))
            .accessibilityLabel("Timer")
            .accessibilityValue("\(value) seconds remaining")
    }
}
