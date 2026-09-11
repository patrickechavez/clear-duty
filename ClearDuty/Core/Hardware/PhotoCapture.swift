//
//  PhotoCapture.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/11/26.
//

import Foundation

// Takes the still that shows who actually blew into the analyser.
protocol PhotoCapture: Sendable {

    // Returns the encoded image, or throws if the camera could not take one.
    func capturePhoto() async throws -> Data
}

enum PhotoCaptureError: Error, Equatable {
    case cameraUnavailable
    case captureFailed
}

// Returns a fixed image, for previews and tests.
struct SimulatedPhotoCapture: PhotoCapture {

    var photo = Data("simulated-photo".utf8)

    var failure: PhotoCaptureError?

    func capturePhoto() async throws -> Data {
        if let failure { throw failure }
        return photo
    }
}
