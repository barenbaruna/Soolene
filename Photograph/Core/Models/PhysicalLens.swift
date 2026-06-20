//
//  PhysicalLens.swift
//  Soolene
//
//  Optical lens constituents — telemetry and mapping only (not UI).
//

import Foundation

/// Physical rear camera role on the device.
enum PhysicalLens: String, Equatable, Sendable {
    case ultraWide
    case wide
    case tele3x
    case tele5x
}
