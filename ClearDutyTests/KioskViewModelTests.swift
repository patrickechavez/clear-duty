//
//  KioskViewModelTests.swift
//  ClearDutyTests
//

import Foundation
import Testing
@testable import ClearDuty

@MainActor
struct KioskViewModelTests {

    private func makeViewModel(
        analyzer: SimulatedBreathAnalyzer = SimulatedBreathAnalyzer()
    ) -> KioskViewModel {
        KioskViewModel(terminalName: "Cubao terminal", analyzer: analyzer)
    }

    @Test func scansWhenTheAnalyzerIsHealthy() {
        let viewModel = makeViewModel()

        #expect(viewModel.state() == .scanning)
        #expect(viewModel.isCameraRunning())
    }

    @Test func reportsADisconnectedAnalyzer() {
        let viewModel = makeViewModel(analyzer: SimulatedBreathAnalyzer(isConnected: false))

        #expect(viewModel.state() == .fault(.analyzerDisconnected))
        #expect(!viewModel.isCameraRunning())
    }

    @Test func reportsAnExpiredCalibration() {
        let viewModel = makeViewModel(
            analyzer: SimulatedBreathAnalyzer(calibrationExpiresOn: .now.addingTimeInterval(-86_400))
        )

        #expect(viewModel.state() == .fault(.calibrationExpired))
        #expect(!viewModel.isCameraRunning())
    }

    // A disconnected analyser is reported even when its calibration has lapsed too.
    @Test func prefersTheConnectionFault() {
        let viewModel = makeViewModel(
            analyzer: SimulatedBreathAnalyzer(
                calibrationExpiresOn: .now.addingTimeInterval(-86_400),
                isConnected: false
            )
        )

        #expect(viewModel.state() == .fault(.analyzerDisconnected))
    }

    @Test func startsWithAnEmptyTally() {
        let viewModel = makeViewModel()

        #expect(viewModel.tally == KioskViewModel.Tally())
        #expect(viewModel.unsyncedCount == 0)
    }
}

struct SimulatedBreathAnalyzerTests {

    @Test func returnsTheReadingItWasGiven() async throws {
        let analyzer = SimulatedBreathAnalyzer(reading: 0.04, blowDuration: .zero)

        #expect(try await analyzer.measure() == 0.04)
    }

    @Test func refusesWhenDisconnected() async {
        let analyzer = SimulatedBreathAnalyzer(isConnected: false, blowDuration: .zero)

        await #expect(throws: BreathAnalyzerError.notConnected) { try await analyzer.measure() }
    }

    @Test func refusesWhenCalibrationHasLapsed() async {
        let analyzer = SimulatedBreathAnalyzer(
            calibrationExpiresOn: .now.addingTimeInterval(-86_400),
            blowDuration: .zero
        )

        await #expect(throws: BreathAnalyzerError.calibrationExpired) { try await analyzer.measure() }
    }
}
