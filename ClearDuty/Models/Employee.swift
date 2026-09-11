//
//  Employee.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/11/26.
//

import Foundation

// A person in the roster. Drivers are tested; staff sign in.
struct Employee: Codable, Identifiable, Equatable, Sendable {

    enum Role: String, Codable, Sendable {
        case driver
        case supervisor
        case admin
    }

    enum Status: String, Codable, Sendable {
        case active
        case suspended
    }

    let id: UUID
    let employeeNo: String
    let firstName: String
    let lastName: String
    let role: Role
    let status: Status
    let photoPath: String?

    enum CodingKeys: String, CodingKey {
        case id
        case employeeNo = "employee_no"
        case firstName = "first_name"
        case lastName = "last_name"
        case role
        case status
        case photoPath = "photo_path"
    }

    var fullName: String {
        PersonNameComponents(givenName: firstName, familyName: lastName).formatted()
    }

    var initials: String {
        [firstName, lastName]
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    // Only an active driver may be tested.
    var canBeTested: Bool {
        role == .driver && status == .active
    }
}
