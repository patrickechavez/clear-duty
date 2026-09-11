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
        analyzer: SimulatedBreathAnalyzer = SimulatedBreathAnalyzer(),
        employees: MockEmployeeRepository = MockEmployeeRepository()
    ) -> KioskViewModel {
        KioskViewModel(terminalName: "Cubao terminal", analyzer: analyzer, employees: employees)
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

    @Test func startsIdle() {
        #expect(makeViewModel().phase == .idle)
    }

    @Test func confirmsAKnownDriver() async {
        let viewModel = makeViewModel()

        await viewModel.cardWasRead("CARD-4F2A91")

        #expect(viewModel.phase == .confirming(SampleData.driver))
    }

    @Test func rejectsAnUnknownCard() async {
        let viewModel = makeViewModel()

        await viewModel.cardWasRead("CARD-NOTREAL")

        #expect(viewModel.phase == .rejected(.unrecognised))
    }

    // A suspended driver and a staff card look the same on a mounted screen.
    @Test func rejectsASuspendedDriverAndStaffAlike() async {
        let suspended = makeViewModel()
        await suspended.cardWasRead("CARD-0FA983")

        let staff = makeViewModel()
        await staff.cardWasRead("CARD-S014")

        #expect(suspended.phase == .rejected(.notCleared))
        #expect(staff.phase == .rejected(.notCleared))
    }

    @Test func ignoresAScanWhileAnotherIsInFlight() async {
        let employees = MockEmployeeRepository()
        let viewModel = makeViewModel(employees: employees)

        await viewModel.cardWasRead("CARD-4F2A91")
        await viewModel.cardWasRead("CARD-0FA983")

        #expect(viewModel.phase == .confirming(SampleData.driver))
        #expect(employees.lookups == ["CARD-4F2A91"])
    }

    @Test func returnsToIdleAfterARejection() async {
        let viewModel = makeViewModel()
        await viewModel.cardWasRead("CARD-NOTREAL")

        viewModel.returnToIdle()

        #expect(viewModel.phase == .idle)
    }

    @Test func keepsTheCameraOffWhileConfirming() async {
        let viewModel = makeViewModel()

        await viewModel.cardWasRead("CARD-4F2A91")

        #expect(!viewModel.isCameraRunning())
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
