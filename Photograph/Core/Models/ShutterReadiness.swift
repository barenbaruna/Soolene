//
//  ShutterReadiness.swift
//  Soolene
//
//  Unified shutter visual state — composition alignment vs capture readiness.
//

import Foundation

/// Drives shutter color and glow: olive → gold (stabilizing) → green (ready).
enum ShutterReadiness: Equatable {
    case idle
    case stabilizing
    case ready

    var isCaptureEnabled: Bool {
        self == .ready
    }
}
