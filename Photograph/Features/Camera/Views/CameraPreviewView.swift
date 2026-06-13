//
//  CameraPreviewView.swift
//  Photograph
//
//  Created by Baren Baruna Harahap on 18/05/26.
//

import AVFoundation
import SwiftUI

/// UIViewRepresentable wrapping AVCaptureVideoPreviewLayer.
/// Full-screen, hardware-composited — lowest possible latency.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var onTap: ((CGPoint, CGPoint) -> Void)?
    var onLongPress: ((CGPoint, CGPoint) -> Void)?
    var onDoubleTap: (() -> Void)?
    var onPinch: ((CGFloat, Bool) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        context.coordinator.previewView = view
        context.coordinator.onTap = onTap
        context.coordinator.onLongPress = onLongPress
        context.coordinator.onDoubleTap = onDoubleTap
        context.coordinator.onPinch = onPinch
        context.coordinator.installGestures(on: view)
        
        if let input = session.inputs.first as? AVCaptureDeviceInput {
            let coordinator = AVCaptureDevice.RotationCoordinator(device: input.device, previewLayer: view.previewLayer)
            view.rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak view] _, change in
                if let angle = change.newValue, let connection = view?.previewLayer.connection, connection.isVideoRotationAngleSupported(angle) {
                    DispatchQueue.main.async {
                        connection.videoRotationAngle = angle
                    }
                }
            }
            view.rotationCoordinator = coordinator
        }
        
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        context.coordinator.previewView = uiView
        context.coordinator.onTap = onTap
        context.coordinator.onLongPress = onLongPress
        context.coordinator.onDoubleTap = onDoubleTap
        context.coordinator.onPinch = onPinch

        // Handle camera switch (inputs changed)
        if let input = session.inputs.first as? AVCaptureDeviceInput, 
           uiView.rotationCoordinator?.device !== input.device {
            let coordinator = AVCaptureDevice.RotationCoordinator(device: input.device, previewLayer: uiView.previewLayer)
            uiView.rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.initial, .new]) { [weak uiView] _, change in
                if let angle = change.newValue, let connection = uiView?.previewLayer.connection, connection.isVideoRotationAngleSupported(angle) {
                    DispatchQueue.main.async {
                        connection.videoRotationAngle = angle
                    }
                }
            }
            uiView.rotationCoordinator = coordinator
        }
    }

    final class Coordinator: NSObject {
        weak var previewView: PreviewUIView?
        var onTap: ((CGPoint, CGPoint) -> Void)?
        var onLongPress: ((CGPoint, CGPoint) -> Void)?
        var onDoubleTap: (() -> Void)?
        var onPinch: ((CGFloat, Bool) -> Void)?
        private var didInstallGestures = false

        func installGestures(on view: PreviewUIView) {
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
            guard recognizer.state == .ended,
                  let view = previewView
            else { return }

            let viewPoint = recognizer.location(in: view)
            let devicePoint = view.previewLayer.captureDevicePointConverted(fromLayerPoint: viewPoint)
            onTap?(viewPoint, devicePoint)
        }

        @objc private func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended else { return }
            onDoubleTap?()
        }

        @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
            guard recognizer.state == .began,
                  let view = previewView
            else { return }

            let viewPoint = recognizer.location(in: view)
            let normalized = view.previewLayer.captureDevicePointConverted(fromLayerPoint: viewPoint)
            onLongPress?(viewPoint, normalized)
        }

        @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard recognizer.state == .changed || recognizer.state == .ended else { return }
            onPinch?(recognizer.scale, recognizer.state == .ended)
        }
    }
}

// MARK: - PreviewUIView

final class PreviewUIView: UIView {
    var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    var rotationObservation: NSKeyValueObservation?

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}
