//
//  DashboardView.swift
//  ClearDuty
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

// The terminal is the whole app once a supervisor is signed in.
struct DashboardView: View {

    let dependencies: AppDependencies

    var body: some View {
        KioskView(viewModel: dependencies.makeKioskViewModel(), onSignOut: signOut)
    }

    private func signOut() {
        Task { await dependencies.session.signOut() }
    }
}
