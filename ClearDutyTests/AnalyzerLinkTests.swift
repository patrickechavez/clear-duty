//
//  AnalyzerLinkTests.swift
//  ClearDutyTests
//

import Foundation
import Testing
@testable import ClearDuty

@MainActor
struct AnalyzerLinkTests {

    private func makeStore() -> PairedAnalyzerStore {
        PairedAnalyzerStore(defaults: UserDefaults(suiteName: UUID().uuidString) ?? .standard)
    }

    private func makeLink(
        hub: SimulatedAnalyzerHub = SimulatedAnalyzerHub(),
        store: PairedAnalyzerStore
    ) -> AnalyzerLink {
        AnalyzerLink(hub: hub, pairing: store)
    }

    @Test func startsWithNothingPaired() async {
        let link = makeLink(store: makeStore())

        await link.start()

        #expect(link.connection == .unpaired)
        #expect(link.analyzer == nil)
    }

    @Test func remembersTheAnalyserItPairedWith() async {
        let store = makeStore()
        let link = makeLink(store: store)

        await link.connect(to: AnalyzerDevice.spare.serial)

        #expect(link.connection == .connected(.spare))
        #expect(store.serial == AnalyzerDevice.spare.serial)
        #expect(link.analyzer?.serial == AnalyzerDevice.spare.serial)
    }

    // A nearer analyser belonging to another terminal must not be picked up.
    @Test func reconnectsToThePairedAnalyserRatherThanTheNearest() async {
        let store = makeStore()
        store.serial = AnalyzerDevice.spare.serial

        let link = makeLink(store: store)
        await link.start()

        #expect(link.connection == .connected(.spare))
    }

    @Test func reportsAPairedAnalyserThatDoesNotAnswer() async {
        let store = makeStore()
        store.serial = "SIM-9999"

        let link = makeLink(store: store)
        await link.start()

        #expect(link.connection == .unavailable(serial: "SIM-9999"))
        #expect(link.analyzer == nil)
    }

    @Test func reportsAFailedConnection() async {
        let hub = SimulatedAnalyzerHub(failure: .connectionFailed)
        let link = makeLink(hub: hub, store: makeStore())

        await link.connect(to: AnalyzerDevice.simulated.serial)

        #expect(link.connection == .unavailable(serial: AnalyzerDevice.simulated.serial))
    }

    // Forgetting the serial too, so the next launch does not reconnect silently.
    @Test func forgetsTheAnalyserOnDisconnect() async {
        let store = makeStore()
        let link = makeLink(store: store)
        await link.connect(to: AnalyzerDevice.simulated.serial)

        await link.disconnect()

        #expect(link.connection == .unpaired)
        #expect(link.analyzer == nil)
        #expect(store.serial == nil)
    }

    @Test func listsWhatIsInRangeStrongestFirst() async {
        let link = makeLink(store: makeStore())

        await link.lookForDevices()

        #expect(link.nearby == [.simulated, .spare])
    }
}
