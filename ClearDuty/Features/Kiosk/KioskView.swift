//
//  KioskView.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/11/26.
//

import SwiftUI
import os

// Hosts the kiosk phases; later ones replace the idle screen in place.
struct KioskView: View {

    @State private var viewModel: KioskViewModel

    let onSignOut: () -> Void

    init(viewModel: KioskViewModel, onSignOut: @escaping () -> Void) {
        _viewModel = State(wrappedValue: viewModel)
        self.onSignOut = onSignOut
    }

    var body: some View {
        KioskIdleView(viewModel: viewModel, onRead: cardWasRead, onSignOut: onSignOut)
            .background(Theme.Color.background)
            .persistentSystemOverlays(.hidden)
    }

    // Logs the scan until the employee lookup exists.
    private func cardWasRead(_ code: String) {
        AppLogger.data.breadcrumb("Card read at \(viewModel.terminalName)")
    }
}

#if DEBUG

#Preview {
    KioskView(
        viewModel: KioskViewModel(terminalName: "Cubao terminal", analyzer: SimulatedBreathAnalyzer()),
        onSignOut: {}
    )
}

#endif
