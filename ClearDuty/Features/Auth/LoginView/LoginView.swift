//
//  LoginView.swift
//  ClearDuty
//  Created by John Patrick Echavez on 7/29/26.
//

import SwiftUI

struct LoginView: View {

    @State private var viewModel: LoginViewModel
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, password
    }

    init(viewModel: LoginViewModel) {
        _viewModel = State(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                EmailField(
                    text: $viewModel.email,
                    error: viewModel.emailError,
                    isRequired: true
                )
                .focused($focusedField, equals: .email)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }

                PasswordField(
                    text: $viewModel.password,
                    error: viewModel.passwordError
                )
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { submit() }

                if let error = viewModel.generalError {
                    InlineErrorText(error)
                }

                AsyncButton(
                    title: Text("Sign In", comment: "Primary button on the sign-in screen"),
                    isRunning: viewModel.action.isRunning,
                    action: { await viewModel.signIn() }
                )
                .disabled(!viewModel.canSubmit)
            }
            .padding(Theme.Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(Text("Welcome", comment: "Title of the sign-in screen"))
    }

    private func submit() {
        focusedField = nil
        Task { await viewModel.signIn() }
    }
}

#if DEBUG

#Preview {
    PreviewHost { dependencies in
        NavigationStack {
            LoginView(viewModel: dependencies.makeLoginViewModel())
        }
    }
}

#endif
