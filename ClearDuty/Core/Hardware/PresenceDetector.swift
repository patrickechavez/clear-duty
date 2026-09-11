//
//  PresenceDetector.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/11/26.
//

import Foundation

// One look at the camera, stamped when the frame was seen.
struct PresenceReading: Equatable, Sendable {

    var isPresent: Bool

    var seenAt: Date

    init(isPresent: Bool, seenAt: Date = .now) {
        self.isPresent = isPresent
        self.seenAt = seenAt
    }
}

// Works out whether somebody is there from when a face was last seen.
struct PresenceClock: Sendable {

    // A face not seen for this long counts as gone.
    static let grace: TimeInterval = 0.5

    var lastFaceAt: Date?

    func reading(at date: Date = .now) -> PresenceReading {
        guard let lastFaceAt, date.timeIntervalSince(lastFaceAt) < Self.grace else {
            return PresenceReading(isPresent: false, seenAt: date)
        }
        return PresenceReading(isPresent: true, seenAt: date)
    }
}

// Reports whether a person is in front of the camera.
protocol PresenceDetector: Sendable {

    // Emits a reading each time the camera finds or loses a face.
    func presence() -> AsyncStream<PresenceReading>
}

// Tracks presence across one blow and holds the start until the driver arrives.
@MainActor
final class PresenceMonitor {

    // Shorter gaps are the analyser covering the face, not the driver leaving.
    nonisolated static let tolerance: Duration = .seconds(3)

    private(set) var isPresent = true

    private(set) var lostAt: Date?

    private(set) var wasLost = false

    private var arrival: CheckedContinuation<Bool, Never>?

    private var hasArrived = false

    private var detectorStopped = false

    func update(_ reading: PresenceReading) {
        update(isPresent: reading.isPresent, at: reading.seenAt)
    }

    func update(isPresent: Bool, at date: Date = .now) {
        self.isPresent = isPresent

        guard isPresent else {
            if lostAt == nil { lostAt = date }
            if let lostAt, date.timeIntervalSince(lostAt) >= Self.tolerance.seconds {
                wasLost = true
            }
            return
        }
        lostAt = nil
        hasArrived = true
        stopWaiting(arrived: true)
    }

    // Suspends until the driver is in frame, or gives up after the limit.
    func waitForArrival(within limit: Duration) async -> Bool {
        if hasArrived { return true }
        if detectorStopped { return false }

        let deadline = Task {
            try? await Task.sleep(for: limit)
            stopWaiting(arrived: false)
        }
        defer { deadline.cancel() }

        return await withCheckedContinuation { arrival = $0 }
    }

    // The detector stopped reporting, so nobody is going to arrive.
    func detectorFinished() {
        detectorStopped = true
        stopWaiting(arrived: false)
    }

    func reset() {
        stopWaiting(arrived: false)
        isPresent = true
        lostAt = nil
        wasLost = false
        hasArrived = false
        detectorStopped = false
    }

    private func stopWaiting(arrived: Bool) {
        arrival?.resume(returning: arrived)
        arrival = nil
    }
}

private extension Duration {
    var seconds: TimeInterval { TimeInterval(components.seconds) }
}

// Reports whatever presence it is told to, for previews and tests.
struct SimulatedPresenceDetector: PresenceDetector {

    var readings: [Bool] = [true]

    // Readings are stamped this far apart, so a run of absences trips the monitor.
    var spacing: Duration = PresenceMonitor.tolerance

    func presence() -> AsyncStream<PresenceReading> {
        AsyncStream { continuation in
            let start = Date.now
            for (index, isPresent) in readings.enumerated() {
                let seenAt = start.addingTimeInterval(Double(index) * spacing.seconds)
                continuation.yield(PresenceReading(isPresent: isPresent, seenAt: seenAt))
            }
            continuation.finish()
        }
    }
}
