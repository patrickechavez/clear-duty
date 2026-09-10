//
//  AuthFlowView.swift
//  ClearDuty
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

struct AuthFlowView: View {

    let dependencies: AppDependencies

    var body: some View {
        NavigationStack {
            LoginView(viewModel: dependencies.makeLoginViewModel())
        }
    }
}
