//
//  TooltipView.swift
//  Photograph
//
//  Reusable walkthrough tooltip using native `.ultraThinMaterial`.
//  Matches Hi-Fi: dark glass card with title, description, and optional action.
//
//  Uses Design System tokens: Typography, Spacing, AppColors.
//
//  Created by Baren Baruna Harahap on 06/06/26.
//

import SwiftUI

// MARK: - Tooltip Anchor

/// Where the caret arrow points relative to the card.
enum TooltipAnchor {
    case none
    case top // Caret on top → card appears BELOW the target
    case topTrailing // Caret on top-right
    case bottom // Caret on bottom → card appears ABOVE the target
    case bottomLeading // Caret on bottom-left
    case bottomTrailing // Caret on bottom-right
    case custom(
        position: (CGFloat, CGFloat, CGRect, CGFloat, CGFloat) -> CGPoint
    ) // custom position
}

// MARK: - TooltipView

struct TooltipView: View {
    let title: String
    let description: String
    let primaryLabel: String?
    let secondaryLabel: String?
    let anchor: TooltipAnchor
    let onPrimary: (() -> Void)?
    let onSecondary: (() -> Void)?

    /// Convenience initialiser with defaults matching Hi-Fi.
    init(
        title: String,
        description: String,
        primaryLabel: String? = "Got it",
        secondaryLabel: String? = nil,
        anchor: TooltipAnchor = .bottom,
        onPrimary: (() -> Void)? = nil,
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
            topCaret

            VStack(alignment: .leading, spacing: Spacing.small) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.neutralText.opacity(0.87))

                Text(description)
                    .font(.caption)
                    .foregroundStyle(AppColors.surfaceTextGuide.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)

                if showsActions {
                    Divider()
                        .background(.white.opacity(0.2))

                    actionRow
                }
            }
            .padding(Spacing.standard)
            .background(.black.opacity(0.58))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.medium, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: 14, y: 8)

            bottomCaret
        }
        .accessibilityElement(children: .contain)
        .allowsHitTesting(showsActions)
    }

    private var showsActions: Bool {
        (primaryLabel != nil && onPrimary != nil)
            || (secondaryLabel != nil && onSecondary != nil)
    }

    private var actionRow: some View {
        HStack {
            if let primaryLabel, let onPrimary {
                Button(action: onPrimary) {
                    Text(primaryLabel)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }

            Spacer()

            if let secondaryLabel, let onSecondary {
                Button(action: onSecondary) {
                    Text(secondaryLabel)
                        .font(.subheadline.weight(.regular))
                        .foregroundStyle(AppColors.gridlineRed)
                }
            }
        }
    }

    @ViewBuilder
    private var topCaret: some View {
        switch anchor {
        case .top:
            HStack {
                Spacer()
                caretTriangle(pointsUp: true)
                Spacer()
            }
        case .topTrailing:
            HStack {
                Spacer()
                caretTriangle(pointsUp: true)
                    .padding(.trailing, Spacing.medium)
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var bottomCaret: some View {
        switch anchor {
        case .bottom:
            HStack {
                Spacer()
                caretTriangle(pointsUp: false)
                Spacer()
            }
        case .bottomLeading:
            HStack {
                caretTriangle(pointsUp: false)
                    .padding(.leading, Spacing.medium)
                Spacer()
            }
        case .bottomTrailing:
            HStack {
                Spacer()
                caretTriangle(pointsUp: false)
                    .padding(.trailing, Spacing.medium)
            }
        default:
            EmptyView()
        }
    }

    private func caretTriangle(pointsUp: Bool) -> some View {
        Triangle()
            .fill(.black.opacity(0.58))
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
