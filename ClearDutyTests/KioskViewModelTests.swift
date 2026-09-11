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
        employees: MockEmployeeRepository = MockEmployeeRepository(),
        presence: SimulatedPresenceDetector = SimulatedPresenceDetector(),
        photos: SimulatedPhotoCapture = SimulatedPhotoCapture()
    ) -> KioskViewModel {
        KioskViewModel(
            terminalName: "Cubao terminal",
            analyzer: analyzer,
            employees: employees,
            presenceDetector: presence,
            photos: photos
        )
    }

    // Nobody in front of the camera means no reading is taken at all.
    @Test func doesNotBlowWithoutTheDriver() async {
        let viewModel = makeViewModel(presence: SimulatedPresenceDetector(readings: [false]))
        await viewModel.cardWasRead("CARD-4F2A91")

        await viewModel.identityConfirmed()

        #expect(viewModel.phase == .cancelled(SampleData.driver))
        #expect(viewModel.lastCancellation?.verdict == .invalid(.driverLeft))
    }

    @Test func scansWhenTheAnalyzerIsHealthy() {
        let viewModel = makeViewModel()

        #expect(viewModel.state() == .scanning)
    }

    @Test func reportsADisconnectedAnalyzer() {
        let viewModel = makeViewModel(analyzer: SimulatedBreathAnalyzer(isConnected: false))

        #expect(viewModel.state() == .fault(.analyzerDisconnected))
    }

    @Test func reportsAnExpiredCalibration() {
        let viewModel = makeViewModel(
            analyzer: SimulatedBreathAnalyzer(calibrationExpiresOn: .now.addingTimeInterval(-86_400))
        )

        #expect(viewModel.state() == .fault(.calibrationExpired))
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

    // A terminal that cannot test does not start one.
    @Test func ignoresAScanWhileTheAnalyserIsDisconnected() async {
        let employees = MockEmployeeRepository()
        let viewModel = makeViewModel(
            analyzer: SimulatedBreathAnalyzer(isConnected: false),
            employees: employees
        )

        await viewModel.cardWasRead("CARD-4F2A91")

        #expect(viewModel.phase == .idle)
        #expect(employees.lookups.isEmpty)
    }

    @Test func ignoresAScanWhileTheCalibrationHasLapsed() async {
        let viewModel = makeViewModel(
            analyzer: SimulatedBreathAnalyzer(calibrationExpiresOn: .now.addingTimeInterval(-86_400))
        )

        await viewModel.cardWasRead("CARD-4F2A91")

        #expect(viewModel.phase == .idle)
    }

    @Test func returnsToIdleAfterARejection() async {
        let viewModel = makeViewModel()
        await viewModel.cardWasRead("CARD-NOTREAL")

        viewModel.returnToIdle()

        #expect(viewModel.phase == .idle)
    }

    @Test func clearsADriverWhoBlowsZero() async {
        let analyzer = SimulatedBreathAnalyzer(reading: 0, warmUpSeconds: 0, stageDuration: .zero)
        let viewModel = makeViewModel(analyzer: analyzer)
        await viewModel.cardWasRead("CARD-4F2A91")

        await viewModel.identityConfirmed()

        #expect(viewModel.phase == .result(KioskViewModel.Outcome(
            driver: SampleData.driver,
            reading: 0,
            threshold: 0,
            verdict: .cleared,
            photo: SimulatedPhotoCapture().photo
        )))
    }

    // Zero tolerance, so anything above zero blocks.
    @Test func blocksADriverOverTheThreshold() async {
        let analyzer = SimulatedBreathAnalyzer(reading: 0.01, warmUpSeconds: 0, stageDuration: .zero)
        let viewModel = makeViewModel(analyzer: analyzer)
        await viewModel.cardWasRead("CARD-4F2A91")

        await viewModel.identityConfirmed()

        guard case let .result(outcome) = viewModel.phase else {
            Issue.record("expected a result")
            return
        }
        #expect(outcome.verdict == .blocked)
        #expect(outcome.reading == 0.01)
    }

    @Test func blowsOnlyFromTheConfirmScreen() async {
        let viewModel = makeViewModel()

        await viewModel.identityConfirmed()

        #expect(viewModel.phase == .idle)
    }

    @Test func returnsToIdleAfterAResult() async {
        let viewModel = makeViewModel(analyzer: SimulatedBreathAnalyzer(warmUpSeconds: 0, stageDuration: .zero))
        await viewModel.cardWasRead("CARD-4F2A91")
        await viewModel.identityConfirmed()

        viewModel.returnToIdle()

        #expect(viewModel.phase == .idle)
    }

    // A blow that stops early produces no reading, so nobody is blocked, and
    // there was no blow to photograph.
    @Test func recordsAnInterruptedBlowAsInvalid() async {
        let viewModel = makeViewModel(analyzer: SimulatedBreathAnalyzer(
            warmUpSeconds: 0,
            stageDuration: .zero,
            failsAfter: .blowing
        ))
        await viewModel.cardWasRead("CARD-4F2A91")

        await viewModel.identityConfirmed()

        guard case let .result(outcome) = viewModel.phase else {
            Issue.record("expected a result")
            return
        }
        #expect(outcome.verdict == .invalid(.analyzerFailed))
        #expect(outcome.reading == nil)
        #expect(outcome.photo == nil)
    }

    // Losing the driver before the sample is captured stops the test.
    @Test func cancelsWhenTheDriverLeavesMidBlow() async {
        let viewModel = makeViewModel(
            analyzer: SimulatedBreathAnalyzer(warmUpSeconds: 0, stageDuration: .milliseconds(10)),
            presence: SimulatedPresenceDetector(readings: [true, false, false])
        )
        await viewModel.cardWasRead("CARD-4F2A91")

        await viewModel.identityConfirmed()

        #expect(viewModel.phase == .cancelled(SampleData.driver))
    }

    // A cancelled attempt is kept, so repeated abandonment leaves a trail.
    @Test func recordsACancelledAttempt() async {
        let viewModel = makeViewModel(
            analyzer: SimulatedBreathAnalyzer(warmUpSeconds: 0, stageDuration: .milliseconds(10)),
            presence: SimulatedPresenceDetector(readings: [true, false, false])
        )
        await viewModel.cardWasRead("CARD-4F2A91")

        await viewModel.identityConfirmed()

        let cancellation = viewModel.lastCancellation
        #expect(cancellation?.verdict == .invalid(.driverLeft))
        #expect(cancellation?.reading == nil)
        #expect(cancellation?.driver == SampleData.driver)
    }

    // Retrying goes back to confirm, not idle; identity was already checked.
    @Test func retriesFromTheConfirmScreen() async {
        let viewModel = makeViewModel(
            analyzer: SimulatedBreathAnalyzer(warmUpSeconds: 0, stageDuration: .milliseconds(10)),
            presence: SimulatedPresenceDetector(readings: [true, false, false])
        )
        await viewModel.cardWasRead("CARD-4F2A91")
        await viewModel.identityConfirmed()

        viewModel.retryAfterCancellation()

        #expect(viewModel.phase == .confirming(SampleData.driver))
    }

    // The photo is taken while the driver is blowing, not before or after.
    @Test func keepsThePhotoTakenDuringTheBlow() async {
        let viewModel = makeViewModel(
            analyzer: SimulatedBreathAnalyzer(warmUpSeconds: 0, stageDuration: .zero)
        )
        await viewModel.cardWasRead("CARD-4F2A91")

        await viewModel.identityConfirmed()

        guard case let .result(outcome) = viewModel.phase else {
            Issue.record("expected a result")
            return
        }
        #expect(outcome.photo == SimulatedPhotoCapture().photo)
    }

    // A reading still stands if the camera could not produce the photo.
    @Test func clearsADriverEvenWhenThePhotoFails() async {
        let viewModel = makeViewModel(
            analyzer: SimulatedBreathAnalyzer(warmUpSeconds: 0, stageDuration: .zero),
            photos: SimulatedPhotoCapture(failure: .captureFailed)
        )
        await viewModel.cardWasRead("CARD-4F2A91")

        await viewModel.identityConfirmed()

        guard case let .result(outcome) = viewModel.phase else {
            Issue.record("expected a result")
            return
        }
        #expect(outcome.verdict == .cleared)
        #expect(outcome.photo == nil)
    }

    @Test func startsWithAnEmptyTally() {
        let viewModel = makeViewModel()

        #expect(viewModel.tally == KioskViewModel.Tally())
        #expect(viewModel.unsyncedCount == 0)
    }
}

