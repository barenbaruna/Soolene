# Phase 6 — Service Extraction (Complete)

**Branch:** `refactor/ui-logic-app`  
**Build:** Verified (`generic/platform=iOS`)

## Vision pipeline split

| File | Role |
|------|------|
| `VisionService.swift` (~325 LOC) | Orchestration, pinning, capture gating, callbacks |
| `VisionAnalysisProcessor.swift` | Shared `buildFinalAnalysis`, ML hysteresis, smoothing filters |
| `SpatialVisionPipeline.swift` | ARKit frame request scheduling + projection-only path |
| `ClassicVisionPipeline.swift` | AVFoundation tracking + frame request scheduling |

`VisionService` no longer embeds duplicated finalization or per-pipeline request blocks.

## AR session extraction

| File | Role |
|------|------|
| `ARSessionController.swift` | World configuration, run/pause, continuous autofocus |
| `SpatialCameraEngine.swift` | Tracking, capture, delegate — delegates session lifecycle |

`configureAndRun`, `startSession`, `stopSession`, and `resumeSessionPreservingAnchors` route through `ARSessionController`.

## Next: Phase 7

- Validation checklist (capture, gallery, onboarding on device)
- Final dead-code sweep
- Comment consistency pass on touched coordinators
