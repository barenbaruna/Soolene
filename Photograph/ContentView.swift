//
//  ContentView.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import SwiftUI

struct ContentView: View {

    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        if hasSeenOnboarding {
            CameraView()
        } else {
            OnboardingView()
        }
    }
}

#Preview {
    ContentView()
}
