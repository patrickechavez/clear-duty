//
//  EmployeeRepository.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/11/26.
//

import Foundation

// Why a scanned card did not produce a testable driver.
enum CardLookupFailure: Error, Equatable {
    case unknownCard
    case notADriver
    case suspended
}

protocol EmployeeRepository: Sendable {

    // Returns the driver holding this card, or why they cannot be tested.
    func driver(withCard code: String) async throws -> Employee
}

nonisolated struct LiveEmployeeRepository: EmployeeRepository {

    private static let path = "rest/v1/employees"

    private let api: any APIClient

    init(api: any APIClient) {
        self.api = api
    }

    func driver(withCard code: String) async throws -> Employee {
        let matches: [Employee] = try await api.send(
            Endpoint(
                Self.path,
                query: [
                    URLQueryItem(name: "select", value: "*"),
                    URLQueryItem(name: "card_code", value: "eq.\(code)")
                ]
            ),
            as: [Employee].self
        )

        guard let employee = matches.first else { throw CardLookupFailure.unknownCard }
        guard employee.role == .driver else { throw CardLookupFailure.notADriver }
        guard employee.status == .active else { throw CardLookupFailure.suspended }
        return employee
    }
}
