//
//  KioskConfirmView.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/11/26.
//

import SwiftUI

// Asks the supervisor whether the stored photo matches the person present.
struct KioskConfirmView: View {

    let driver: Employee

    let onConfirm: () -> Void

    let onReject: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.xxl) {
            Spacer()

            HStack(spacing: Theme.Spacing.xxl) {
                photo

                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(driver.fullName)
                        .font(Theme.Font.screenTitle)

                    Text(driver.employeeNo)
                        .font(Theme.Font.secondary)
                        .foregroundStyle(Theme.Color.secondaryText)

                    StatusPill(
                        text: Text("Active driver", comment: "Shown when a scanned driver may be tested"),
                        tone: .success,
                        systemImage: "checkmark"
                    )
                    .padding(.top, Theme.Spacing.xs)
                }
            }

            Text("Is this the person in front of you?",
                 comment: "Asks the supervisor to check the photo against the driver")
                .font(Theme.Font.sectionTitle)
                .foregroundStyle(Theme.Color.secondaryText)

            Spacer()

            HStack(spacing: Theme.Spacing.lg) {
                Button(role: .cancel, action: onReject) {
                    Text("Not this person", comment: "Rejects a scanned card as the wrong driver")
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.kioskTapTarget)
                }
                .buttonStyle(.bordered)

                Button(action: onConfirm) {
                    Text("Yes, start test", comment: "Confirms identity and begins the breath test")
                        .frame(maxWidth: .infinity, minHeight: Theme.Size.kioskTapTarget)
                }
                .buttonStyle(.borderedProminent)
            }
            .controlSize(.large)
            .font(Theme.Font.sectionTitle)
            .padding(.horizontal, Theme.Spacing.xxl)
            .padding(.bottom, Theme.Spacing.xxl)
        }
    }

    private var photo: some View {
        CachedAsyncImage(url: driver.photoPath.flatMap(URL.init(string:))) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            Text(driver.initials)
                .font(Theme.Font.display)
                .foregroundStyle(Theme.Color.secondaryText)
        }
        .frame(width: 200, height: 200)
        .background(Theme.Color.secondaryBackground)
        .clipShape(Circle())
    }
}

// Shown briefly when a card does not resolve to a testable driver.
struct KioskRejectedView: View {

    let rejection: KioskViewModel.CardRejection

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Image(systemName: "xmark.circle")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Color.danger)

            title
                .font(Theme.Font.screenTitle)
                .multilineTextAlignment(.center)

            Text("See your supervisor.", comment: "What a driver should do after a refused card")
                .font(Theme.Font.sectionTitle)
                .foregroundStyle(Theme.Color.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: Text {
        switch rejection {
        case .unrecognised:
            Text("Card not recognised", comment: "Shown when a scanned card is not in the roster")
        case .notCleared:
            Text("Not cleared to test", comment: "Shown when a scanned card may not be tested")
        }
    }
}

#if DEBUG

#Preview("Confirm") {
    KioskConfirmView(driver: SampleData.driver, onConfirm: {}, onReject: {})
}

#Preview("Card not recognised") {
    KioskRejectedView(rejection: .unrecognised)
}

#Preview("Not cleared") {
    KioskRejectedView(rejection: .notCleared)
}

#endif
