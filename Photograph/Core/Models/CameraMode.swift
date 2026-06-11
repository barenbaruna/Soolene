//
//  CameraMode.swift
//  Photograph
//
//  Rear spatial mode uses ARKit world-lock; front classic uses AVFoundation + 2D Vision tracking.
//

import Foundation

enum CameraMode: Equatable {
    case rearSpatial
    case frontClassic
}
