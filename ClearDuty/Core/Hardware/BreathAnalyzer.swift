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

    // Reports each stage of a reading as the device reaches it.
    func measure() -> AsyncThrowingStream<BlowStage, any Error>
}

extension BreathAnalyzer {

    // True while the calibration is still in date.
    func isCalibrated(on date: Date = .now) -> Bool {
        calibrationExpiresOn > date
    }
}

// One stage of taking a reading, mirroring what a device reports.
enum BlowStage: Equatable, Sendable {
    case warmingUp(secondsRemaining: Int)
    case readyToBlow
    case blowing
    case analysing
    // Blood alcohol as a percentage, so 0.04 means 0.04 percent.
    case complete(Double)
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

    var warmUpSeconds = 3

    // A countdown ticks once a second, whatever the instructions take.
    var warmUpTick: Duration = .seconds(1)

    // Long enough to read an instruction before it is replaced.
    var stageDuration: Duration = .seconds(3)

    // Fails partway through, to exercise an interrupted blow.
    var failsAfter: BlowStage?

    func measure() -> AsyncThrowingStream<BlowStage, any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard isConnected else { throw BreathAnalyzerError.notConnected }
                    guard isCalibrated() else { throw BreathAnalyzerError.calibrationExpired }

                    for remaining in stride(from: warmUpSeconds, to: 0, by: -1) {
                        try await emit(
                            .warmingUp(secondsRemaining: remaining),
                            to: continuation,
                            lasting: warmUpTick
                        )
                    }
                    try await emit(.readyToBlow, to: continuation)
                    try await emit(.blowing, to: continuation)
                    try await emit(.analysing, to: continuation)
                    continuation.yield(.complete(reading))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private func emit(
        _ stage: BlowStage,
        to continuation: AsyncThrowingStream<BlowStage, any Error>.Continuation,
        lasting duration: Duration? = nil
    ) async throws {
        if stage == failsAfter { throw BreathAnalyzerError.insufficientSample }
        continuation.yield(stage)

        let holding = duration ?? stageDuration
        if holding > .zero { try await Task.sleep(for: holding) }
    }
}
