# Phase 7 — Validation Checklist

**Branch:** `refactor/ui-logic-app`  
**Device testing required** — simulator cannot exercise AR capture fully.

## Automated

- [x] `xcodebuild -scheme Photograph -destination 'generic/platform=iOS' build` succeeds
- [ ] No new Swift 6 concurrency warnings (review build log on CI or local full build)
- [x] `CameraViewModel.swift` core file under 300 LOC (~235; extensions hold capture/controls/guidance)
- [x] No view imports ARKit except `SpatialCameraView` wrapper

## On-device (iPhone with LiDAR recommended)

- [ ] Rear spatial: scan → pin subject → reach perfect → capture → photo in gallery
- [ ] Second capture after AR tracking recovery (B2 handoff if triggered)
- [ ] Front camera capture (if enabled on branch)
- [ ] Gallery → photo detail → back → camera session resumes
- [ ] Onboarding walkthrough completes; does not re-show after finish
- [ ] Permission denied / limited flows show correct gate UI

## Architecture spot-check

- [x] Coordinators live under `Features/Camera/Domain/Coordinators/`
- [x] No duplicate `Coordinators/` legacy folder
- [x] `VisionService` split into processor + spatial/classic pipelines
- [x] `ARSessionController` owns session run/pause lifecycle
- [x] `CompositionUIState` is single source for guidance UI state
- [x] Capture save flows through `CameraViewModel.executeCapture` → `savePhoto()`

## Sign-off

| Tester | Date | Device | Notes |
|--------|------|--------|-------|
| | | | |
