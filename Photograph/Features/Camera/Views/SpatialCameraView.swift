//
//  SpatialCameraView.swift
//  Photograph
//
//  SwiftUI wrapper for ARKit camera preview with tap / long-press / pinch gestures.
//

import ARKit
import SwiftUI

/// Full-screen AR camera preview backed by ARSCNView.
struct SpatialCameraView: UIViewRepresentable {
    let engine: SpatialCameraEngine
    var onTap: ((CGPoint, CGPoint) -> Void)?
    var onLongPress: ((CGPoint, CGPoint) -> Void)?
    var onDoubleTap: (() -> Void)?
    var onPinch: ((CGFloat, Bool) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.session = engine.session
        view.automaticallyUpdatesLighting = false
        view.rendersCameraGrain = true
        view.antialiasingMode = ProcessInfo.processInfo.thermalState == .nominal
            ? .multisampling4X
            : .none
        view.contentMode = .scaleAspectFill

        context.coordinator.arView = view
        context.coordinator.engine = engine
        context.coordinator.onTap = onTap
        context.coordinator.onLongPress = onLongPress
        context.coordinator.onDoubleTap = onDoubleTap
        context.coordinator.onPinch = onPinch
        context.coordinator.installGestures(on: view)

        updateViewportSize(for: view)
        return view
    }

    func updateUIView(_ uiView: ARSCNView, context: Context) {
        context.coordinator.arView = uiView
        context.coordinator.engine = engine
        context.coordinator.onTap = onTap
        context.coordinator.onLongPress = onLongPress
        context.coordinator.onDoubleTap = onDoubleTap
        context.coordinator.onPinch = onPinch
        updateViewportSize(for: uiView)
    }

    private func updateViewportSize(for view: ARSCNView) {
        let size = view.bounds.size
        guard size.width > 0, size.height > 0 else { return }
        let orientation = view.window?.windowScene?.interfaceOrientation ?? .portrait
        engine.updateViewport(size: size, orientation: orientation)
    }

    final class Coordinator: NSObject {
        weak var arView: ARSCNView?
        weak var engine: SpatialCameraEngine?
        var onTap: ((CGPoint, CGPoint) -> Void)?
        var onLongPress: ((CGPoint, CGPoint) -> Void)?
        var onDoubleTap: (() -> Void)?
        var onPinch: ((CGFloat, Bool) -> Void)?
        private var didInstallGestures = false

        func installGestures(on view: ARSCNView) {
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

        private func normalizedPair(in view: ARSCNView, at viewPoint: CGPoint) -> (CGPoint, CGPoint) {
            let normalized = CoordinateMapper.normalizedPoint(in: view.bounds.size, viewPoint: viewPoint)
            return (viewPoint, normalized)
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let view = arView else { return }
            let viewPoint = recognizer.location(in: view)
            let pair = normalizedPair(in: view, at: viewPoint)
            onTap?(pair.0, pair.1)
        }

        @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            onDoubleTap?()
        }

        @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began, let view = arView else { return }
            let viewPoint = recognizer.location(in: view)
            let pair = normalizedPair(in: view, at: viewPoint)
            onLongPress?(pair.0, pair.1)
        }

        @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard recognizer.state == .changed || recognizer.state == .ended else { return }
            onPinch?(recognizer.scale, recognizer.state == .ended)
        }
    }
}
