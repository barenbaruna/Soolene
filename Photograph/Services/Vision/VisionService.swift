//
//  VisionService.swift
//  Photograph
//
//  Runs Vision analysis on live camera frames with tiered throttling.
//
//  This service acts purely as a coordinator.
//  - VisionRequestManager handles the VNRequests
//  - GeometryExtractor parses the results
//  - AlignmentAnalyzer computes the math
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import AVFoundation
import CoreGraphics
import CoreML
import Vision

final class VisionService: @unchecked Sendable {
    
    // MARK: - Callback
    
    /// Called on the main queue whenever a new analysis result is ready.
    var onAnalysisUpdated: ((CompositionAnalysis) -> Void)?
    
    // MARK: - Throttling
    
    private var frameCounter = 0
    private var isAnalyzing = false
    
    // MARK: - CoreML Model
    
    private var compositionModel: VNCoreMLModel? = {
        guard let url = Bundle.main.url(forResource: "FiveCompositionDetector", withExtension: "mlmodelc")
                     ?? Bundle.main.url(forResource: "FiveCompositionDetector", withExtension: "mlpackage")
        else { return nil }
        guard let model = try? MLModel(contentsOf: url),
              let visionModel = try? VNCoreMLModel(for: model)
        else { return nil }
        return visionModel
    }()
    
    // MARK: - Accumulated State
    
    private var currentAnalysis = CompositionAnalysis()
    private var wasCompositionPerfect = false
    
    // MARK: - Main Entry Point
    
    func processFrame(_ sampleBuffer: CMSampleBuffer) {
        guard !isAnalyzing else { return }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        frameCounter += 1
        isAnalyzing = true
        
        let counter = frameCounter
        let snapshot = currentAnalysis
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            
            var updated = snapshot
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
            
            // ── Fast tier (every frame): horizon + face ───────────────────
            VisionRequestManager.runFastRequests(handler: handler, geometry: &updated.sceneGeometry)
            
            // ── Medium tier (every 8 frames): saliency + rectangles ───────
            if counter % 8 == 0 {
                VisionRequestManager.runMediumRequests(handler: handler, geometry: &updated.sceneGeometry)
            }
            
            // ── Slow tier (every 60 frames): ML classification ────────────
            if counter % 60 == 0, let model = self.compositionModel {
                VisionRequestManager.runSlowRequests(handler: handler, model: model, analysis: &updated)
            }
            
            // ── Resolve best composition from ML + geometry ───────────────
            let technique = GuidanceEngine.pickBest(
                predictions: updated.mlPredictions,
                geometry: updated.sceneGeometry
            )
            updated.activeTechnique = technique
            updated.detectedComposition = technique.composition
            
            // ── Compute subject offset (for arrow direction in UI) ─────────
            let offsetResult = AlignmentAnalyzer.computeSubjectOffset(
                for: technique.composition,
                geometry: updated.sceneGeometry
            )
            updated.subjectOffset = offsetResult.vector
            updated.isCompositionPerfect = offsetResult.isPerfect
            
            // ── Compute scene alignment score (drives Red/Green/White) ─────
            updated.sceneAlignmentScore = AlignmentAnalyzer.computeSceneAlignmentScore(
                for: technique.composition,
                geometry: updated.sceneGeometry,
                isPerfect: offsetResult.isPerfect
            )
            
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.currentAnalysis = updated
                self.onAnalysisUpdated?(updated)
                self.isAnalyzing = false
                
                // Haptic feedback when composition snaps to perfect
                if updated.isCompositionPerfect, !self.wasCompositionPerfect {
                    HapticManager.success()
                }
                self.wasCompositionPerfect = updated.isCompositionPerfect
            }
        }
    }
}
