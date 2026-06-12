# Phase 4 — UI Decomposition (Complete)

**Branch:** `refactor/ui-logic-app`  
**Build:** Verified

## Camera view decomposition

| File | Responsibility |
|------|----------------|
| `CameraView.swift` | Orchestration, permissions gate, side effects (~230 LOC) |
| `CameraPreviewLayer.swift` | Spatial / classic preview + lifecycle |
| `CameraGuidanceOverlayStack.swift` | Grids, scanning coach, dual-anchor overlay |
| `CameraInteractionOverlays.swift` | Tap indicator, lock ring, focus/exposure |

## Shared composition grids

- Moved `Features/Camera/Overlays/Grids/` → `Shared/Components/CompositionGrid/`
- Added `CompositionGridView` — used by live `CompositionOverlayView` and gallery `StaticOverlayView`
- Removed duplicate Canvas drawing in `StaticOverlayView` (~120 LOC deleted)

## Removed dead code

- `PulsingTargetRing.swift` — unreferenced
- `PinnedSubjectBadge.swift` — preview-only
- `Features/Camera/MIGRATION.md` — moved to `Docs/Architecture/CAMERA_MIGRATION.md` (avoid app bundle copy)
- Empty `Overlays/Grids/` folder

## Next: Phase 5

- Collapse `syncCompositionState()` / `CompositionUIState`
- Unify capture readiness in `CaptureCoordinator`
- Decouple `CameraView` from direct engine observation
