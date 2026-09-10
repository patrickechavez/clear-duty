//
//  StatusPill.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/10/26.
//

import SwiftUI

// A short state label on a tinted capsule. Used for duty status, sync state and
// device health, which is most of what the kiosk and the board report.
struct StatusPill: View {

    enum Tone {
        case neutral
        case success
        case warning
        case danger

        var foreground: Color {
            switch self {
            case .neutral: Theme.Color.secondaryText
            case .success: Theme.Color.success
            case .warning: Theme.Color.warning
            case .danger: Theme.Color.danger
            }
        }

        var background: Color {
            switch self {
            case .neutral: Theme.Color.placeholder
            case .success: Theme.Color.success.opacity(0.12)
            case .warning: Theme.Color.warning.opacity(0.12)
            case .danger: Theme.Color.danger.opacity(0.12)
            }
        }
    }

    let text: Text

    var tone: Tone = .neutral

    var systemImage: String?

    var body: some View {
        HStack(spacing: Theme.Spacing.xs) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            text
        }
        .font(Theme.Font.caption)
        .foregroundStyle(tone.foreground)
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.xs)
        .background(tone.background, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG

#Preview {
    VStack(alignment: .leading, spacing: Theme.Spacing.md) {
        StatusPill(text: Text(verbatim: "Cleared"), tone: .success, systemImage: "checkmark")
        StatusPill(text: Text(verbatim: "Pending"), tone: .warning)
        StatusPill(text: Text(verbatim: "Blocked"), tone: .danger, systemImage: "xmark")
        StatusPill(text: Text(verbatim: "3 waiting to sync"), tone: .neutral, systemImage: "icloud.slash")
    }
    .padding()
}

#endif
