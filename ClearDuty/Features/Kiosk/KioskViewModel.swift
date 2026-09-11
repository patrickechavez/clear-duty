//
//  KioskViewModel.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/11/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class KioskViewModel {

    struct Tally: Equatable {
        var cleared = 0
        var pending = 0
        var blocked = 0
    }

    enum State: Equatable {
        case scanning
        case fault(Fault)
    }

    // What the kiosk is showing. Phases replace each other in place.
    enum Phase: Equatable {
        case idle
        case looking
        case confirming(Employee)
        // Waiting for the driver to step in front of the camera.
        case awaitingPresence(Employee)
        case rejected(CardRejection)
        case blowing(Employee, BlowStage)
        case cancelled(Employee)
        case result(Outcome)
    }

    // What a completed test came to, and who it was about.
    struct Outcome: Equatable {
        let driver: Employee
        let reading: Double?
        let threshold: Double
        let verdict: Verdict
        // True when the driver left the camera during the blow.
        var presenceLost = false
        // The still taken while the driver was blowing, if one was caught.
        var photo: Data?
    }

    enum Verdict: Equatable {
        case cleared
        case blocked
        // No usable sample, so nothing was decided. Recorded, not discarded.
        case invalid(InvalidReason)
    }

    enum InvalidReason: Equatable {
        case analyzerFailed
        case driverLeft
    }

    // Why a scanned card did not reach the confirm screen.
    enum CardRejection: Equatable {
        case unrecognised
        case notCleared

        init(_ failure: CardLookupFailure) {
            switch failure {
            case .unknownCard: self = .unrecognised
            // A suspended driver and a staff card read the same on screen, so a
            // mounted terminal does not announce why someone was refused.
            case .suspended, .notADriver: self = .notCleared
            }
        }
    }

    // Conditions that stop the terminal producing a valid test.
    enum Fault: Equatable {
        case analyzerDisconnected
        case calibrationExpired
    }

    // Zero tolerance for public utility drivers. Belongs on a policy record
    // once one exists, and is snapshotted onto every test either way.
    static let threshold: Double = 0

    let terminalName: String

    private(set) var phase: Phase = .idle

    private(set) var tally = Tally()

    private(set) var unsyncedCount = 0

    // Held until persistence exists to write it.
    private(set) var lastCancellation: Outcome?

    @ObservationIgnored let analyzer: any BreathAnalyzer

    @ObservationIgnored private let employees: any EmployeeRepository

    @ObservationIgnored private let presenceDetector: any PresenceDetector

    @ObservationIgnored private let photos: any PhotoCapture

    @ObservationIgnored private let presence = PresenceMonitor()

    // How long a confirmed driver has to step in front of the camera.
    @ObservationIgnored private let presenceTimeout: Duration

    // The session the kiosk screens preview. Absent in tests and previews.
    @ObservationIgnored let camera: KioskCamera?

    init(
        terminalName: String,
        analyzer: any BreathAnalyzer,
        employees: any EmployeeRepository,
        presenceDetector: any PresenceDetector = SimulatedPresenceDetector(),
        photos: any PhotoCapture = SimulatedPhotoCapture(),
        presenceTimeout: Duration = .seconds(20),
        camera: KioskCamera? = nil
    ) {
        self.terminalName = terminalName
        self.analyzer = analyzer
        self.employees = employees
        self.presenceDetector = presenceDetector
        self.photos = photos
        self.presenceTimeout = presenceTimeout
        self.camera = camera
    }

    // Resolves a scanned code to a driver, or to why it was refused. A faulted
    // terminal ignores cards, since it cannot produce a valid test.
    func cardWasRead(_ code: String) async {
        guard phase == .idle, state() == .scanning else { return }
        phase = .looking

        do {
            phase = .confirming(try await employees.driver(withCard: code))
        } catch let failure as CardLookupFailure {
            phase = .rejected(CardRejection(failure))
        } catch {
            phase = .rejected(.unrecognised)
        }
    }

    func returnToIdle() {
        phase = .idle
    }

    // The supervisor confirmed the face matches, so take the reading once the
    // driver is actually in front of the camera.
    func identityConfirmed() async {
        guard case let .confirming(driver) = phase else { return }
        presence.reset()
        phase = .awaitingPresence(driver)

        let watching = Task { await watchPresence() }
        defer { watching.cancel() }

        // Does not start until someone is in frame, so the photo has a subject.
        guard await presence.waitForArrival(within: presenceTimeout) else {
            cancel(for: driver, photo: nil)
            return
        }
        await takeReading(for: driver)
    }

    // Feeds the monitor for as long as the attempt lasts.
    private func watchPresence() async {
        for await reading in presenceDetector.presence() {
            presence.update(reading)
        }
        presence.detectorFinished()
    }

    private func takeReading(for driver: Employee) async {
        phase = .blowing(driver, .warmingUp(secondsRemaining: 0))
        var photo: Task<Data?, Never>?

        do {
            for try await stage in analyzer.measure() {
                // Once the sample is captured, walking away cannot invalidate it.
                if stage != .analysing, presence.wasLost {
                    cancel(for: driver, photo: await taken(photo))
                    return
                }

                // Taken mid-blow, when the driver is holding the analyser.
                if stage == .blowing, photo == nil {
                    photo = Task { try? await photos.capturePhoto() }
                }

                if case let .complete(reading) = stage {
                    phase = .result(outcome(for: driver, reading: reading, photo: await taken(photo)))
                } else {
                    phase = .blowing(driver, stage)
                }
            }
        } catch {
            phase = .result(outcome(
                for: driver,
                reading: nil,
                reason: .analyzerFailed,
                photo: await taken(photo)
            ))
        }
    }

    private func taken(_ photo: Task<Data?, Never>?) async -> Data? {
        guard let photo else { return nil }
        return await photo.value
    }

    // Saved rather than discarded, so repeated abandonment leaves a trail.
    private func cancel(for driver: Employee, photo: Data?) {
        lastCancellation = outcome(for: driver, reading: nil, reason: .driverLeft, photo: photo)
        phase = .cancelled(driver)
    }

    // The supervisor sends the driver back to try again.
    func retryAfterCancellation() {
        guard case let .cancelled(driver) = phase else { return }
        presence.reset()
        phase = .confirming(driver)
    }

    private func outcome(
        for driver: Employee,
        reading: Double?,
        reason: InvalidReason = .analyzerFailed,
        photo: Data? = nil
    ) -> Outcome {
        guard let reading else {
            return Outcome(
                driver: driver,
                reading: nil,
                threshold: Self.threshold,
                verdict: .invalid(reason),
                presenceLost: presence.wasLost,
                photo: photo
            )
        }
        return Outcome(
            driver: driver,
            reading: reading,
            threshold: Self.threshold,
            verdict: reading <= Self.threshold ? .cleared : .blocked,
            presenceLost: presence.wasLost,
            photo: photo
        )
    }

    func state(at date: Date = .now) -> State {
        if !analyzer.isConnected { return .fault(.analyzerDisconnected) }
        if !analyzer.isCalibrated(on: date) { return .fault(.calibrationExpired) }
        return .scanning
    }
}
