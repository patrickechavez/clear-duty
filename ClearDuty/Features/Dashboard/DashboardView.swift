//
//  DashboardView.swift
//  ClearDuty
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

// Shows the kiosk on iPad and the board on iPhone.
struct DashboardView: View {

    let dependencies: AppDependencies

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            KioskView(viewModel: dependencies.makeKioskViewModel(), onSignOut: signOut)
        } else {
            BoardPlaceholderView(onSignOut: signOut)
        }
    }

    private func signOut() {
        Task { await dependencies.session.signOut() }
    }
}

// Placeholder until the board is built.
struct BoardPlaceholderView: View {

    let onSignOut: () -> Void

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Board coming soon", systemImage: "list.clipboard")
            } description: {
                Text("Today's drivers and exceptions go here.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onSignOut) {
                        Text("Sign Out", comment: "Button that signs the user out")
                    }
                }
            }
        }
    }
}
