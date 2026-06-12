//
//  CaptureErrorToast.swift
//  Visula
//
//  Inline capture / save feedback above the shutter band.
//

import SwiftUI

struct CaptureErrorToast: View {
    let message: String

    var body: some View {
        HStack(spacing: Spacing.small) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppColors.gridlineRed)
                .accessibilityHidden(true)

            Text(message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textOnCamera)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, Spacing.standard)
        .padding(.vertical, Spacing.small)
        .background { toastBackground }
        .accessibilityLabel("Error: \(message)")
    }

    @ViewBuilder
    private var toastBackground: some View {
        if #available(iOS 26, *) {
            Capsule()
                .fill(Color.black.opacity(0.55))
                .glassEffect(.regular, in: .capsule)
        } else {
            Capsule().fill(.ultraThinMaterial)
        }
    }
}
