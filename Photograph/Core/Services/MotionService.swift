//
//  MotionService.swift
//  Soolene
//
//  Provides real-time device attitude data using sensor fusion (accelerometer + gyroscope).
//  Used to give accurate horizontal/vertical level guidance independent of Vision.
//
//  Why CoreMotion instead of Vision for leveling?
//  - VNDetectHorizonRequest analyzes image pixels, which is slow (every N frames).
//  - CMDeviceMotion runs at 30–60Hz via hardware sensor fusion, giving smooth real-time feedback.
//  - Combined: CoreMotion gives instantaneous level feedback; Vision gives scene-content accuracy.
//
//  Created by Baren Baruna Harahap on 05/06/26.
//

import CoreMotion
import Foundation

final class MotionService: @unchecked Sendable {

    // MARK: - Public State

    /// Roll angle in degrees. 0 = perfectly level (landscape-neutral).
    /// Positive = device tilted right, negative = tilted left.
    private(set) var rollDegrees: Double = 0

    /// Pitch angle in degrees relative to vertical hold.
    /// When holding phone in portrait, pitch ≈ 0 at upright.
    private(set) var pitchDegrees: Double = 0

    /// True when the device is within ±2° of level (both roll and pitch combined).
    var isLevel: Bool {
        abs(rollDegrees) < 2.0 && abs(pitchDegrees) < 2.0
    }

    /// Callback fired on main thread whenever attitude updates (throttled to 30Hz).
    var onAttitudeUpdated: (() -> Void)?

    // MARK: - Private

    private let motionManager = CMMotionManager()
    private var updateCounter = 0

    // MARK: - Lifecycle

    func start() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0  // 30 Hz
        motionManager.startDeviceMotionUpdates(
            using: .xArbitraryZVertical,
            to: .main
        ) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.updateAttitude(from: motion.attitude)
        }
    }

    func stop() {
        motionManager.stopDeviceMotionUpdates()
    }

    // MARK: - Private

    private func updateAttitude(from attitude: CMAttitude) {
        // Convert radians to degrees for readability
        rollDegrees  = attitude.roll  * (180 / .pi)
        pitchDegrees = attitude.pitch * (180 / .pi)
        onAttitudeUpdated?()
    }
}
