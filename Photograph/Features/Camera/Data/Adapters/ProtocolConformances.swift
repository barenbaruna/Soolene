//
//  ProtocolConformances.swift
//  Soolene
//
//  Bridges existing Core services to Core/Protocols during incremental migration.
//

import Foundation

extension SpatialCameraEngine: SpatialCameraProviding {}

extension CameraManager: ClassicCameraProviding {}

extension VisionService: VisionAnalyzing {}
