//
//  CardScannerView.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/11/26.
//

import AVFoundation
import SwiftUI

// Shows the camera and reports any QR or barcode it reads.
struct CardScannerView: UIViewRepresentable {

    let isRunning: Bool

    let onRead: (String) -> Void

    func makeUIView(context: Context) -> ScannerPreviewView {
        let view = ScannerPreviewView()
        view.onRead = onRead
        return view
    }

    func updateUIView(_ view: ScannerPreviewView, context: Context) {
        view.onRead = onRead
        if isRunning {
            view.start()
        } else {
            view.stop()
        }
    }

    static func dismantleUIView(_ view: ScannerPreviewView, coordinator: ()) {
        view.stop()
    }
}

final class ScannerPreviewView: UIView, AVCaptureMetadataOutputObjectsDelegate {

    var onRead: ((String) -> Void)?

    // Carries the non-Sendable session to the serial queue below.
    private struct SessionBox: @unchecked Sendable {
        let session: AVCaptureSession
    }

    private static let sessionQueue = DispatchQueue(label: "com.echavez.ClearDuty.scanner")

    private let session = AVCaptureSession()
    private var isConfigured = false
    private var lastCode: String?

    // Reports the preview angle to use as the device turns.
    private var rotation: AVCaptureDevice.RotationCoordinator?
    private var rotationObserver: NSKeyValueObservation?
    private var isFrontCamera = false

    override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    private var previewLayer: AVCaptureVideoPreviewLayer? {
        layer as? AVCaptureVideoPreviewLayer
    }

    func start() {
        configureIfNeeded()
        guard isConfigured else { return }

        let box = SessionBox(session: session)
        Self.sessionQueue.async {
            guard !box.session.isRunning else { return }
            box.session.startRunning()
        }
    }

    func stop() {
        let box = SessionBox(session: session)
        Self.sessionQueue.async {
            guard box.session.isRunning else { return }
            box.session.stopRunning()
        }
    }

    private func configureIfNeeded() {
        guard !isConfigured else { return }
        let position: AVCaptureDevice.Position = .front
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }

        isFrontCamera = position == .front

        session.beginConfiguration()
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr, .code128]
        session.commitConfiguration()

        previewLayer?.session = session
        previewLayer?.videoGravity = .resizeAspectFill
        isConfigured = true

        followDeviceRotation(of: device)
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

        // Mirror the front camera only.
        if connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isFrontCamera
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput objects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let code = (objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        // One card fills many frames, so report each code once.
        guard code != lastCode else { return }
        lastCode = code
        onRead?(code)
    }
}
