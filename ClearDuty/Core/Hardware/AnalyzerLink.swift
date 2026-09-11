//
//  AnalyzerLink.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/11/26.
//

import Foundation
import Observation

// Where the terminal stands with its analyser.
enum AnalyzerConnection: Equatable {
    case unpaired
    case searching(serial: String)
    case connected(AnalyzerDevice)
    case unavailable(serial: String)
}

// Remembers which analyser this terminal is paired to, across launches.
struct PairedAnalyzerStore {

    private static let key = "paired-analyzer-serial"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var serial: String? {
        get { defaults.string(forKey: Self.key) }
        nonmutating set { defaults.set(newValue, forKey: Self.key) }
    }
}

// Holds the terminal to one paired analyser rather than to whatever is nearest,
// so a depot with several terminals cannot cross-connect them.
@Observable
@MainActor
final class AnalyzerLink {

    // How long to wait for the paired analyser to answer.
    nonisolated static let connectTimeout: Duration = .seconds(15)

    private(set) var connection: AnalyzerConnection = .unpaired

    private(set) var analyzer: (any BreathAnalyzer)?

    // What the picker is showing, only filled while it is open.
    private(set) var nearby: [AnalyzerDevice] = []

    @ObservationIgnored private let hub: any AnalyzerHub

    @ObservationIgnored private let pairing: PairedAnalyzerStore

    init(hub: any AnalyzerHub, pairing: PairedAnalyzerStore = PairedAnalyzerStore()) {
        self.hub = hub
        self.pairing = pairing
    }

    var pairedSerial: String? { pairing.serial }

    // Reconnects to the analyser this terminal already knows about.
    func start() async {
        guard let serial = pairing.serial else {
            connection = .unpaired
            return
        }
        await connect(to: serial)
    }

    // Pairs with this analyser and stays with it from now on.
    func connect(to serial: String) async {
        connection = .searching(serial: serial)

        do {
            let connected = try await hub.connect(to: serial, timeout: Self.connectTimeout)
            analyzer = connected.analyzer
            pairing.serial = serial
            connection = .connected(connected.device)
        } catch {
            analyzer = nil
            connection = .unavailable(serial: serial)
        }
    }

    // Forgets the analyser too, so the terminal does not reconnect behind the
    // supervisor's back on the next launch.
    func disconnect() async {
        await hub.disconnect()
        analyzer = nil
        pairing.serial = nil
        connection = .unpaired
    }

    // Lists what is in range for as long as the picker is open.
    func lookForDevices() async {
        for await devices in hub.devices() {
            nearby = devices.sorted { ($0.signal ?? .min) > ($1.signal ?? .min) }
        }
    }
}

#if DEVELOPMENT

extension AnalyzerLink {

    // A link already holding an analyser, for previews and tests.
    static func connected(to analyzer: any BreathAnalyzer) -> AnalyzerLink {
        let link = AnalyzerLink(hub: SimulatedAnalyzerHub(analyzer: SimulatedBreathAnalyzer()))
        link.adopt(analyzer)
        return link
    }

    func adopt(_ analyzer: any BreathAnalyzer) {
        self.analyzer = analyzer
        connection = .connected(AnalyzerDevice(serial: analyzer.serial, name: "Simulated analyser"))
    }
}

#endif
