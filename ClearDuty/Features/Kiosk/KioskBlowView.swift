//
//  KioskBlowView.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/11/26.
//

import SwiftUI

// Shown while waiting for the driver to step in front of the camera.
struct KioskPresenceView: View {

    let driver: Employee

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "person.crop.rectangle")
                .font(.system(size: 72))
                .foregroundStyle(Theme.Color.accent)

            Text("Step in front of the camera",
                 comment: "Asks the driver to move into shot before the test starts")
                .font(Theme.Font.screenTitle)

            Text(driver.fullName)
                .font(Theme.Font.sectionTitle)
                .foregroundStyle(Theme.Color.secondaryText)

            Spacer()
        }
        .multilineTextAlignment(.center)
    }
}

// Shown while the analyser is taking a reading, one screen per stage.
struct KioskBlowView: View {

    let driver: Employee

    let stage: BlowStage

    var body: some View {
        VStack(spacing: Theme.Spacing.xl) {
            Spacer()

            Text(driver.fullName)
                .font(Theme.Font.secondary)
                .foregroundStyle(Theme.Color.secondaryText)

            indicator
                .frame(height: 160)

            title
                .font(Theme.Font.screenTitle)

            detail
                .font(Theme.Font.sectionTitle)
                .foregroundStyle(Theme.Color.secondaryText)

            // The still is taken during the blow, so the screen says so as it happens.
            Label {
                Text("Photo being taken", comment: "Shown while the kiosk captures a photo during the blow")
            } icon: {
                Image(systemName: "camera")
            }
            .font(Theme.Font.caption)
            .foregroundStyle(Theme.Color.tertiaryText)
            .opacity(stage == .blowing ? 1 : 0)
            .padding(.top, Theme.Spacing.lg)

            Spacer()
        }
        .multilineTextAlignment(.center)
    }

    @ViewBuilder
    private var indicator: some View {
        switch stage {
        case let .warmingUp(remaining):
            Text(remaining, format: .number)
                .font(Theme.Font.display)
                .monospacedDigit()
                .foregroundStyle(Theme.Color.accent)
        case .readyToBlow:
            Image(systemName: "wind")
                .font(.system(size: 88))
                .foregroundStyle(Theme.Color.accent)
        case .blowing, .analysing, .complete:
            ProgressView()
                .controlSize(.extraLarge)
                .scaleEffect(2)
        }
    }

    private var title: Text {
        switch stage {
        case .warmingUp:
            Text("Warming up", comment: "Shown while the analyser prepares")
        case .readyToBlow:
            Text("Blow now", comment: "Tells the driver to start blowing")
        case .blowing:
            Text("Keep blowing", comment: "Tells the driver to keep going")
        case .analysing, .complete:
            Text("Analysing", comment: "Shown while the analyser works out the reading")
        }
    }

    private var detail: Text {
        switch stage {
        case .warmingUp:
            Text("Do not blow yet", comment: "Warns the driver not to blow during warm-up")
        case .readyToBlow:
            Text("Steady breath", comment: "How to blow into the analyser")
        case .blowing:
            Text("Keep going until the tone stops", comment: "How long to keep blowing")
        case .analysing, .complete:
            Text("You can stop now", comment: "Tells the driver the blow has ended")
        }
    }
}

// Shown when the driver left the camera before the sample was captured.
struct KioskCancelledView: View {

    let driver: Employee

    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundStyle(Theme.Color.warning)

            Text("Test stopped", comment: "Shown when the driver left the camera during the test")
                .font(Theme.Font.screenTitle)

            Text("Stay in front of the camera and try again.",
                 comment: "What a driver should do after leaving the camera")
                .font(Theme.Font.sectionTitle)
                .foregroundStyle(Theme.Color.secondaryText)

            Text(driver.fullName)
                .font(Theme.Font.secondary)
                .foregroundStyle(Theme.Color.tertiaryText)

            Spacer()

            Button(action: onRetry) {
                Text("Try again", comment: "Restarts a cancelled test")
                    .frame(maxWidth: 360, minHeight: Theme.Size.kioskTapTarget)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .font(Theme.Font.sectionTitle)
            .padding(.bottom, Theme.Spacing.xxl)
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
        case .invalid(.analyzerFailed):
            Text("Test not completed", comment: "Shown when the analyser produced no usable reading")
        case .invalid(.driverLeft):
            Text("Test stopped", comment: "Shown when the driver left the camera during the test")
        }
    }

    private var detail: Text {
        switch outcome.verdict {
        case .cleared:
            Text("Valid for this shift", comment: "How long a passed test lasts")
        case .blocked:
            Text("See your supervisor.", comment: "What a driver should do after failing")
        case .invalid(.analyzerFailed):
            Text("Try again.", comment: "What a driver should do after an unusable sample")
        case .invalid(.driverLeft):
            Text("Stay in front of the camera and try again.",
                 comment: "What a driver should do after leaving the camera")
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

#Preview("Waiting for the driver") {
    KioskPresenceView(driver: SampleData.driver)
}

#Preview("Warming up") {
    KioskBlowView(driver: SampleData.driver, stage: .warmingUp(secondsRemaining: 3))
}

#Preview("Blow now") {
    KioskBlowView(driver: SampleData.driver, stage: .readyToBlow)
}

#Preview("Keep blowing") {
    KioskBlowView(driver: SampleData.driver, stage: .blowing)
}

#Preview("Analysing") {
    KioskBlowView(driver: SampleData.driver, stage: .analysing)
}

#Preview("Cancelled") {
    KioskCancelledView(driver: SampleData.driver, onRetry: {})
}

#Preview("Cleared") {
    KioskResultView(outcome: outcome(.cleared, reading: 0))
}

#Preview("Not cleared") {
    KioskResultView(outcome: outcome(.blocked, reading: 0.04))
}

#Preview("Invalid") {
    KioskResultView(outcome: outcome(.invalid(.analyzerFailed), reading: nil))
}

#endif
