//
//  ExposureRulerLayout.swift
//  Photograph
//
//  Tick boundaries and step size for the EV ruler.
//

import CoreGraphics

enum ExposureRulerLayout {
    static let range: ClosedRange<CGFloat> = -2...2
    static let majorBoundaries: [CGFloat] = [-2, -1, 0, 1, 2]
    static let minorStep: CGFloat = 0.25
}
