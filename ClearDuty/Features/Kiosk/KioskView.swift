//
//  KioskView.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/11/26.
//

import SwiftUI

// Hosts the kiosk phases; each one replaces the last in place.
struct KioskView: View {

    @State private var viewModel: KioskViewModel

    let onSignOut: () -> Void

    // How long a refused card stays on screen before the kiosk resets.
    private let rejectionDuration: Duration = .seconds(4)

    // Long enough for the driver to read the verdict, short enough for a queue.
    private let resultDuration: Duration = .seconds(6)

    init(viewModel: KioskViewModel, onSignOut: @escaping () -> Void) {
        _viewModel = State(wrappedValue: viewModel)
        self.onSignOut = onSignOut
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.Color.background)
            .animation(Theme.Animation.standard, value: viewModel.phase)
            .persistentSystemOverlays(.hidden)
            .task { await viewModel.link.start() }
            .task { await readCards() }
            .onDisappear { viewModel.camera?.stop() }
    }

    // The camera runs for as long as the kiosk is on screen.
    private func readCards() async {
        guard let camera = viewModel.camera else { return }
        camera.start()

        for await code in camera.codes() {
            await viewModel.cardWasRead(code)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle:
            KioskIdleView(viewModel: viewModel, onSignOut: onSignOut)

        case .looking:
            ProgressView()
                .controlSize(.large)

        case let .confirming(driver):
            KioskConfirmView(
                driver: driver,
                onConfirm: { Task { await viewModel.identityConfirmed() } },
                onReject: viewModel.returnToIdle
            )

        case let .awaitingPresence(driver):
            KioskPresenceView(driver: driver)

        case let .blowing(driver, stage):
            KioskBlowView(driver: driver, stage: stage)

        case let .cancelled(driver):
            KioskCancelledView(driver: driver, onRetry: viewModel.retryAfterCancellation)

        case let .result(outcome):
            KioskResultView(outcome: outcome)
                .task {
                    try? await Task.sleep(for: resultDuration)
                    viewModel.returnToIdle()
                }

        case let .rejected(rejection):
            KioskRejectedView(rejection: rejection)
                .task {
                    try? await Task.sleep(for: rejectionDuration)
                    viewModel.returnToIdle()
                }
        }
    }
}

#if DEBUG

@MainActor
private func previewViewModel() -> KioskViewModel {
    KioskViewModel(
        terminalName: "Cubao terminal",
        link: .connected(to: SimulatedBreathAnalyzer()),
        employees: MockEmployeeRepository()
    )
}

#Preview {
    KioskView(viewModel: previewViewModel(), onSignOut: {})
}

#endif
