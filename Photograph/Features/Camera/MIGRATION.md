# Camera Feature — Architecture Migration

**Branch:** `refactor/ui-logic-app`  
**Target:** `Presentation/` · `Domain/` · `Data/`

## Current layout (legacy paths)

| Path | Status |
|------|--------|
| `Views/`, `ViewModels/`, `Components/`, `Overlays/` | Active — move to `Presentation/` in Phase 3–4 |
| `Domain/Coordinators/` | **Done** — migrated from `Coordinators/` (Phase 3) |
| `Domain/Models/` | Skeleton — `CompositionUIState`, `CaptureUIState` |
| `Data/Adapters/` | Skeleton — protocol conformances |

## Migration order

1. Wire `AppDependencies` (optional; VM still uses direct `init()` until Phase 5).
2. ~~Move coordinators to `Domain/Coordinators/`.~~ Done (Phase 3).
3. Replace duplicated VM composition fields with `CompositionUIState` (Phase 5).
4. Decompose `CameraView` into layer subviews.
5. Split `SpatialCameraEngine` / `VisionService` behind protocols.

Do not delete legacy paths until imports are updated in the same commit.
