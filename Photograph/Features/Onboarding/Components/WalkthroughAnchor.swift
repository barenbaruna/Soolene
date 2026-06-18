//
//  WalkthroughAnchor.swift
//  Photograph
//
//  Reports UI element frames for walkthrough tooltip placement.
//

import SwiftUI

enum WalkthroughAnchorID: Hashable {
    case guidanceTip
    case shutter
    case gallery
    case gridToggle
}

struct WalkthroughAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [WalkthroughAnchorID: CGRect] = [:]

    static func reduce(
        value: inout [WalkthroughAnchorID: CGRect],
        nextValue: () -> [WalkthroughAnchorID: CGRect]
    ) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}

extension View {
    func walkthroughAnchor(_ id: WalkthroughAnchorID) -> some View {
        background {
            GeometryReader { geo in
                Color.clear.preference(
                    key: WalkthroughAnchorPreferenceKey.self,
                    value: [id: geo.frame(in: .global)]
                )
            }
        }
    }
}

enum WalkthroughTooltipLayout {
    static let estimatedCardHeight: CGFloat = 150
    static let estimatedCardWidth: CGFloat = 340

    static func position(
        for anchor: CGRect,
        style: TooltipAnchor,
        in containerGlobalFrame: CGRect
    ) -> CGPoint {
        let containerW = containerGlobalFrame.width
        let cardWidth = min(containerW * 0.82, estimatedCardWidth)
        let localAnchor = CGRect(
            x: anchor.minX - containerGlobalFrame.minX,
            y: anchor.minY - containerGlobalFrame.minY,
            width: anchor.width,
            height: anchor.height
        )

        switch style {
        case .none:
            return CGPoint(
                x: containerW * 0.50,
                y: containerGlobalFrame.height * 0.36
            )
        case .top:
            return CGPoint(
                x: localAnchor.midX,
                y: localAnchor.maxY + Spacing.small + estimatedCardHeight / 2 - Spacing.standard
            )
        case .bottom:
            return CGPoint(
                x: localAnchor.midX,
                y: localAnchor.minY - Spacing.small - estimatedCardHeight / 2 + Spacing.standard + 20
            )
        case .bottomLeading:
            // Gallery button is at the far left — position tooltip shifted right
            // so it doesn't get cropped, with caret pointing down-left to the button.
            let tooltipCenterX = max(
                cardWidth / 2 + Spacing.standard,
                min(localAnchor.midX + cardWidth / 2 - Spacing.large,
                    containerW - cardWidth / 2 - Spacing.standard)
            )
            return CGPoint(
                x: tooltipCenterX,
                y: localAnchor.minY - Spacing.small - estimatedCardHeight / 2 + Spacing.standard + 16
            )
        case .bottomTrailing:
            // Gallery button is at the far left — position tooltip so the
            // bottom-right caret points down toward the button area.
            let tooltipCenterX = max(
                cardWidth / 2 + Spacing.standard,
                min(localAnchor.midX + cardWidth / 2 - Spacing.large,
                    containerW - cardWidth / 2 - Spacing.standard)
            )
            return CGPoint(
                x: tooltipCenterX,
                y: localAnchor.minY - Spacing.small - estimatedCardHeight / 2
            )
        case .topTrailing:
            // Grid toggle is at the far right — position tooltip so it stays on-screen.
            // Anchor caret points up-right to the button.
            let tooltipCenterX = min(
                containerW - cardWidth / 2 - Spacing.small,
                max(localAnchor.midX, cardWidth / 2 + Spacing.small)
            )
            return CGPoint(
                x: tooltipCenterX,
                y: localAnchor.maxY + Spacing.small + estimatedCardHeight / 2
            )
        case .custom(let position):
            let point = position(containerW, cardWidth, localAnchor, estimatedCardWidth, estimatedCardHeight)
            
            return CGPoint(
                x: point.x,
                y: point.y
            )
        }
    }
}
