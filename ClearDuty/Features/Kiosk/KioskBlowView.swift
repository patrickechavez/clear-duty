//
//  KioskBlowView.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/11/26.
//

import SwiftUI

// Shown while the analyser is taking a reading.
struct KioskBlowView: View {

    let driver: Employee

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Text(driver.fullName)
                .font(Theme.Font.secondary)
                .foregroundStyle(Theme.Color.secondaryText)

            ProgressView()
                .controlSize(.extraLarge)
                .scaleEffect(2)
                .frame(height: 160)

            Text("Blow steadily", comment: "Kiosk instruction while the analyser reads")
                .font(Theme.Font.screenTitle)

            Text("Keep going until the tone stops",
                 comment: "How long to keep blowing into the analyser")
                .font(Theme.Font.sectionTitle)
                .foregroundStyle(Theme.Color.secondaryText)

            Label {
                Text("Recording", comment: "Shown while the kiosk captures a photo during the blow")
            } icon: {
                Image(systemName: "camera")
            }
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.tertiaryText)
            .padding(.top, Theme.Spacing.lg)

            Spacer()
        }
        .multilineTextAlignment(.center)
    }
}

// Shown once a reading is in, then the kiosk returns to idle on its own.
struct KioskResultView: View {

    let outcome: KioskViewModel.Outcome

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Text(outcome.driver.fullName)
                .font(Theme.Font.secondary)
                .foregroundStyle(Theme.Color.secondaryText)

            reading

            verdict
                .font(Theme.Font.screenTitle)
                .foregroundStyle(tone)

            detail
                .font(Theme.Font.sectionTitle)
                .foregroundStyle(Theme.Color.secondaryText)

            Spacer()
        }
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var reading: some View {
        if let value = outcome.reading {
            VStack(spacing: 0) {
                Text(value, format: .number.precision(.fractionLength(2)))
                    .font(Theme.Font.display)
                    .monospacedDigit()

                Text("percent BAC", comment: "Unit shown under a breath test reading")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.Color.secondaryText)
            }
            .foregroundStyle(tone)
            .padding(.vertical, Theme.Spacing.md)
        } else {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundStyle(tone)
                .padding(.vertical, Theme.Spacing.md)
        }
    }

    private var verdict: Text {
        switch outcome.verdict {
        case .cleared:
            Text("Cleared for duty", comment: "Shown when a driver passes the breath test")
        case .blocked:
            Text("Not cleared", comment: "Shown when a driver fails the breath test")
        case .invalid:
            Text("Test not completed", comment: "Shown when the analyser produced no usable reading")
        }
    }

    private var detail: Text {
        switch outcome.verdict {
        case .cleared:
            Text("Valid for this shift", comment: "How long a passed test lasts")
        case .blocked:
            Text("See your supervisor.", comment: "What a driver should do after failing")
        case .invalid:
            Text("Try again.", comment: "What a driver should do after an unusable sample")
        }
    }

    // A failure is stated plainly rather than shouted; the screen is semi-public.
    private var tone: Color {
        switch outcome.verdict {
        case .cleared: Theme.Color.success
        case .blocked: Theme.Color.danger
        case .invalid: Theme.Color.warning
        }
    }
}

#if DEBUG

@MainActor
private func outcome(_ verdict: KioskViewModel.Verdict, reading: Double?) -> KioskViewModel.Outcome {
    KioskViewModel.Outcome(
        driver: SampleData.driver,
        reading: reading,
        threshold: KioskViewModel.threshold,
        verdict: verdict
    )
}

#Preview("Blowing") {
    KioskBlowView(driver: SampleData.driver)
}

#Preview("Cleared") {
    KioskResultView(outcome: outcome(.cleared, reading: 0))
}

#Preview("Not cleared") {
    KioskResultView(outcome: outcome(.blocked, reading: 0.04))
}

#Preview("Invalid") {
    KioskResultView(outcome: outcome(.invalid, reading: nil))
}

#endif