struct SimulatedBreathAnalyzerTests {

    private func stages(_ analyzer: SimulatedBreathAnalyzer) async throws -> [BlowStage] {
        var collected: [BlowStage] = []
        for try await stage in analyzer.measure() { collected.append(stage) }
        return collected
    }

    @Test func reportsEveryStageInOrder() async throws {
        let analyzer = SimulatedBreathAnalyzer(reading: 0.04, warmUpSeconds: 1, stageDuration: .zero)

        #expect(try await stages(analyzer) == [
            .warmingUp(secondsRemaining: 1),
            .readyToBlow,
            .blowing,
            .analysing,
            .complete(0.04)
        ])
    }

    @Test func countsTheWarmUpDown() async throws {
        let analyzer = SimulatedBreathAnalyzer(warmUpSeconds: 3, stageDuration: .zero)

        let warmUp = try await stages(analyzer).prefix(3)

        #expect(Array(warmUp) == [
            .warmingUp(secondsRemaining: 3),
            .warmingUp(secondsRemaining: 2),
            .warmingUp(secondsRemaining: 1)
        ])
    }

    @Test func refusesWhenDisconnected() async {
        let analyzer = SimulatedBreathAnalyzer(isConnected: false, warmUpSeconds: 0, stageDuration: .zero)

        await #expect(throws: BreathAnalyzerError.notConnected) { try await stages(analyzer) }
    }

    @Test func refusesWhenCalibrationHasLapsed() async {
        let analyzer = SimulatedBreathAnalyzer(
            calibrationExpiresOn: .now.addingTimeInterval(-86_400),
            warmUpSeconds: 0,
            stageDuration: .zero
        )

        await #expect(throws: BreathAnalyzerError.calibrationExpired) { try await stages(analyzer) }
    }

    @Test func stopsPartwayWhenTheBlowIsInterrupted() async {
        let analyzer = SimulatedBreathAnalyzer(
            warmUpSeconds: 0,
            stageDuration: .zero,
            failsAfter: .blowing
        )

        await #expect(throws: BreathAnalyzerError.insufficientSample) { try await stages(analyzer) }
    }
}
