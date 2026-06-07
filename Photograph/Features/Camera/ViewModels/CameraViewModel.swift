import AVFoundation
import SwiftUI

/// Mocked CameraViewModel for UI Development.
/// All AVFoundation, Vision, and CoreML logic has been removed to isolate the Coded UI.
@Observable
@MainActor
final class CameraViewModel {
    var cameraManager = CameraManager()
    
    // UI State (Mapped to CameraManager)
    var isFlashActive: Bool {
        get { cameraManager.flashMode != .off }
        set { cameraManager.cycleFlash() }
    }
    var exposureBias: Float {
        get { cameraManager.exposureBias }
        set { cameraManager.setExposureBias(newValue) }
    }
    var selectedLens: String {
        get { cameraManager.selectedLens.rawValue }
        set { if let l = LensType(rawValue: newValue) { cameraManager.switchLens(l) } }
    }
    var isFrontCamera: Bool {
        get { cameraManager.isUsingFrontCamera }
        set { cameraManager.switchCamera() }
    }
    
    var selectedAspectRatio: AspectRatioMode = .free
    
    var timerLength: Int = 0
    var isCountingDown: Bool = false
    var countdownValue: Int = 0
    
    var showShutterFlash: Bool = false
    
    // Mocked Capture Data
    var saveError: String? = nil
    var capturedPhotoData: Data? = nil
    
    // Mocked from previous AVFoundation/Vision
    var lastSavedThumbnail: UIImage? = nil
    var activeTechnique: CompositionType? = nil
    var isSubjectPinned: Bool = false
    var analysis = CompositionAnalysis()
    var resolvedComposition: CompositionType { .ruleOfThirds }
    
    // Dummy analysis state for UI testing
    var compositionLabel: String = "Rule of Thirds"
    var isSceneAligned: Bool = false // Toggle this to see Red/Green gridlines
    
    func onAppear() async {
        await cameraManager.checkPermissionsAndSetup()
    }
    func onDisappear() {
        cameraManager.stopSession()
    }
    func pauseSession() {
        cameraManager.stopSession()
    }
    func resumeSession() {
        Task { await cameraManager.checkPermissionsAndSetup() }
    }
    
    func switchCamera() {
        cameraManager.switchCamera()
    }
    
    func switchLens(_ lensStr: String) {
        if let lens = LensType(rawValue: lensStr) {
            cameraManager.switchLens(lens)
        }
    }
    
    func cycleFlash() {
        cameraManager.cycleFlash()
    }
    
    func cycleExposure() {
        let bias = exposureBias
        if bias == 0 { exposureBias = 1.0 }
        else if bias == 1.0 { exposureBias = 2.0 }
        else if bias == 2.0 { exposureBias = -2.0 }
        else if bias == -2.0 { exposureBias = -1.0 }
        else { exposureBias = 0.0 }
    }
    
    func cycleTimer() {
        switch timerLength {
        case 0: timerLength = 3
        case 3: timerLength = 10
        case 10: timerLength = 0
        default: timerLength = 0
        }
    }
    
    func capturePhoto() {
        showShutterFlash = true
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            showShutterFlash = false
        }
        
        cameraManager.capturedImage = nil
        cameraManager.capturedPhotoData = nil
        cameraManager.capturePhoto(aspectRatio: selectedAspectRatio)
    }
    
    func savePhoto() async {
        // Mock save
    }
    
    func pinSubject(at point: CGPoint) {
        isSubjectPinned = true
    }
    
    func clearPinnedSubject() {
        isSubjectPinned = false
    }
    
    func cancelCountdown() {
        isCountingDown = false
        countdownValue = 0
    }
}
