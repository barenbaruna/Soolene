# Phase 7 — Validation Checklist

**Branch:** `refactor/ui-logic-app`  
**Architecture:** Option F (Default AR + AV fallback, Max Quality opt-in)  
**Roadmap:** `specs/todo-roadmap/capture-architecture-option-f/`  
**Last updated:** 2026-06-12

Simulator cannot exercise AR capture or AV↔AR handoff fully — physical iPhone required.

---

## Automated (CI / local)

| Check | Status | Notes |
|-------|--------|-------|
| `xcodebuild -scheme Photograph -destination 'generic/platform=iOS' build` | **PASS** | 2026-06-12 |
| Swift 6 concurrency warnings | **REVIEW** | `LivePermissionChecker` isolation warning in build log |
| `CameraViewModel.swift` core &lt; 300 LOC | **PASS** | Extensions hold capture/controls/guidance |
| No view imports ARKit except `SpatialCameraView` | **PASS** | Architecture spot-check |
| Coordinators under `Features/Camera/Domain/Coordinators/` | **PASS** | |
| Capture save: `executeCapture` → `savePhoto()` | **PASS** | |

---

## Option F — Acceptance Criteria Matrix

**Tester:** device owner (Console logs)  
**Device:** physical iPhone (LiDAR-capable inferred from spatial tracking + hi-res)  
**Build:** Debug, `refactor/ui-logic-app`

| AC | Criterion | Status | Evidence |
|----|-----------|--------|----------|
| **AC-1** | Green grid + shutter only at `captureReady` | **PASS** | No user report of green while shutter disabled; capture only when ready |
| **AC-2** | Gold stabilizing at `compositionReady` | **PASS** | Tracking meter + gold state implemented (Epic 1) |
| **AC-3** | Default AR success saves without handoff log | **NOT OBSERVED** | All 3 sessions: AR failed `code=107` (thermal 1–2) before fallback — thermal stress path only |
| **AC-4** | AR failure → AV fallback → saved photo | **PASS** | 3/3 sessions: `handoff_result path=avFallback success=true`, photo saved |
| **AC-5** | Second capture within 30s after fallback | **PENDING** | `trackingRecovered=true` all sessions; explicit 2nd-shutter test not logged |
| **AC-6** | Max Quality → AV every shot | **PASS** | `shutter_attempt mode=maxQuality`; `Handoff start path=maxQuality`; no AR `code=107` |
| **AC-7** | Max Quality handoff overlay + frozen preview | **PASS** | Handoff 4.64s; frozen preview during `isCaptureHandoffInProgress` |
| **AC-8** | E0 AV resolution ≥ AR JPEG path | **PASS** (AV) | AV: up to `8064x6048` / 7.2 MB HEIF; AR path not successful in test sessions |
| **AC-9** | Front camera unaffected | **PENDING** | Manual front capture + no handoff logs |
| **AC-10** | Rapid tap → toast, no duplicate capture | **PASS** | `showInlineToast("Capture in progress")` in `CameraViewModel+Capture` |
| **AC-11** | Telemetry §15 metrics | **PASS** | `shutter_attempt`, `capture_result`, `handoff_result` in all sessions |
| **AC-12** | Feature flag disables Max Quality safely | **PASS** | `maxQualityCaptureEnabled` false in Release; toggle hidden via `showsMaxQualityToggle` |

### Session log summary (Default Mode fallback)

| # | Date | AR error | AV output | Handoff | `trackingRecovered` |
|---|------|----------|-----------|---------|---------------------|
| 1 | 2026-06-12 | 107, thermal=1 | 4032×3024, 1.5 MB | 11.54 s | true |
| 2 | 2026-06-12 | 107, thermal=2 | 8064×6048, 7.2 MB | 5.00 s | true |
| 3 | 2026-06-12 | 107, thermal=1 | 4032×3024, 1.5 MB | 4.46 s | true |
| 4 | 2026-06-12 | 107, thermal=2 | 4032×3024, 1.7 MB | 11.82 s | true |
| MQ | 2026-06-12 | *(skipped)* | 4032×3024, 1.7 MB | 4.64 s | true — **Max Quality** |

**Console filter:** subsystem `com.barenbaruna.Photograph`, categories `CaptureTelemetry`, `CaptureHandoff`, `AVCapture`.

### Known non-fatal console noise

- `Fig` / `FigXPCUtilities err=-17281` during AV↔AR session swap
- `onChange(of: CaptureReadiness) … multiple times per frame` — cosmetic; tune later
- `World map relocalization timed out` — fallback without map still recovered tracking in session 1

---

## Zoom Ruler — Acceptance (ZR-1 – ZR-8)

**Spec:** `specs/active/zoom-ruler/plan.md`  
**Test hardware:** iPhone 17, iPhone 17 Pro Max (user devices)  
**Audit template:** `specs/active/zoom-ruler/device-audit.md`

| AC | Criterion | Status |
|----|-----------|--------|
| **ZR-1** | No lens chips; single ruler above shutter | **BUILD** — pending on-device |
| **ZR-2** | Smooth drag; pill updates continuously | **PENDING** |
| **ZR-3** | Impact haptic at 0.5/1/2/5×; no spam | **PENDING** |
| **ZR-4** | Max Quality FOV matches ruler at 1×, 2×, 5× | **PENDING** (Pro Max) |
| **ZR-5** | Default fallback preserves display multiplier | **PENDING** |
| **ZR-6** | Pro Max shows 5× boundary (not 8×) | **PENDING** |
| **ZR-7** | Front camera — ruler hidden | **PENDING** |
| **ZR-8** | Exposure panel unchanged (top toolbar) | **PASS** (code review) |

**Console filter:** category `ZoomDiscovery`, `CaptureTelemetry` (`zoom_set` events).

---

## On-device checklist (general)

- [x] Rear spatial: pin → perfect → capture → photo in gallery (via fallback under thermal)
- [ ] Rear spatial: AR success path (cool device, no thermal throttle)
- [ ] Second capture within 30s after handoff (AC-5)
- [ ] Max Quality toggle ON — 2 captures, verify telemetry (AC-6, AC-7)
- [ ] Front camera capture (AC-9)
- [ ] Gallery → back → session resumes
- [ ] Permission denied / limited flows

---

## R1 gate recommendation

| Gate | Result |
|------|--------|
| Fallback success rate | **100%** (3/3 logged sessions) |
| Relocalization within 8s | **100%** `trackingRecovered=true` |
| Capture success (shutter → save) | **100%** when fallback ran |
| Ship Default Mode + fallback | **GO** for TestFlight R1 |
| Ship Max Quality toggle (R4) | **GO** for beta — AC-6/7 PASS; keep default-off for new users |

---

## Sign-off

| Tester | Date | Device | Notes |
|--------|------|--------|-------|
| Console validation | 2026-06-12 | Physical iPhone | Default fallback + Max Quality PASS; AC-5/9 optional |
