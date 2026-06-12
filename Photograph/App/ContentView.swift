//
//  ContentView.swift
//  Photograph
//

import SwiftUI

struct ContentView: View {
    @State private var onboarding = OnboardingStore()

    var body: some View {
        Group {
            if !onboarding.hasCompletedSplash {
                SplashView()
            } else {
                CameraView()
            }
        }
        .environment(onboarding)
    }
}

#Preview {
    ContentView()
}
