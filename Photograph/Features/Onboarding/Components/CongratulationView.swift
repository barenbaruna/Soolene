//
//  CongratulationView.swift
//  Photograph
//
//  The final onboarding screen — a centered glass card
//  thanking the user with a yellow "Start" CTA button.
//
//  Uses Design System tokens: Typography, Spacing, AppColors, AppRadius.
//
//  Created by Baren Baruna Harahap on 06/06/26.
//

import SwiftUI

struct CongratulationView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: Spacing.medium) {
            // Title
            Text("Congratulation")
                .font(Typography.title)
                .foregroundStyle(.white)

            // Description
            Text("You're ready to go. Follow composition guides as you frame your shot.")
                .font(Typography.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.standard)

            // Start button — yellow CTA matching Design System
            Button(action: onStart) {
                Text("Start")
                    .font(Typography.buttonCTA)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(AppColors.primary, in: RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            }
            .padding(.horizontal, Spacing.large)
        }
        .padding(.vertical, Spacing.large)
        .background(.black.opacity(0.7))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusLarge, style: .continuous))
        .padding(.horizontal, Spacing.extraLarge)
    }
}

#Preview {
    ZStack {
        Color.gray.ignoresSafeArea()
        CongratulationView(onStart: {})
    }
}
