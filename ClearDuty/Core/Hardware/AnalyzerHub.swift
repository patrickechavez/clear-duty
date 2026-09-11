//
//  AnalyzerHub.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/11/26.
//

import Foundation

// An analyser the terminal can see over Bluetooth.
struct AnalyzerDevice: Identifiable, Equatable, Sendable {

    // The serial is what ends up stamped on every test, so it is the identity.
    var id: String { serial }

    let serial: String

    let name: String

    // Signal strength, used only to sort the picker.
    var signal: Int?
}

// An analyser that answered, with the device it belongs to.
struct ConnectedAnalyzer: Sendable {

    let device: AnalyzerDevice

    let analyzer: any BreathAnalyzer
}

enum AnalyzerHubError: Error, Equatable {
    case notFound
    case connectionFailed
}

// Finds analysers in range and connects to one of them.
protocol AnalyzerHub: Sendable {

    // Emits what is in range, updated as more units answer.
    func devices() -> AsyncStream<[AnalyzerDevice]>

    // Connects to one analyser by serial, never to whatever is nearest.
    func connect(to serial: String, timeout: Duration) async throws -> ConnectedAnalyzer

    func disconnect() async
}

// Reports a fixed set of analysers, for previews and tests.
struct SimulatedAnalyzerHub: AnalyzerHub {

    var available: [AnalyzerDevice] = [.simulated, .spare]

    var analyzer = SimulatedBreathAnalyzer()

    var failure: AnalyzerHubError?

    func devices() -> AsyncStream<[AnalyzerDevice]> {
        AsyncStream { continuation in
            continuation.yield(available)
            continuation.finish()
        }
    }

    func connect(to serial: String, timeout: Duration) async throws -> ConnectedAnalyzer {
        if let failure { throw failure }

        guard let device = available.first(where: { $0.serial == serial }) else {
            throw AnalyzerHubError.notFound
        }

        var connected = analyzer
        connected.serial = device.serial
        return ConnectedAnalyzer(device: device, analyzer: connected)
    }

    func disconnect() async {}
}

extension AnalyzerDevice {

    static let simulated = AnalyzerDevice(serial: "SIM-0001", name: "Simulated analyser", signal: -42)

    static let spare = AnalyzerDevice(serial: "SIM-0002", name: "Simulated analyser", signal: -71)
}
