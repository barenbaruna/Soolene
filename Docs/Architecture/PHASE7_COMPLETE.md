# Phase 7 — Validation & Cleanup (Complete)

**Branch:** `refactor/ui-logic-app`  
**Build:** Verified (`generic/platform=iOS`)

## CameraViewModel decomposition

| File | LOC | Responsibility |
|------|-----|----------------|
| `CameraViewModel.swift` | ~235 | State, init wiring, lifecycle, composition actions |
| `CameraViewModel+Permissions.swift` | ~43 | Privacy gates and settings |
| `CameraViewModel+Guidance.swift` | ~86 | Tips, tracking warnings, stability meter |
| `CameraViewModel+Capture.swift` | ~144 | Shutter, countdown, save pipeline |
| `CameraViewModel+Controls.swift` | ~170 | Lens, zoom, flash, exposure, camera switch |

Main type is under the 300 LOC blueprint target. ARKit import isolated to the guidance extension.

## Dead code removed

- `BoldDirectionArrow.swift` — unused overlay (direction UI lives in `CompositionDirectionOverlay`)
- `CaptureUIState.swift` — unused skeleton model

## Wiring

- `CameraView` constructs the VM via `AppDependencies.shared.makeCameraViewModel()`
- `LensType.closest(toZoom:)` moved to `LensType.swift`

## Device validation

See `PHASE7_VALIDATION.md` — on-device sign-off still required.

## Refactor summary (Phases 0–7)

| Phase | Deliverable |
|-------|-------------|
| 0 | Architecture audit |
| 1 | MVVM blueprint |
| 2 | Protocols, `AppDependencies`, domain UI state skeletons |
| 3 | Gallery VM, onboarding store, coordinator relocation |
| 4 | `CameraView` decomposition, shared composition grids |
| 5 | Composition/capture business logic in coordinators |
| 6 | `ARSessionController`, Vision pipeline split |
| 7 | VM extensions, dead-code sweep, validation checklist |
