//
//  ContentView.swift
//  Photograph
//
//  Root view. Controls the app flow:
//  - Splash screen → Camera (with walkthrough tooltips if first launch)
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var onboardingManager = OnboardingManager()

    var body: some View {
        Group {
            if !onboardingManager.hasCompletedSplash {
                SplashView()
            } else {
                CameraView()
            }
        }
        .environmentObject(onboardingManager)
    }
}

#Preview {
    ContentView()
}
