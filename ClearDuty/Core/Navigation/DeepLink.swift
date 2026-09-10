//
//  DeepLink.swift
//  ClearDuty
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation
import os

enum DeepLink: Equatable, Sendable {
    case home

    var isPublic: Bool { false }

    var path: String {
        switch self {
        case .home: "/home"
        }
    }
}

struct DeepLinkParser: Sendable {

    private let scheme: String
    private let universalLinkHosts: Set<String>

    init(
        scheme: String = APIConfig.urlScheme,
        universalLinkHosts: Set<String> = ["example.com", "www.example.com"]
    ) {
        self.scheme = scheme.lowercased()
        self.universalLinkHosts = universalLinkHosts
    }

    func parse(_ url: URL) -> DeepLink? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            return nil
        }

        let incomingScheme = components.scheme?.lowercased()

        let segments: [String]
        switch incomingScheme {
        case scheme:
            segments = ([components.host] + components.path.split(separator: "/").map(String.init))
                .compactMap { $0 }
                .filter { !$0.isEmpty }

        case "https", "http":
            guard let host = components.host?.lowercased(), universalLinkHosts.contains(host) else {
                return nil
            }
            segments = components.path.split(separator: "/").map(String.init)

        default:
            return nil
        }

        return route(for: segments, query: components.queryItems ?? [])
    }

    private func route(for segments: [String], query: [URLQueryItem]) -> DeepLink? {
        switch segments.first?.lowercased() {
        case nil, "home", "":
            return .home

        default:
            let path = segments.joined(separator: "/")
            AppLogger.navigation.breadcrumb("Unrecognised deep link path: \(path)")
            return nil
        }
    }

    func parse(notificationPayload: [AnyHashable: Any]) -> DeepLink? {
        guard let raw = (payloadValue(notificationPayload, "deep_link")
            ?? payloadValue(notificationPayload, "url")
            ?? payloadValue(notificationPayload, "link")),
            let url = URL(string: raw)
        else {
            return nil
        }
        return parse(url)
    }

    private func payloadValue(_ payload: [AnyHashable: Any], _ key: String) -> String? {
        if let value = payload[key] as? String { return value }

        if let nested = payload["data"] as? [AnyHashable: Any] {
            return nested[key] as? String
        }
        return nil
    }
}
