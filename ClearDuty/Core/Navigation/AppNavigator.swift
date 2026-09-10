//
//  AppNavigator.swift
//  ClearDuty
//  Created by John Patrick Echavez on 7/29/26.
//

import Observation
import SwiftUI
import os

@Observable
@MainActor
final class AppNavigator {

    private(set) var pendingLink: DeepLink?

    @ObservationIgnored private let parser: DeepLinkParser

    init(parser: DeepLinkParser = DeepLinkParser()) {
        self.parser = parser
    }

    @discardableResult
    func open(_ url: URL, isAuthenticated: Bool) -> Bool {
        guard let link = parser.parse(url) else {
            AppLogger.navigation.breadcrumb("Ignoring unhandled URL: \(url.absoluteString)")
            return false
        }
        open(link, isAuthenticated: isAuthenticated)
        return true
    }

    @discardableResult
    func open(notification payload: [AnyHashable: Any], isAuthenticated: Bool) -> Bool {
        guard let link = parser.parse(notificationPayload: payload) else { return false }
        open(link, isAuthenticated: isAuthenticated)
        return true
    }

    func open(_ link: DeepLink, isAuthenticated: Bool) {
        guard isAuthenticated || link.isPublic else {

            AppLogger.navigation.breadcrumb("Deferring deep link until signed in: \(link.path)")
            pendingLink = link
            return
        }

        apply(link)
    }

    func resumePendingLink() {
        guard let link = pendingLink else { return }
        pendingLink = nil
        AppLogger.navigation.breadcrumb("Resuming deferred deep link: \(link.path)")
        apply(link)
    }

    func clearPendingLink() {
        pendingLink = nil
    }

    func reset() {
        pendingLink = nil
    }

    // ClearDuty has no routed screens yet, so a link only has to survive the
    // sign-in gate until there is somewhere to send it.
    private func apply(_ link: DeepLink) {
        AppLogger.navigation.breadcrumb("Deep link has no destination yet: \(link.path)")
    }
}
