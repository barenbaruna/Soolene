import SwiftUI

/// Mocked CameraViewModel for UI Development.
/// All AVFoundation, Vision, and CoreML logic has been removed to isolate the Coded UI.
@Observable
@MainActor
final class CameraViewModel {
    var isFlashActive: Bool = false
    var exposureBias: Float = 0.0
    var selectedLens: String = "1x"
    var isFrontCamera: Bool = false
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
    
    // MARK: - Actions (Mocked)
    
    func onAppear() {}
    func onDisappear() {}
    func pauseSession() {}
    func resumeSession() {}
    
    func switchCamera() {
        isFrontCamera.toggle()
    }
    
    func switchLens(_ lens: String) {
        selectedLens = lens
    }
    
    func cycleFlash() {
        isFlashActive.toggle()
    }
    
    func cycleExposure() {
        if exposureBias == 0 { exposureBias = 1.0 }
        else if exposureBias == 1.0 { exposureBias = 2.0 }
        else if exposureBias == 2.0 { exposureBias = -2.0 }
        else if exposureBias == -2.0 { exposureBias = -1.0 }
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
        // Mock capture sequence
        showShutterFlash = true
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            showShutterFlash = false
        }
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
