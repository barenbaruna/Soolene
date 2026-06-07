//
//  SaliencySmoother.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 06/06/26.
//

import CoreGraphics

/// A lightweight temporal smoother using Exponential Moving Average.
final class SaliencySmoother: @unchecked Sendable {
    
    private var smoothedPoint: CGPoint?
    
    /// The smoothing factor (0.0 to 1.0).
    /// Higher = more responsive but more jitter.
    /// Lower = very stable but introduces lag.
    /// 0.35 is an empirical sweet spot for 30fps AR tracking.
    private let alpha: CGFloat = 0.35
    
    func smooth(_ newPoint: CGPoint?) -> CGPoint? {
        guard let new = newPoint else {
            reset()
            return nil
        }
        
        guard let current = smoothedPoint else {
            smoothedPoint = new
            return new
        }
        
        let smoothedX = (alpha * new.x) + ((1.0 - alpha) * current.x)
        let smoothedY = (alpha * new.y) + ((1.0 - alpha) * current.y)
        
        let result = CGPoint(x: smoothedX, y: smoothedY)
        smoothedPoint = result
        return result
    }
    
    func reset() {
        smoothedPoint = nil
    }
}
