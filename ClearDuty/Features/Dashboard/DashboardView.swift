//
//  DashboardView.swift
//  ClearDuty
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

// Placeholder shell for the signed-in app. The kiosk flow and the dispatcher
// board replace this.
struct DashboardView: View {

    let dependencies: AppDependencies

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Nothing here yet", systemImage: "hammer")
            } description: {
                Text("The kiosk and the dispatcher board go here.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await dependencies.session.signOut() }
                    } label: {
                        Text("Sign Out", comment: "Button that signs the user out")
                    }
                }
            }
        }
    }
}
