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
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle:
            KioskIdleView(
                viewModel: viewModel,
                onRead: { code in Task { await viewModel.cardWasRead(code) } },
                onSignOut: onSignOut
            )

        case .looking:
            ProgressView()
                .controlSize(.large)

        case let .confirming(driver):
            KioskConfirmView(
                driver: driver,
                onConfirm: viewModel.identityConfirmed,
                onReject: viewModel.returnToIdle
            )

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
        analyzer: SimulatedBreathAnalyzer(),
        employees: MockEmployeeRepository()
    )
}

#Preview {
    KioskView(viewModel: previewViewModel(), onSignOut: {})
}

#endif
