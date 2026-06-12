//
//  ZoomRulerTickLayout.swift
//  Photograph
//
//  Device-aware tick density for the zoom ruler — scales with supported max zoom.
//

import CoreGraphics
import Foundation

/// Precomputed tick marks for the center-pinned zoom ruler.
struct ZoomRulerTickLayout: Equatable, Sendable {
    let minorStep: CGFloat
    let tickValues: [CGFloat]
    let majorBoundaries: [CGFloat]

    // MARK: - Factory

    static func make(from capabilities: ZoomDeviceCapabilities) -> ZoomRulerTickLayout {
        let span = capabilities.maxDisplayZoom - capabilities.minDisplayZoom
        let minorStep = adaptiveMinorStep(span: span)
        let majors = capabilities.rulerMajorBoundaries
        let ticks = buildTickValues(
            from: capabilities.minDisplayZoom,
            through: capabilities.maxDisplayZoom,
            step: minorStep
        )

        return ZoomRulerTickLayout(
            minorStep: minorStep,
            tickValues: ticks,
            majorBoundaries: majors
        )
    }

    func isMajor(_ tick: CGFloat) -> Bool {
        majorBoundaries.contains { abs($0 - tick) < minorStep * 0.45 }
    }

    // MARK: - Private

    /// Chooses a readable minor-step so tick count scales with device max zoom.
    private static func adaptiveMinorStep(span: CGFloat) -> CGFloat {
        let targetCount: CGFloat
        switch span {
        case ...5:  targetCount = 44
        case ...12: targetCount = 38
        case ...20: targetCount = 34
        default:     targetCount = 30
        }

        let ideal = span / targetCount
        let candidates: [CGFloat] = [0.1, 0.2, 0.25, 0.5, 1.0, 2.0, 5.0]
        return candidates.min { abs($0 - ideal) < abs($1 - ideal) } ?? 0.5
    }

    private static func buildTickValues(
        from lower: CGFloat,
        through upper: CGFloat,
        step: CGFloat
    ) -> [CGFloat] {
        var values: [CGFloat] = []
        var tick = lower
        while tick <= upper + step * 0.01 {
            values.append((tick * 100).rounded() / 100)
            tick += step
        }
        return values
    }
}

extension ZoomDeviceCapabilities {

    /// Major tick marks including optical boundaries and device max zoom.
    var rulerMajorBoundaries: [CGFloat] {
        var boundaries = majorBoundaries
        let maxRounded = (maxDisplayZoom * 10).rounded() / 10

        if maxRounded >= 5,
           !boundaries.contains(where: { abs($0 - maxRounded) < 0.15 }) {
            boundaries.append(maxRounded)
        }

        return Array(Set(boundaries)).sorted()
    }
}
