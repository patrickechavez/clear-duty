//
//  TerminalSheet.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/11/26.
//

import SwiftUI

// Everything on the terminal that is for the supervisor rather than the driver.
struct TerminalSheet: View {

    let link: AnalyzerLink

    let terminalName: String

    let onSignOut: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isConfirmingSignOut = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    analyzer
                } header: {
                    Text("Analyser", comment: "Section listing the paired breath analyser")
                }

                Section {
                    nearby
                } header: {
                    Text("In range", comment: "Section listing analysers the terminal can see")
                }

                Section {
                    signOut
                } footer: {
                    Text(terminalName)
                }
            }
            .navigationTitle(Text("Terminal", comment: "Title of the supervisor settings sheet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Text("Done", comment: "Closes the supervisor settings sheet")
                    }
                }
            }
            .task { await link.lookForDevices() }
        }
    }

    @ViewBuilder
    private var analyzer: some View {
        switch link.connection {
        case .unpaired:
            Text("No analyser paired", comment: "Kiosk message when no analyser has been chosen yet")
                .foregroundStyle(Theme.Color.secondaryText)

        case let .searching(serial):
            HStack {
                ProgressView()
                Text("Looking for \(serial)", comment: "Shown while the terminal waits for its analyser")
                    .foregroundStyle(Theme.Color.secondaryText)
            }

        case let .connected(device):
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text(device.name)
                Text(device.serial)
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.secondaryText)
            }

            Button(role: .destructive) {
                Task { await link.disconnect() }
            } label: {
                Text("Disconnect", comment: "Drops the paired analyser")
            }

        case let .unavailable(serial):
            VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                Text("\(serial) did not answer", comment: "Shown when the paired analyser cannot be reached")
                Text("It may be off, out of range, or paired to another terminal.",
                     comment: "Why the paired analyser cannot be reached")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.secondaryText)
            }

            Button {
                Task { await link.connect(to: serial) }
            } label: {
                Text("Try again", comment: "Retries connecting to the paired analyser")
            }
        }
    }

    @ViewBuilder
    private var nearby: some View {
        if link.nearby.isEmpty {
            Text("Nothing in range", comment: "Shown when no analysers can be seen")
                .foregroundStyle(Theme.Color.secondaryText)
        } else {
            ForEach(link.nearby) { device in
                Button {
                    Task { await link.connect(to: device.serial) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                            Text(device.name)
                            Text(device.serial)
                                .font(Theme.Font.caption)
                                .foregroundStyle(Theme.Color.secondaryText)
                        }

                        Spacer()

                        if device.serial == link.pairedSerial {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Theme.Color.accent)
                        }
                    }
                }
                .foregroundStyle(Theme.Color.primaryText)
            }
        }
    }

    private var signOut: some View {
        Button(role: .destructive) {
            isConfirmingSignOut = true
        } label: {
            Text("Sign out", comment: "Signs the supervisor out of the terminal")
        }
        .confirmationDialog(
            Text("Sign out of this terminal?", comment: "Confirms signing out of the kiosk"),
            isPresented: $isConfirmingSignOut,
            titleVisibility: .visible
        ) {
            Button(role: .destructive, action: onSignOut) {
                Text("Sign out", comment: "Signs the supervisor out of the terminal")
            }
        } message: {
            Text("Nobody can be tested until someone signs back in.",
                 comment: "What happens after signing out of the kiosk")
        }
    }
}

#if DEBUG

#Preview {
    TerminalSheet(
        link: .connected(to: SimulatedBreathAnalyzer()),
        terminalName: "Cubao terminal",
        onSignOut: {}
    )
}

#endif
