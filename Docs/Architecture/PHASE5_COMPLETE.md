# Phase 5 — Business Logic Cleanup (Complete)

**Branch:** `refactor/ui-logic-app`  
**Build:** Verified

## Composition state

- `CompositionCoordinator` is `@Observable` with authoritative `CompositionUIState`
- Removed `syncCompositionState()` and duplicate stored fields from `CameraViewModel`
- VM exposes computed forwards (`guidancePhase`, `compositionState`, etc.)

## Capture readiness

- `CaptureCoordinator.isCaptureReady` now requires `guidancePhase.isPerfect`
- Rear spatial also requires `trackingStabilityProgress >= 1.0`
- `shutterReadiness` centralized in `CaptureCoordinator`
- Classic front capture waits for delegate completion before save

## View / engine decoupling

- `CameraView` no longer observes `spatialEngine` / `cameraManager` for save or tracking
- Tracking warnings updated via `SpatialCameraEngine.onTrackingStateChanged`
- Photo save runs in `executeCapture` → `savePhoto()` pipeline
- `clearCapturedPhotoData()` after successful gallery save

## Next: Phase 6

- Split `VisionService` spatial vs classic pipelines
- Extract `ARSessionController` from `SpatialCameraEngine`
- Documentation and comment pass (Phase 6–7)
