//
//  SupabaseAPIKeyInterceptor.swift
//  ClearDuty
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

// Required on every request: apikey identifies the project, Authorization the user.
struct SupabaseAPIKeyInterceptor: RequestInterceptor {

    private let anonKey: String

    init(anonKey: String) {
        self.anonKey = anonKey
    }

    func adapt(_ request: URLRequest, for endpoint: Endpoint) async throws -> URLRequest {
        var request = request
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        return request
    }
}
