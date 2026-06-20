//
//  SpatialCameraView.swift
//  Soolene
//
//  SwiftUI wrapper for ARKit camera preview with tap / long-press / pinch gestures.
//  AR guidance uses visual preview zoom — ARKit wide-primary hi-res feeds ignore
//  `videoZoomFactor` for the live ARSCNView image.
//

import ARKit
import SwiftUI

/// Full-screen AR camera preview backed by ARSCNView.
struct SpatialCameraView: UIViewRepresentable {
    let engine: SpatialCameraEngine
    /// Display-space multiplier — drives visual preview zoom (1× = identity).
    let previewZoom: CGFloat
    var onTap: ((CGPoint, CGPoint) -> Void)?
    var onLongPress: ((CGPoint, CGPoint) -> Void)?
    var onDoubleTap: (() -> Void)?
    var onPinch: ((CGFloat, Bool) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARPreviewContainer {
        let container = ARPreviewContainer()
        container.arView.session = engine.session
        container.arView.automaticallyUpdatesLighting = false
        container.arView.rendersCameraGrain = true
        container.arView.antialiasingMode = ProcessInfo.processInfo.thermalState == .nominal
            ? .multisampling4X
            : .none
        container.arView.contentMode = .scaleAspectFill

        context.coordinator.container = container
        context.coordinator.engine = engine
        context.coordinator.onTap = onTap
        context.coordinator.onLongPress = onLongPress
        context.coordinator.onDoubleTap = onDoubleTap
        context.coordinator.onPinch = onPinch
        context.coordinator.installGestures(on: container)

        container.setPreviewZoom(previewZoom)
        updateViewportSize(for: container)
        return container
    }

    func updateUIView(_ uiView: ARPreviewContainer, context: Context) {
        context.coordinator.container = uiView
        context.coordinator.engine = engine
        context.coordinator.onTap = onTap
        context.coordinator.onLongPress = onLongPress
        context.coordinator.onDoubleTap = onDoubleTap
        context.coordinator.onPinch = onPinch
        uiView.setPreviewZoom(previewZoom)
        updateViewportSize(for: uiView)
    }

    private func updateViewportSize(for container: ARPreviewContainer) {
        let size = container.bounds.size
        guard size.width > 0, size.height > 0 else { return }
        let orientation = container.window?.windowScene?.interfaceOrientation ?? .portrait
        engine.updateViewport(size: size, orientation: orientation)
    }

    // MARK: - Container

    /// Clips a scaled ARSCNView so display-space zoom is visible during AR guidance.
    final class ARPreviewContainer: UIView {
        let arView = ARSCNView(frame: .zero)
        private(set) var previewZoom: CGFloat = 1.0

        override init(frame: CGRect) {
            super.init(frame: frame)
            clipsToBounds = true
            backgroundColor = .black
            arView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(arView)
            NSLayoutConstraint.activate([
                arView.leadingAnchor.constraint(equalTo: leadingAnchor),
                arView.trailingAnchor.constraint(equalTo: trailingAnchor),
                arView.topAnchor.constraint(equalTo: topAnchor),
                arView.bottomAnchor.constraint(equalTo: bottomAnchor)
            ])
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        func setPreviewZoom(_ zoom: CGFloat) {
            let clamped = min(max(zoom, 0.5), 10.0)
            guard abs(clamped - previewZoom) > 0.001 else { return }
            previewZoom = clamped
            applyPreviewTransform()
        }

        private func applyPreviewTransform() {
            // <1× cannot reveal ultra-wide on AR wide-primary — keep identity.
            let scale = previewZoom < 1.0 ? 1.0 : previewZoom
            arView.transform = CGAffineTransform(scaleX: scale, y: scale)
        }

        /// Maps a touch in container space to normalized image coordinates accounting for preview scale.
        func normalizedPoint(at containerPoint: CGPoint) -> CGPoint {
            let scale = previewZoom < 1.0 ? 1.0 : previewZoom
            let adjusted = CGPoint(
                x: bounds.midX + (containerPoint.x - bounds.midX) / scale,
                y: bounds.midY + (containerPoint.y - bounds.midY) / scale
            )
            return CoordinateMapper.normalizedPoint(in: bounds.size, viewPoint: adjusted)
        }
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject {
        weak var container: ARPreviewContainer?
        weak var engine: SpatialCameraEngine?
        var onTap: ((CGPoint, CGPoint) -> Void)?
        var onLongPress: ((CGPoint, CGPoint) -> Void)?
        var onDoubleTap: (() -> Void)?
        var onPinch: ((CGFloat, Bool) -> Void)?
        private var didInstallGestures = false

        func installGestures(on view: ARPreviewContainer) {
            guard !didInstallGestures else { return }
            didInstallGestures = true

            let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            singleTap.numberOfTapsRequired = 1

            let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
            doubleTap.numberOfTapsRequired = 2
            singleTap.require(toFail: doubleTap)

            let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            longPress.minimumPressDuration = 0.45

            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))

            view.addGestureRecognizer(singleTap)
            view.addGestureRecognizer(doubleTap)
            view.addGestureRecognizer(longPress)
            view.addGestureRecognizer(pinch)
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let container else { return }
            let viewPoint = recognizer.location(in: container)
            onTap?(viewPoint, container.normalizedPoint(at: viewPoint))
        }

        @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            onDoubleTap?()
        }

        @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began, let container else { return }
            let viewPoint = recognizer.location(in: container)
            onLongPress?(viewPoint, container.normalizedPoint(at: viewPoint))
        }

        @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard recognizer.state == .changed || recognizer.state == .ended else { return }
            onPinch?(recognizer.scale, recognizer.state == .ended)
        }
    }
}
