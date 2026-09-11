//
//  PresenceMonitorTests.swift
//  ClearDutyTests
//

import Foundation
import Testing
@testable import ClearDuty

@MainActor
struct PresenceMonitorTests {

    private let start = Date(timeIntervalSince1970: 1_000_000)

    @Test func startsPresent() {
        let monitor = PresenceMonitor()

        #expect(monitor.isPresent)
        #expect(!monitor.wasLost)
    }

    // A brief gap is the detector blinking, not the driver leaving.
    @Test func toleratesAShortGap() {
        let monitor = PresenceMonitor()

        monitor.update(isPresent: false, at: start)
        monitor.update(isPresent: true, at: start.addingTimeInterval(1))

        #expect(!monitor.wasLost)
        #expect(monitor.isPresent)
    }

    @Test func flagsAGapPastTheTolerance() {
        let monitor = PresenceMonitor()

        monitor.update(isPresent: false, at: start)
        monitor.update(isPresent: false, at: start.addingTimeInterval(2))

        #expect(monitor.wasLost)
    }

    // Once lost, the flag stays set even if the driver comes back.
    @Test func keepsTheFlagAfterTheDriverReturns() {
        let monitor = PresenceMonitor()

        monitor.update(isPresent: false, at: start)
        monitor.update(isPresent: false, at: start.addingTimeInterval(3))
        monitor.update(isPresent: true, at: start.addingTimeInterval(4))

        #expect(monitor.wasLost)
        #expect(monitor.isPresent)
    }

    @Test func restartsTheClockAfterEachReturn() {
        let monitor = PresenceMonitor()

        monitor.update(isPresent: false, at: start)
        monitor.update(isPresent: true, at: start.addingTimeInterval(1))
        monitor.update(isPresent: false, at: start.addingTimeInterval(2))
        monitor.update(isPresent: false, at: start.addingTimeInterval(3))

        #expect(!monitor.wasLost)
    }

    // The blow waits for the driver rather than starting on an empty frame.
    @Test func waitsUntilTheDriverArrives() async {
        let monitor = PresenceMonitor()
        monitor.update(isPresent: false, at: start)

        async let arrived = monitor.waitForArrival(within: .seconds(10))
        await Task.yield()
        monitor.update(isPresent: true, at: start.addingTimeInterval(1))

        #expect(await arrived)
    }

    // A driver who never steps in front of the camera does not hold the kiosk.
    @Test func givesUpAfterTheLimit() async {
        let monitor = PresenceMonitor()
        monitor.update(isPresent: false, at: start)

        #expect(await !monitor.waitForArrival(within: .milliseconds(20)))
    }

    // Nobody is going to arrive once the camera stops reporting.
    @Test func givesUpWhenTheDetectorStops() async {
        let monitor = PresenceMonitor()
        monitor.update(isPresent: false, at: start)

        async let arrived = monitor.waitForArrival(within: .seconds(10))
        await Task.yield()
        monitor.detectorFinished()

        #expect(await !arrived)
    }

    @Test func clearsOnReset() {
        let monitor = PresenceMonitor()
        monitor.update(isPresent: false, at: start)
        monitor.update(isPresent: false, at: start.addingTimeInterval(5))

        monitor.reset()

        #expect(!monitor.wasLost)
        #expect(monitor.isPresent)
    }
}
