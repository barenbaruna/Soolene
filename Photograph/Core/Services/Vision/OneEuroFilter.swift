//
//  OneEuroFilter.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 06/06/26.
//

import CoreGraphics
import Foundation

final class OneEuroFilter {
    private var lastValue: Double = 0
    
    func filter(_ value: Double, alpha: Double) -> Double {
        let result = alpha * value + (1.0 - alpha) * lastValue
        lastValue = result
        return result
    }
}

/// A 1-Euro filter for 2D points (CGPoint).
/// Filters high-frequency noise at low speeds while maintaining responsiveness at high speeds.
final class OneEuroPointFilter {
    private let minCutoff: Double
    private let beta: Double
    private let dCutoff: Double
    
    private let xFilter = OneEuroFilter()
    private let yFilter = OneEuroFilter()
    private let dxFilter = OneEuroFilter()
    private let dyFilter = OneEuroFilter()
    
    private var lastTimestamp: Double?
    private var lastRawPoint: CGPoint?
    
    init(minCutoff: Double = 0.8, beta: Double = 0.005, dCutoff: Double = 1.0) {
        self.minCutoff = minCutoff
        self.beta = beta
        self.dCutoff = dCutoff
    }
    
    private func smoothingFactor(cutoff: Double, dt: Double) -> Double {
        let tau = 1.0 / (2.0 * .pi * cutoff)
        return dt / (dt + tau)
    }
    
    func filter(_ point: CGPoint) -> CGPoint {
        let now = CFAbsoluteTimeGetCurrent()
        
        guard let prevTime = lastTimestamp, let prevPoint = lastRawPoint else {
            lastTimestamp = now
            lastRawPoint = point
            _ = xFilter.filter(Double(point.x), alpha: 1.0)
            _ = yFilter.filter(Double(point.y), alpha: 1.0)
            return point
        }
        
        let dt = max(now - prevTime, 1.0 / 120.0)
        
        let rawDx = (Double(point.x) - Double(prevPoint.x)) / dt
        let rawDy = (Double(point.y) - Double(prevPoint.y)) / dt
        
        let derivAlpha = smoothingFactor(cutoff: dCutoff, dt: dt)
        let filteredDx = dxFilter.filter(rawDx, alpha: derivAlpha)
        let filteredDy = dyFilter.filter(rawDy, alpha: derivAlpha)
        
        let speed = hypot(filteredDx, filteredDy)
        let cutoff = minCutoff + beta * speed
        
        let alpha = smoothingFactor(cutoff: cutoff, dt: dt)
        let filteredX = xFilter.filter(Double(point.x), alpha: alpha)
        let filteredY = yFilter.filter(Double(point.y), alpha: alpha)
        
        lastTimestamp = now
        lastRawPoint = point // Store RAW point, NOT filtered point (prevent feedback loop!)
        
        return CGPoint(x: filteredX, y: filteredY)
    }
    
    func reset() {
        lastTimestamp = nil
        lastRawPoint = nil
    }
}
