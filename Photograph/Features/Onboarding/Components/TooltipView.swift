//
//  TooltipView.swift
//  Photograph
//
//  Reusable walkthrough tooltip using native `.ultraThinMaterial`.
//  Matches Hi-Fi: dark glass card with title, description, "Got it" + "Skip" actions.
//
//  Uses Design System tokens: Typography, Spacing, AppColors.
//
//  Created by Baren Baruna Harahap on 06/06/26.
//

import SwiftUI

// MARK: - Tooltip Anchor

/// Where the caret arrow points relative to the card.
enum TooltipAnchor {
    case top       // Caret on top → card appears BELOW the target
    case bottom    // Caret on bottom → card appears ABOVE the target
    case bottomLeading  // Caret on bottom-left
}

// MARK: - TooltipView

struct TooltipView: View {
    let title: String
    let description: String
    let primaryLabel: String
    let secondaryLabel: String?
    let anchor: TooltipAnchor
    let onPrimary: () -> Void
    let onSecondary: (() -> Void)?

    /// Convenience initialiser with defaults matching Hi-Fi.
    init(
        title: String,
        description: String,
        primaryLabel: String = "Got it",
        secondaryLabel: String? = "Skip",
        anchor: TooltipAnchor = .bottom,
        onPrimary: @escaping () -> Void,
        onSecondary: (() -> Void)? = nil
    ) {
        self.title = title
        self.description = description
        self.primaryLabel = primaryLabel
        self.secondaryLabel = secondaryLabel
        self.anchor = anchor
        self.onPrimary = onPrimary
        self.onSecondary = onSecondary
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Caret on top
            if anchor == .top {
                caretTriangle(pointsUp: true)
                    .padding(.leading, Spacing.medium)
            }

            // Card content
            VStack(alignment: .leading, spacing: Spacing.small) {
                Text(title)
                    .font(Typography.headline)
                    .foregroundStyle(.white)

                Text(description)
                    .font(Typography.caption)
                    .foregroundStyle(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)

                Divider()
                    .background(.white.opacity(0.2))

                // Action row
                HStack {
                    Button(action: onPrimary) {
                        Text(primaryLabel)
                            .font(Typography.headline)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    if let secondaryLabel, let onSecondary {
                        Button(action: onSecondary) {
                            Text(secondaryLabel)
                                .font(Typography.subheadline)
                                .foregroundStyle(AppColors.gridlineRed)
                        }
                    }
                }
            }
            .padding(Spacing.standard)
            .background(.black.opacity(0.7))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Spacing.cornerRadiusMedium, style: .continuous))

            // Caret on bottom
            if anchor == .bottom || anchor == .bottomLeading {
                HStack {
                    if anchor == .bottomLeading {
                        caretTriangle(pointsUp: false)
                            .padding(.leading, Spacing.medium)
                        Spacer()
                    } else {
                        Spacer()
                        caretTriangle(pointsUp: false)
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Caret Shape

    private func caretTriangle(pointsUp: Bool) -> some View {
        Triangle()
            .fill(.black.opacity(0.7))
            .frame(width: 16, height: 8)
            .rotationEffect(.degrees(pointsUp ? 0 : 180))
    }
}

// MARK: - Triangle Shape

/// Simple equilateral triangle pointing upward.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

// MARK: - Preview

#Preview("Tooltip — Bottom") {
    ZStack {
        Color.gray.ignoresSafeArea()
        TooltipView(
            title: "Composition Suggestion",
            description: "Get composition recommendations based on the scene in your camera.",
            onPrimary: {}
        )
        .frame(width: 300)
    }
}
