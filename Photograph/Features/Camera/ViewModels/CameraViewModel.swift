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
    var capturedPhotoData: Data? {
        cameraManager.capturedPhotoData
    }
    
    // Thumbnail for Gallery Button
    var lastSavedThumbnail: UIImage? = nil
    

    
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
        guard let data = cameraManager.capturedPhotoData else { return }
        do {
            try await GalleryManager.shared.savePhoto(data, composition: .ruleOfThirds)
            // Update the gallery thumbnail
            if let image = UIImage(data: data) {
                lastSavedThumbnail = image
            }
            cameraManager.capturedPhotoData = nil
        } catch {
            self.saveError = error.localizedDescription
        }
    }
    

    
    func cancelCountdown() {
        isCountingDown = false
        countdownValue = 0
    }
}
