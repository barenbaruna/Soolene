import SwiftUI

/// Mocked CameraViewModel for UI Development.
/// All AVFoundation, Vision, and CoreML logic has been removed to isolate the Coded UI.
@Observable
@MainActor
final class CameraViewModel {
    
    // MARK: - UI State (Mocked)
    
    var isFlashActive: Bool = false
    var selectedLens: String = "1x"
    var isFrontCamera: Bool = false
    
    var timerLength: Int = 0
    var isCountingDown: Bool = false
    var countdownValue: Int = 0
    
    var showShutterFlash: Bool = false
    
    // Mocked from previous AVFoundation/Vision
    var lastSavedThumbnail: UIImage? = nil
    var activeTechnique: CompositionType? = nil
    var isSubjectPinned: Bool = false
    
    // Dummy analysis state for UI testing
    var compositionLabel: String = "Rule of Thirds"
    var isSceneAligned: Bool = false // Toggle this to see Red/Green gridlines
    
    // MARK: - Actions (Mocked)
    
    func onAppear() {
        // Mock startup
    }
    
    func onDisappear() {
        // Mock teardown
    }
    
    func switchCamera() {
        isFrontCamera.toggle()
    }
    
    func switchLens(_ lens: String) {
        selectedLens = lens
    }
    
    func cycleFlash() {
        isFlashActive.toggle()
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
    
    func cancelCountdown() {
        isCountingDown = false
        countdownValue = 0
    }
}
