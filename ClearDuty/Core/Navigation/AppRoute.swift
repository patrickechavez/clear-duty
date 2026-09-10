//
//  AppRoute.swift
//  ClearDuty
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

protocol AppRoute: Hashable, Codable, Sendable, Identifiable {}

// Lets a route bind straight to .sheet(item:) and .fullScreenCover(item:).
extension AppRoute {
    var id: Self { self }
}
