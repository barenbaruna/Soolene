//
//  SplashView.swift
//  Soolene
//
//  Splash / intro screen matching Hi-Fi:
//  - Dark background (AppColors.screen)
//  - App icon from Assets
//  - "Soolene" title + italic tagline
//  - Auto-transitions after 2.5 seconds
//
//  Uses Design System tokens: AppColors, Typography, Spacing.
//
//  Created by Baren Baruna Harahap on 06/06/26.
//

import SwiftUI

struct SplashView: View {
    @Environment(OnboardingStore.self) private var onboarding
    @State private var contentOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                // App Icon — loads from the asset catalog
                appIcon

                // App name and tagline
                VStack(spacing: 12) {
                    Text(AppIdentity.displayName)
                        .font(Typography.title)
                        .foregroundStyle(AppColors.primary)

                    Text("seeing depth through a lens")
                        .font(Typography.body)
                        .foregroundStyle(AppColors.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Spacing.extraLarge)
                }

                Spacer()
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            // Fade in
            withAnimation(.easeIn(duration: 0.8)) {
                contentOpacity = 1
            }
            // Auto-dismiss after 2.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(.easeOut(duration: 0.5)) {
                    onboarding.hasCompletedSplash = true
                }
            }
        }
    }

    // MARK: - App Icon

    /// Attempts to load the app icon from the bundle; falls back to a styled "V".
    @ViewBuilder
    private var appIcon: some View {
        if let image = UIImage(named: "SplashView") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        } else {
            Text("S")
                .font(.system(size: 120, weight: .bold, design: .serif))
                .italic()
                .foregroundStyle(AppColors.primary)
        }
    }
}

#Preview {
    SplashView()
        .environment(OnboardingStore())
}
