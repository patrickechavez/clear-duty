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
        case rejected(CardRejection)
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

    let terminalName: String

    private(set) var phase: Phase = .idle

    private(set) var tally = Tally()

    private(set) var unsyncedCount = 0

    @ObservationIgnored let analyzer: any BreathAnalyzer

    @ObservationIgnored private let employees: any EmployeeRepository

    init(
        terminalName: String,
        analyzer: any BreathAnalyzer,
        employees: any EmployeeRepository
    ) {
        self.terminalName = terminalName
        self.analyzer = analyzer
        self.employees = employees
    }

    // Resolves a scanned code to a driver, or to why it was refused.
    func cardWasRead(_ code: String) async {
        guard phase == .idle else { return }
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

    // The supervisor confirmed the face matches; the blow comes next.
    func identityConfirmed() {
        guard case .confirming = phase else { return }
        phase = .idle
    }

    func state(at date: Date = .now) -> State {
        if !analyzer.isConnected { return .fault(.analyzerDisconnected) }
        if !analyzer.isCalibrated(on: date) { return .fault(.calibrationExpired) }
        return .scanning
    }

    // The camera only looks while the kiosk is idle and healthy.
    func isCameraRunning(at date: Date = .now) -> Bool {
        phase == .idle && state(at: date) == .scanning
    }
}
