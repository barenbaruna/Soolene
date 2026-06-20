//
//  Comparable+Clamping.swift
//  Soolene
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import Foundation

extension Comparable {
    /// Clamps the value to the specified range.
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
