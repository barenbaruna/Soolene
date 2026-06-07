//
//  GlassModifiers.swift
//  Photograph
//
//  Reusable Liquid Glass view modifiers for camera overlay UI.
//  These wrap content in frosted glass shapes (pill, circle, rounded rect).
//
//  Created by Baren Baruna Harahap on 03/06/26.
//

import SwiftUI

// MARK: - Glass Pill

/// Wraps content in a frosted glass capsule shape.
/// Usage: `Text("Label").glassPill()`
extension View {
    func glassPill() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
    }
}

// MARK: - Glass Circle

/// Wraps content in a frosted glass circle.
/// Usage: `Image(systemName: "bolt").glassCircle(size: 44)`
extension View {
    func glassCircle(size: CGFloat = 56) -> some View {
        self
            .frame(width: size, height: size)
            .background(.regularMaterial, in: Circle())
    }
}

// MARK: - Glass Rounded Rectangle

/// Wraps content in a frosted glass rounded rectangle.
/// Usage: `.glassCard(cornerRadius: 16)`
extension View {
    func glassCard(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
}
