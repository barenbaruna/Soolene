# Subject Lock Verification Matrix

Manual QA checklist for spatial (rear ARKit) subject lock accuracy after the trust fix.

| # | Scenario | Tap target | Pass criteria |
|---|----------|------------|---------------|
| 1 | Portrait head lock | Person's head | Bracket appears on head within ~3% of frame; lock ring and bracket align |
| 2 | Portrait torso lock | Chest | Bracket stays on chest, not face |
| 3 | Subject movement | Locked head, subject sways | Bracket follows head; offset preserved relative to body |
| 4 | Table object | Small object on table | Depth-first anchor lands on object, not floor plane |
| 5 | Low-texture fallback | Plain wall | "Subject lock is approximate" warning; bracket stable vs tap |
| 6 | Composition thirds | Lock head, select Thirds | Target socket frozen from lock origin, not drifted center |
| 7 | Re-lock | Double-tap clear, lock again | Prior offset cleared; new tap honored |
| 8 | Guidance arrow | Thirds / Diagonal, far from target | Arrow sits toward target circle; reads as move bracket toward circle |

## Automated tests

Run **PhotographTests** target:

- `SubjectLockAccuracyTests` — tap-offset math and `resolveSubjectPoint` priority
- `CoordinateMapperTests` — view/image coordinate mapping

## Expected architecture

- `userLockOrigin` — immutable user long-press (never overwritten by tracking)
- `trackedSubjectPoint` — live AR projection + frozen tap offset
- `lockedTargetPoint` — composition target socket (separate from subject)
