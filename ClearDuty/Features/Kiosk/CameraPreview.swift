//
//  CameraPreview.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/11/26.
//

import AVFoundation
import SwiftUI

// Shows what the kiosk camera sees, or black when there is no camera.
struct CameraPreview: View {

    let camera: KioskCamera?

    var body: some View {
        if let camera {
            CameraLayer(camera: camera)
        } else {
            Color.black
        }
    }
}

private struct CameraLayer: UIViewRepresentable {

    let camera: KioskCamera

    func makeUIView(context: Context) -> CameraPreviewView {
        CameraPreviewView(camera: camera)
    }

    func updateUIView(_ view: CameraPreviewView, context: Context) {}
}

final class CameraPreviewView: UIView {

    // Reports the preview angle to use as the device turns.
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var rotationObserver: NSKeyValueObservation?

    override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    private var previewLayer: AVCaptureVideoPreviewLayer? {
        layer as? AVCaptureVideoPreviewLayer
    }

    init(camera: KioskCamera) {
        super.init(frame: .zero)

        previewLayer?.session = camera.session
        previewLayer?.videoGravity = .resizeAspectFill

        guard let device = camera.device else { return }
        followDeviceRotation(of: device)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    private func followDeviceRotation(of device: AVCaptureDevice) {
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotation = coordinator
        apply(angle: coordinator.videoRotationAngleForHorizonLevelPreview)

        rotationObserver = coordinator.observe(
            \.videoRotationAngleForHorizonLevelPreview,
            options: [.new]
        ) { [weak self] _, change in
            guard let angle = change.newValue else { return }
            Task { @MainActor in self?.apply(angle: angle) }
        }
    }

    private func apply(angle: CGFloat) {
        guard let connection = previewLayer?.connection else { return }

        if connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }

        // The kiosk camera faces the driver, so the preview is mirrored.
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }
}
