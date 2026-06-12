# Camera Feature — Architecture Migration

**Branch:** `refactor/ui-logic-app`

| Path | Status |
|------|--------|
| `Views/` | Phase 4 — decomposed into `CameraPreviewLayer`, `CameraGuidanceOverlayStack`, `CameraInteractionOverlays` |
| `ViewModels/`, `Components/`, `Overlays/` | Active — move to `Presentation/` in a later pass |
| `Domain/Coordinators/` | Done (Phase 3) |
| `Shared/Components/CompositionGrid/` | Done (Phase 4) — shared with gallery |

## Remaining

1. Move views under `Presentation/`
2. `CompositionUIState` collapse (Phase 5)
3. Service splits (Phase 6)
