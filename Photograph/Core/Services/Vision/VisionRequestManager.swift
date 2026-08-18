//
//  VisionRequestManager.swift
//  Soolene
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
        geometry: inout SceneGeometry,
        isFrontCamera: Bool
    ) {
        let horizonReq = VNDetectHorizonRequest()
        let faceReq    = VNDetectFaceRectanglesRequest()
        
        try? handler.perform([horizonReq, faceReq])
        
        GeometryExtractor.extractFastTier(
            horizonObs: horizonReq.results?.first,
            faces: faceReq.results as? [VNFaceObservation],
            isFrontCamera: isFrontCamera,
            into: &geometry
        )
    }
    
    // MARK: - Medium Tier
    
    static func runMediumRequests(
        handler: VNImageRequestHandler,
        geometry: inout SceneGeometry,
        isFrontCamera: Bool
    ) {
        let attentionReq = VNGenerateAttentionBasedSaliencyImageRequest()
        let objectnessReq = VNGenerateObjectnessBasedSaliencyImageRequest()
        let bodyPoseReq = VNDetectHumanBodyPoseRequest()
        
        let rectReq = VNDetectRectanglesRequest()
        rectReq.minimumAspectRatio = 0.1
        rectReq.maximumAspectRatio = 0.5
        rectReq.minimumConfidence  = 0.6
        rectReq.maximumObservations = 3
        
        try? handler.perform([attentionReq, objectnessReq, bodyPoseReq, rectReq])
        
        GeometryExtractor.extractSaliency(
            obs: attentionReq.results?.first as? VNSaliencyImageObservation,
            isFrontCamera: isFrontCamera,
            into: &geometry
        )
        
        GeometryExtractor.extractObjectness(
            obs: objectnessReq.results?.first as? VNSaliencyImageObservation,
            isFrontCamera: isFrontCamera,
            into: &geometry
        )
        
        GeometryExtractor.extractBodyPose(
            obs: bodyPoseReq.results?.first,
            isFrontCamera: isFrontCamera,
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
