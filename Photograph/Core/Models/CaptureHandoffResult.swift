//
//  CaptureHandoffResult.swift
//  Soolene
//

import Foundation

/// Outcome of an AR → AV → AR capture handoff.
struct CaptureHandoffResult: Equatable {
    var photoData: Data?
    var trackingRecovered: Bool
    var recoveryDeferred: Bool = false
    var usedWorldMap: Bool
    var elapsedSeconds: TimeInterval

    var success: Bool { photoData != nil }
}
