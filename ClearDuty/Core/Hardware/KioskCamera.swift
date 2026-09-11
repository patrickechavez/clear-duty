//
//  KioskCamera.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/11/26.
//

import AVFoundation
import os

// The one camera the kiosk uses: card scanning and the blow photo.
final class KioskCamera: NSObject, PhotoCapture, @unchecked Sendable {

    let session = AVCaptureSession()

    private(set) var device: AVCaptureDevice?

    // One card fills many frames, so the same code is reported once a scan.
    private static let rescanDelay: TimeInterval = 5

    // A camera that never answers must not hold the blow screen open.
    private static let captureTimeout: TimeInterval = 3

    private let sessionQueue = DispatchQueue(label: "com.echavez.ClearDuty.camera")

    private let photoOutput = AVCapturePhotoOutput()

    private let codeOutput = AVCaptureMetadataOutput()

    private let shared = OSAllocatedUnfairLock(initialState: Shared())

    // Everything the capture queues touch.
    private struct Shared {
        var codes: [UUID: AsyncStream<String>.Continuation] = [:]
        var photos: [Int64: CheckedContinuation<Data, any Error>] = [:]
        var lastCode: String?
        var lastCodeAt = Date.distantPast
    }

    private var rotation: AVCaptureDevice.RotationCoordinator?

    private var rotationObserver: NSKeyValueObservation?

    override init() {
        super.init()
        configure()
    }

    func start() {
        sessionQueue.async { [self] in
            guard device != nil, !session.isRunning else { return }
            session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            guard session.isRunning else { return }
            session.stopRunning()
        }
    }

    // Emits each card code the camera reads.
    func codes() -> AsyncStream<String> {
        AsyncStream { continuation in
            let id = UUID()
            shared.withLock { $0.codes[id] = continuation }
            continuation.onTermination = { [weak self] _ in
                self?.shared.withLock { $0.codes.removeValue(forKey: id) }
            }
        }
    }

    func capturePhoto() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async { [self] in
                guard session.isRunning else {
                    continuation.resume(throwing: PhotoCaptureError.cameraUnavailable)
                    return
                }

                let settings = AVCapturePhotoSettings()
                let id = settings.uniqueID
                shared.withLock { $0.photos[id] = continuation }
                photoOutput.capturePhoto(with: settings, delegate: self)
                giveUpOnPhoto(id, after: Self.captureTimeout)
            }
        }
    }

    // Whoever gets there first takes the continuation, so it resumes once.
    private func giveUpOnPhoto(_ id: Int64, after delay: TimeInterval) {
        sessionQueue.asyncAfter(deadline: .now() + delay) { [self] in
            let waiting = shared.withLock { $0.photos.removeValue(forKey: id) }
            waiting?.resume(throwing: PhotoCaptureError.captureFailed)
        }
    }

    private func configure() {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else { return }

        device = camera

        session.beginConfiguration()
        session.sessionPreset = .photo
        session.addInput(input)
        addCodeReader()
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        session.commitConfiguration()

        followRotation(of: camera)
    }

    private func addCodeReader() {
        guard session.canAddOutput(codeOutput) else { return }

        session.addOutput(codeOutput)
        codeOutput.setMetadataObjectsDelegate(self, queue: .main)
        codeOutput.metadataObjectTypes = [.qr, .code128]
    }

    // Keeps the photo upright as the mounted device turns.
    private func followRotation(of camera: AVCaptureDevice) {
        let coordinator = AVCaptureDevice.RotationCoordinator(device: camera, previewLayer: nil)
        rotation = coordinator
        apply(angle: coordinator.videoRotationAngleForHorizonLevelCapture)

        rotationObserver = coordinator.observe(
            \.videoRotationAngleForHorizonLevelCapture,
            options: [.new]
        ) { [weak self] _, change in
            guard let angle = change.newValue else { return }
            self?.apply(angle: angle)
        }
    }

    private func apply(angle: CGFloat) {
        sessionQueue.async { [self] in
            guard let connection = photoOutput.connection(with: .video),
                  connection.isVideoRotationAngleSupported(angle) else { return }
            connection.videoRotationAngle = angle
        }
    }
}

extension KioskCamera: AVCaptureMetadataOutputObjectsDelegate {

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput objects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let code = (objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }

        let now = Date.now
        let isNew = shared.withLock { state in
            let isRepeat = state.lastCode == code && now.timeIntervalSince(state.lastCodeAt) < Self.rescanDelay
            state.lastCode = code
            state.lastCodeAt = now
            return !isRepeat
        }
        guard isNew else { return }

        for watcher in shared.withLock({ Array($0.codes.values) }) {
            watcher.yield(code)
        }
    }
}

extension KioskCamera: AVCapturePhotoCaptureDelegate {

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: (any Error)?
    ) {
        let id = photo.resolvedSettings.uniqueID
        let waiting = shared.withLock { $0.photos.removeValue(forKey: id) }
        guard let waiting else { return }

        guard error == nil, let data = photo.fileDataRepresentation() else {
            waiting.resume(throwing: PhotoCaptureError.captureFailed)
            return
        }
        waiting.resume(returning: data)
    }
}
