//
//  KioskIdleView.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/11/26.
//

import SwiftUI

// The kiosk screen shown between drivers.
struct KioskIdleView: View {

    let viewModel: KioskViewModel

    let onSignOut: () -> Void

    @State private var isShowingTerminal = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            let state = viewModel.state(at: context.date)

            VStack(spacing: 0) {
                content(for: state)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                footer
            }
            .sheet(isPresented: $isShowingTerminal) {
                TerminalSheet(
                    link: viewModel.link,
                    terminalName: viewModel.terminalName,
                    onSignOut: onSignOut
                )
            }
        }
    }

    @ViewBuilder
    private func content(for state: KioskViewModel.State) -> some View {
        switch state {
        case .scanning:
            scanning
        case let .fault(fault):
            faulted(fault)
        }
    }

    @ViewBuilder
    private var scanning: some View {
        #if DEVELOPMENT
        if AppEnvironment.isDemo {
            demoScanner
        } else {
            cameraScanner
        }
        #else
        cameraScanner
        #endif
    }

    // Preview sits at the top, next to the camera, in the camera's own 4:3.
    private var cameraScanner: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            CameraPreview(camera: viewModel.camera)
                .aspectRatio(4 / 3, contentMode: .fit)
                .containerRelativeFrame(.horizontal) { width, _ in
                    min(width * 0.5, Theme.Size.kioskPreviewMaxWidth)
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.md))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.md)
                        .strokeBorder(Theme.Color.accent, lineWidth: 3)
                }
                .padding(.top, Theme.Spacing.xl)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Hold your ID up to the camera", comment: "Kiosk instruction while scanning")
                    .font(Theme.Font.sectionTitle)

                Text("QR code facing the screen, about 20 cm away",
                     comment: "Which side of the ID to show and how close to hold it")
                    .font(Theme.Font.secondary)
                    .foregroundStyle(Theme.Color.secondaryText)
            }
            .multilineTextAlignment(.center)
        }
    }

    #if DEVELOPMENT

    // A card the demo can scan without a camera.
    private struct DemoCard {
        let name: String
        let code: String

        static let all = [
            DemoCard(name: "Active driver", code: "CARD-4F2A91"),
            DemoCard(name: "Suspended driver", code: "CARD-0FA983"),
            DemoCard(name: "Staff card", code: "CARD-S014"),
            DemoCard(name: "Unknown card", code: "CARD-NOTREAL")
        ]
    }

    // The simulator has no camera, so cards are handed over by hand.
    private var demoScanner: some View {
        VStack(spacing: Theme.Spacing.xl) {
            VStack(spacing: Theme.Spacing.sm) {
                Text(verbatim: "Pick a card to scan")
                    .font(Theme.Font.sectionTitle)

                Text(verbatim: "The simulator has no camera, so the reader is stood in for")
                    .font(Theme.Font.secondary)
                    .foregroundStyle(Theme.Color.secondaryText)
            }
            .multilineTextAlignment(.center)

            VStack(spacing: Theme.Spacing.md) {
                ForEach(DemoCard.all, id: \.code) { card in
                    Button {
                        Task { await viewModel.cardWasRead(card.code) }
                    } label: {
                        Text(verbatim: card.name)
                            .frame(maxWidth: 320, minHeight: Theme.Size.minimumTapTarget)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    #endif

    private func faulted(_ fault: KioskViewModel.Fault) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(Theme.Color.danger)

            faultTitle(fault)
                .font(Theme.Font.sectionTitle)

            Text("Testing cannot start. Tell your supervisor.",
                 comment: "What to do when the terminal cannot accept tests")
                .font(Theme.Font.secondary)
                .foregroundStyle(Theme.Color.secondaryText)

            Button {
                isShowingTerminal = true
            } label: {
                Text("Set up the analyser", comment: "Opens the analyser settings from the fault screen")
                    .frame(maxWidth: 360, minHeight: Theme.Size.kioskTapTarget)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(Theme.Font.sectionTitle)
            .padding(.top, Theme.Spacing.lg)
        }
        .multilineTextAlignment(.center)
    }

    private func faultTitle(_ fault: KioskViewModel.Fault) -> Text {
        switch fault {
        case .analyzerUnpaired:
            Text("No analyser paired", comment: "Kiosk message when no analyser has been chosen yet")
        case .analyzerDisconnected:
            Text("Analyser not connected", comment: "Kiosk message when the breath analyser is unreachable")
        case .calibrationExpired:
            Text("Analyser calibration has expired", comment: "Kiosk message when the analyser is out of date")
        }
    }

    @ViewBuilder
    private var analyzerStatus: some View {
        if let analyzer = viewModel.analyzer {
            let calibration = analyzer.calibrationExpiresOn.formatted(.dateTime.day().month().year())
            Text("\(analyzer.serial), calibrated to \(calibration)",
                 comment: "Analyser serial number and calibration expiry")
        } else {
            Text("No analyser connected", comment: "Shown in the footer while nothing is paired")
        }
    }

    private var footer: some View {
        HStack(spacing: Theme.Spacing.xl) {
            Text(viewModel.terminalName)

            StatusPill(text: Text("\(viewModel.tally.cleared) cleared",
                                  comment: "Count of drivers cleared to drive"), tone: .success)
            StatusPill(text: Text("\(viewModel.tally.pending) pending",
                                  comment: "Count of drivers not yet tested"))
            StatusPill(text: Text("\(viewModel.tally.blocked) blocked",
                                  comment: "Count of drivers stopped from driving"), tone: .danger)

            if viewModel.unsyncedCount > 0 {
                StatusPill(
                    text: Text("\(viewModel.unsyncedCount) waiting to sync",
                               comment: "Number of results not yet uploaded"),
                    systemImage: "icloud.slash"
                )
            }

            Spacer()

            analyzerStatus
        }
        .font(Theme.Font.caption)
        .foregroundStyle(Theme.Color.secondaryText)
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(Theme.Color.secondaryBackground)
        // Long press opens the controls that are not for drivers.
        .onLongPressGesture(minimumDuration: 2) { isShowingTerminal = true }
    }
}

#if DEBUG

@MainActor
private func previewViewModel(
    analyzer: SimulatedBreathAnalyzer = SimulatedBreathAnalyzer()
) -> KioskViewModel {
    KioskViewModel(
        terminalName: "Cubao terminal",
        link: .connected(to: analyzer),
        employees: MockEmployeeRepository()
    )
}

#Preview("Scanning") {
    KioskIdleView(viewModel: previewViewModel(), onSignOut: {})
}

#Preview("Analyser offline") {
    KioskIdleView(
        viewModel: previewViewModel(analyzer: SimulatedBreathAnalyzer(isConnected: false)),
        onSignOut: {}
    )
}

#endif
