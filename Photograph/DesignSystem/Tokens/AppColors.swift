//
//  AppColors.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 03/06/26.
//

import SwiftUI

/// Standardized color palette based on the Design System.
enum AppColors {
    /// #FFF6C0 - Light Yellow (Used for secondary accents or specific surface highlights)
    static let secondarySurface = Color(hex: 0xFFF6C0)

    /// #D94A3D - Red accent for ML gridlines
    static let gridlineRed = Color(hex: 0xD94A3D)

    /// #7FB77E - Green accent for ML gridlines (perfect alignment)
    static let gridlineGreen = Color(hex: 0x7FB77E)
}

extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 08) & 0xFF) / 255,
            blue: Double((hex >> 00) & 0xFF) / 255,
            opacity: alpha
        )
    }
}
