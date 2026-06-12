//
//  CaptureUIState.swift
//  Photograph
//

import Foundation

/// Shutter and capture feedback for the camera presentation layer.
struct CaptureUIState: Equatable {
    var isCapturing = false
    var isHandoffInProgress = false
    var captureError: String?
    var showShutterFlash = false
}
