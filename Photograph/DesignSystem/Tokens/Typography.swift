//
//  Typography.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 03/06/26.
//

import SwiftUI

/// Standardized typography based on the Design System.
enum Typography {
    static let largeTitle = Font.largeTitle.weight(.bold)
    static let title = Font.title.weight(.semibold)
    static let headline = Font.headline.weight(.semibold)
    static let body = Font.body
    static let subheadline = Font.subheadline
    static let caption = Font.caption
}

extension View {
    func textStyle(_ font: Font, color: Color = .primary) -> some View {
        self.font(font)
            .foregroundStyle(color)
    }
}
