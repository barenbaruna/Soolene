//
//  ViewfinderZoomShortcuts.swift
//  Soolene
//
//  Zoom shortcut buttons (0.5x, 1x, 2x, etc.).
//

import SwiftUI

struct ViewfinderZoomShortcuts: View {
    @Bindable var viewModel: CameraViewModel
    let isEnabled: Bool
    var glassID: String? = nil
    var glassNamespace: Namespace.ID? = nil
    var iconRotation: Double = 0

    private var availableLenses: [LensType] {
        let lenses = LensType.availableOnDevice
        if viewModel.cameraMode == .rearSpatial {
            return lenses.filter { $0.nominalMultiplier >= 1.0 }
        }
        return lenses
    }

    private var activeMultiplier: CGFloat {
        viewModel.zoomController.displayMultiplier
    }

    var body: some View {
        HStack(spacing: Spacing.small) {
            ForEach(availableLenses) { lens in
                let isSelected = isLensActive(lens)
                Button {
                    viewModel.setZoomMultiplier(lens.nominalMultiplier, isFinal: true)
                } label: {
                    Text(buttonLabel(for: lens, isSelected: isSelected))
                        .font(.headline.monospacedDigit().weight(isSelected ? .bold : .semibold))
                        .foregroundStyle(isSelected ? AppColors.controlActive : .primary)
                        .rotationEffect(.degrees(iconRotation))
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .background {
                    if #available(iOS 26, *) {
                        let glass: Glass = .clear.tint(Color.black.opacity(0.15)).interactive()
                        let base = Color.clear
                            .glassEffect(glass, in: .circle)
                            .allowsHitTesting(false)
                        
                        if isSelected, let id = glassID, let ns = glassNamespace {
                            base.glassEffectID(id, in: ns)
                        } else {
                            base
                        }
                    } else {
                        Circle()
                            .fill(.ultraThinMaterial)
                    }
                }
            }
        }
        .opacity(isEnabled ? 1 : 0.5)
        .allowsHitTesting(isEnabled)
        // Dragging the shortcuts invokes the ruler
        .gesture(
            DragGesture(minimumDistance: 10)
                .onChanged { _ in
                    viewModel.showZoomRulerTemporarily()
                }
        )
    }

    private func isLensActive(_ lens: LensType) -> Bool {
        let active = LensType.preset(containing: activeMultiplier, in: availableLenses)
        return active == lens
    }

    private func buttonLabel(for lens: LensType, isSelected: Bool) -> String {
        let label = lens.displayLabel
        if isSelected { return label }
        let raw = label.replacingOccurrences(of: "×", with: "")
        if raw == "0.5" { return ".5" }
        return raw
    }
}
