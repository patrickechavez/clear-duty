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

    // Conditions that stop the terminal producing a valid test.
    enum Fault: Equatable {
        case analyzerDisconnected
        case calibrationExpired
    }

    let terminalName: String

    private(set) var tally = Tally()

    private(set) var unsyncedCount = 0

    @ObservationIgnored let analyzer: any BreathAnalyzer

    init(terminalName: String, analyzer: any BreathAnalyzer) {
        self.terminalName = terminalName
        self.analyzer = analyzer
    }

    func state(at date: Date = .now) -> State {
        if !analyzer.isConnected { return .fault(.analyzerDisconnected) }
        if !analyzer.isCalibrated(on: date) { return .fault(.calibrationExpired) }
        return .scanning
    }

    func isCameraRunning(at date: Date = .now) -> Bool {
        state(at: date) == .scanning
    }
}
