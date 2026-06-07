//
//  Spacing.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 03/06/26.
//

import CoreGraphics
import Foundation

/// Standardized spacing and corner radius tokens matching the Design System spec.
enum Spacing {

    // MARK: - Spacing

    static let tiny: CGFloat       = 4
    static let small: CGFloat      = 8
    static let standard: CGFloat   = 16
    static let medium: CGFloat     = 24
    static let large: CGFloat      = 32
    static let extraLarge: CGFloat = 48

    // MARK: - Corner Radius

    /// 8pt — small cards, chips
    static let cornerRadiusSmall: CGFloat     = 8
    /// 12pt — medium cards
    static let cornerRadiusMedium: CGFloat    = 12
    /// 16pt — standard cards and sheets
    static let cornerRadiusLarge: CGFloat     = 16
    /// 62pt — very-very large (circular buttons, pill-shaped frames)
    static let cornerRadiusXXLarge: CGFloat   = 62
    /// 20pt — capsule/pill shape
    static let cornerRadiusCapsule: CGFloat   = 20
}
