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
            .font(.system(size: 120, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color.white)
            .shadow(color: .black.opacity(0.4), radius: 8)
            .transition(.scale.combined(with: .opacity))
            .accessibilityLabel("Timer")
            .accessibilityValue("\(value) seconds remaining")
    }
}
