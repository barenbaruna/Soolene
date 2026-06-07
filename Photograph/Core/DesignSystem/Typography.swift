//
//  Typography.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 03/06/26.
//

import SwiftUI

/// Standardized typography matching the Design System spec.
///
/// Usage: `.font(Typography.headline)` or `.textStyle(Typography.body)`
enum Typography {

    // MARK: - Scale

    /// 34pt / Bold
    static let largeTitle = Font.system(size: 34, weight: .bold)

    /// 28pt / Semibold
    static let title = Font.system(size: 28, weight: .semibold)

    /// 17pt / Semibold
    static let headline = Font.system(size: 17, weight: .semibold)

    /// 17pt / Regular
    static let body = Font.system(size: 17, weight: .regular)

    /// 15pt / Regular
    static let subheadline = Font.system(size: 15, weight: .regular)

    /// 12pt / Regular
    static let caption = Font.system(size: 12, weight: .regular)

    /// 17pt / Semibold — Buttons and CTAs
    static let buttonCTA = Font.system(size: 17, weight: .semibold)
}

extension View {
    func textStyle(_ font: Font, color: Color = .primary) -> some View {
        self.font(font)
            .foregroundStyle(color)
    }
}
