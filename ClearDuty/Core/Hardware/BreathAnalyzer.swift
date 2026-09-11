//
//  BreathAnalyzer.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/11/26.
//

import Foundation

// A breath analyser the app can measure with.
protocol BreathAnalyzer: Sendable {

    var serial: String { get }

    var calibrationExpiresOn: Date { get }

    var isConnected: Bool { get }

    // Returns blood alcohol as a percentage, so 0.04 means 0.04 percent.
    func measure() async throws -> Double
}

extension BreathAnalyzer {

    // True while the calibration is still in date.
    func isCalibrated(on date: Date = .now) -> Bool {
        calibrationExpiresOn > date
    }
}

enum BreathAnalyzerError: Error, Equatable {
    case notConnected
    case calibrationExpired
    case insufficientSample
}

// Returns whatever reading it is configured with, after a delay.
struct SimulatedBreathAnalyzer: BreathAnalyzer {

    var serial = "SIM-0001"

    var calibrationExpiresOn = Calendar.current.date(byAdding: .month, value: 8, to: .now) ?? .now

    var isConnected = true

    var reading: Double = 0

    var blowDuration: Duration = .seconds(3)

    func measure() async throws -> Double {
        guard isConnected else { throw BreathAnalyzerError.notConnected }
        guard isCalibrated() else { throw BreathAnalyzerError.calibrationExpired }

        try await Task.sleep(for: blowDuration)
        return reading
    }
}
