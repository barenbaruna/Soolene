import SwiftUI

/// Standardized typography matching the Design System spec.
///
/// Font Family: SF Pro Text
/// Following iOS 26 HIG: Uses semantic styles for Dynamic Type support.
///
/// Design System tokens:
///   Large Title (SF Pro Text, Bold, 34)
///   Title (SF Pro Text, Semibold, 28)
///   Headline (SF Pro Text, Semibold, 17)
///   Body (SF Pro Text, Regular, 17)
///   Subheadline (SF Pro Text, Regular, 15)
///   Caption (SF Pro Text, Regular, 12)
struct Typography {
    
    /// Large Title / Bold / 34
    static var largeTitle: Font {
        .largeTitle.weight(.bold)
    }

    /// Title / Semibold / 28
    static var title: Font {
        .title.weight(.semibold)
    }

    /// Headline / Semibold / 17
    static var headline: Font {
        .headline
    }

    /// Body / Regular / 17
    static var body: Font {
        .body
    }

    /// Subheadline / Regular / 15
    static var subheadline: Font {
        .subheadline
    }

    /// Caption / Regular / 12
    static var caption: Font {
        .caption
    }

    /// Button/CTA / Semibold / 17
    static var buttonCTA: Font {
        .headline
    }
}

extension View {
    func textStyle(_ font: Font, color: Color = .primary) -> some View {
        self.font(font)
            .foregroundStyle(color)
    }
}
