import SwiftUI

struct ExposureControl: View {
    @Binding var value: Float
    let onReset: () -> Void

    var body: some View {
        HStack(spacing: Spacing.medium) {
            Button(role: .cancel, action: onReset) {
                Image(systemName: "xmark")
                    .font(.title3)
                    .frame(width: ControlMetrics.compactIconButton, height: ControlMetrics.compactIconButton)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .accessibilityLabel("Close Exposure")

            // Native SwiftUI Slider
            VStack(spacing: Spacing.tiny) {
                Text(formattedValue)
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(AppColors.primary)

                Slider(
                    value: Binding(
                        get: { Double(value) },
                        set: { value = Float($0) }
                    ),
                    in: -2...2,
                    step: 0.1
                )
                .tint(AppColors.primary)
                .accessibilityLabel("Exposure")
            }
            .layoutPriority(1) // Ensure slider takes up remaining space

            Button(action: onReset) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title3)
                    .frame(width: ControlMetrics.compactIconButton, height: ControlMetrics.compactIconButton)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .accessibilityLabel("Reset Exposure")
        }
        .padding(.horizontal, Spacing.standard)
        .padding(.vertical, Spacing.small)
        .glassPill()
    }



    private var formattedValue: String {
        let normalized = Double(value)
        if abs(normalized) < 0.05 {
            return "0,0"
        }

        let number = normalized.formatted(.number.precision(.fractionLength(1)))
        return number.replacingOccurrences(of: ".", with: ",")
    }
}

