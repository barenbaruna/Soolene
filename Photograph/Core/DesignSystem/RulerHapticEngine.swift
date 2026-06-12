//
//  RulerHapticEngine.swift
//  Photograph
//
//  Reusable tiered haptics for continuous ruler controls (zoom + exposure).
//

import CoreGraphics
import UIKit

@MainActor
final class RulerHapticEngine {
    private let impact = UIImpactFeedbackGenerator(style: .rigid)
    private let selection = UISelectionFeedbackGenerator()

    private var lastMajorBoundary: CGFloat?
    private var lastMinorTick: CGFloat?
    private var lastBoundaryFireTime: CFAbsoluteTime = 0

    private let minorDeltaThreshold: CGFloat = 0.08
    private let boundaryCooldown: CFAbsoluteTime = 0.05

    func prepareForDrag() {
        impact.prepare()
        selection.prepare()
    }

    func resetDragState() {
        lastMajorBoundary = nil
        lastMinorTick = nil
    }

    /// Fires impact at major boundaries and subtle selection at minor steps while dragging.
    func handleValueChange(
        from oldValue: CGFloat,
        to newValue: CGFloat,
        majorBoundaries: [CGFloat],
        minorStep: CGFloat
    ) {
        let crossedMajors = boundariesCrossed(from: oldValue, to: newValue, in: majorBoundaries)
        let now = CFAbsoluteTimeGetCurrent()

        for boundary in crossedMajors {
            if boundary == lastMajorBoundary { continue }
            if now - lastBoundaryFireTime < boundaryCooldown { continue }
            impact.impactOccurred(intensity: 1.0)
            lastMajorBoundary = boundary
            lastBoundaryFireTime = now
            lastMinorTick = nil
        }

        let minorTicks = minorTicksCrossed(
            from: oldValue,
            to: newValue,
            majors: majorBoundaries,
            step: minorStep
        )
        for tick in minorTicks {
            if let last = lastMinorTick, abs(tick - last) < minorDeltaThreshold { continue }
            if majorBoundaries.contains(where: { abs($0 - tick) < minorStep * 0.45 }) { continue }
            selection.selectionChanged()
            lastMinorTick = tick
        }
    }

    func boundariesCrossed(
        from old: CGFloat,
        to new: CGFloat,
        in ticks: [CGFloat]
    ) -> [CGFloat] {
        let lo = min(old, new)
        let hi = max(old, new)
        return ticks.filter { tick in
            tick > lo - 0.001 && tick < hi + 0.001 && abs(tick - old) > 0.001
        }
    }

    private func minorTicksCrossed(
        from old: CGFloat,
        to new: CGFloat,
        majors: [CGFloat],
        step: CGFloat
    ) -> [CGFloat] {
        let lo = min(old, new)
        let hi = max(old, new)
        let start = floor(lo / step) * step
        var ticks: [CGFloat] = []
        var tick = start
        while tick <= hi + 0.001 {
            if tick >= lo - 0.001 {
                let isMajor = majors.contains { abs($0 - tick) < step * 0.45 }
                if !isMajor {
                    ticks.append(tick)
                }
            }
            tick += step
        }
        return ticks
    }
}
