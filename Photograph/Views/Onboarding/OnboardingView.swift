//
//  OnboardingView.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import SwiftUI

/// Simple 3-page onboarding explaining what the app does and what the overlays mean.
struct OnboardingView: View {

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            symbol: "viewfinder.rectangular",
            title: "Frame Your Scene",
            body: "FrameIt helps you apply photography composition techniques in real time, right through your camera.",
            accent: .blue
        ),
        OnboardingPage(
            symbol: "grid",
            title: "Live Overlays",
            body: "Visual guides like Rule of Thirds, Center, Horizontal, Vertical, and Diagonal lines are drawn over your live preview to help you compose.",
            accent: .orange
        ),
        OnboardingPage(
            symbol: "sparkles",
            title: "Smart Guidance",
            body: "The app analyzes your scene geometry in real-time and suggests the best composition technique to guide your framing.",
            accent: .green
        )
    ]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(.systemBackground), pages[currentPage].accent.opacity(0.15)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        pageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page dots
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(currentPage == index ? pages[currentPage].accent : Color.secondary.opacity(0.4))
                            .frame(width: currentPage == index ? 20 : 8, height: 8)
                            .animation(.spring(response: 0.4), value: currentPage)
                    }
                }
                .padding(.bottom, 24)

                // Action button
                Button {
                    if currentPage < pages.count - 1 {
                        withAnimation { currentPage += 1 }
                    } else {
                        hasSeenOnboarding = true
                    }
                } label: {
                    Text(currentPage < pages.count - 1 ? "Next" : "Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .onboardingButtonStyle(accent: pages[currentPage].accent)
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
                .animation(.easeInOut(duration: 0.3), value: currentPage)
            }
        }
    }

    @ViewBuilder
    private func pageView(page: OnboardingPage) -> some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.accent.opacity(0.15))
                    .frame(width: 140, height: 140)
                Image(systemName: page.symbol)
                    .font(.system(size: 56, weight: .medium))
                    .symbolEffect(.pulse)
                    .foregroundStyle(page.accent)
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .onboardingTitleWidth()
                    .multilineTextAlignment(.center)

                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }
}

struct OnboardingPage {
    let symbol: String
    let title: String
    let body: String
    let accent: Color
}

// MARK: - Availability Helpers

private extension View {
    @ViewBuilder
    func onboardingButtonStyle(accent: Color) -> some View {
        if #available(iOS 26, *) {
            self
                .buttonStyle(.glassProminent)
                .tint(accent)
        } else {
            self
                .buttonStyle(.borderedProminent)
                .tint(accent)
        }
    }

    @ViewBuilder
    func onboardingTitleWidth() -> some View {
        if #available(iOS 26, *) {
            self.fontWidth(.expanded)
        } else {
            self // fontWidth not available pre-iOS 26
        }
    }
}

#Preview {
    OnboardingView()
}
