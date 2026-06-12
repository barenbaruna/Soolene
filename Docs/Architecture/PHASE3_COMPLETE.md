# Phase 3 — Feature Migration (Complete)

**Branch:** `refactor/ui-logic-app`  
**Build:** Verified `xcodebuild` succeeds

## Commits

| Commit | Scope |
|--------|-------|
| `35780b6` | Gallery: `GalleryViewModel`, `CompositionPhotoListViewModel`, repository wiring |
| `8d3a79b` | Onboarding: `OnboardingStore` (`@Observable`), environment injection |
| `03f8379` | Camera: coordinators moved to `Domain/Coordinators/` |

## Gallery

- `Presentation/ViewModels/GalleryViewModel.swift` — permissions + library load
- `Presentation/ViewModels/CompositionPhotoListViewModel.swift` — per-composition grid
- Views delegate to ViewModels; `GalleryRepository` replaces direct `GalleryManager` calls
- `AppDependencies.makeGalleryViewModel()` wires shared repository

## Onboarding

- `Domain/OnboardingStore.swift` replaces `OnboardingManager`
- `ContentView` uses `@State` + `.environment(OnboardingStore.self)`
- `SplashView`, `CameraView`, `WalkthroughOverlayView` use `@Environment(OnboardingStore.self)`

## Camera

- Coordinators only in `Features/Camera/Domain/Coordinators/`
- Legacy `Coordinators/` folder removed (duplicate symbols)

## Next: Phase 4

- Decompose `CameraView` (549 LOC)
- Shared `CompositionGridView` for camera + gallery overlays
- Move Gallery/Onboarding views under `Presentation/`
