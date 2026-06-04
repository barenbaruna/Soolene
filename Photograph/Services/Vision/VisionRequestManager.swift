//
//  VisionRequestManager.swift
//  Photograph
//
//  Handles the setup and execution of VNImageRequestHandlers for different tiers.
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import CoreML
import Vision

struct VisionRequestManager {
    
    // MARK: - Fast Tier
    
    static func runFastRequests(
        handler: VNImageRequestHandler,
        geometry: inout SceneGeometry
    ) {
        let horizonReq = VNDetectHorizonRequest()
        let faceReq    = VNDetectFaceRectanglesRequest()
        
        try? handler.perform([horizonReq, faceReq])
        
        GeometryExtractor.extractFastTier(
            horizonObs: horizonReq.results?.first,
            faceObs: faceReq.results?.first,
            into: &geometry
        )
    }
    
    // MARK: - Medium Tier
    
    static func runMediumRequests(
        handler: VNImageRequestHandler,
        geometry: inout SceneGeometry
    ) {
        let saliencyReq = VNGenerateAttentionBasedSaliencyImageRequest()
        let bodyPoseReq = VNDetectHumanBodyPoseRequest()
        
        let rectReq = VNDetectRectanglesRequest()
        rectReq.minimumAspectRatio = 0.1
        rectReq.maximumAspectRatio = 0.5
        rectReq.minimumConfidence  = 0.6
        rectReq.maximumObservations = 3
        
        try? handler.perform([saliencyReq, bodyPoseReq, rectReq])
        
        GeometryExtractor.extractSaliency(
            obs: saliencyReq.results?.first as? VNSaliencyImageObservation,
            into: &geometry
        )
        
        GeometryExtractor.extractBodyPose(
            obs: bodyPoseReq.results?.first,
            into: &geometry
        )
        
        GeometryExtractor.extractRectangles(
            rects: rectReq.results as? [VNRectangleObservation],
            into: &geometry
        )
    }
    
    // MARK: - Slow Tier
    
    static func runSlowRequests(
        handler: VNImageRequestHandler,
        model: VNCoreMLModel,
        analysis: inout CompositionAnalysis
    ) {
        let mlReq = VNCoreMLRequest(model: model)
        mlReq.imageCropAndScaleOption = .centerCrop
        try? handler.perform([mlReq])
        
        guard let results = mlReq.results as? [VNClassificationObservation] else { return }
        
        var predictions: [CompositionPrediction] = []
        for obs in results.prefix(5) {
            if let type = CompositionType(coreMLLabel: obs.identifier) {
                predictions.append(CompositionPrediction(type: type, confidence: obs.confidence))
            }
            if predictions.count >= 3 { break }
        }
        analysis.mlPredictions = predictions
    }
}
