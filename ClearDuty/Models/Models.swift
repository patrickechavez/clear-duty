//
//  Models.swift
//  ClearDuty
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation

struct RegisterRequest: Encodable, Sendable {
    let firstName: String
    let lastName: String
    let email: String
    let username: String
    // ISO-8601 calendar date, e.g. "1998-04-23".
    let dateOfBirth: String
    // E.164, e.g. "+639171234567". Optional — the field isn't required.
    let phone: String?
    let password: String
}

struct RegisterResponse: Decodable, Sendable {
    let id: UUID
    let username: String
}

// Mirrors Supabase Auth: id/email top-level, the rest under user_metadata.
struct User: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let email: String
    let userMetadata: UserMetadata

    struct UserMetadata: Codable, Equatable, Sendable {
        let username: String
        let firstName: String
        let lastName: String
        let image: String?

        enum CodingKeys: String, CodingKey {
            case username
            case firstName = "first_name"
            case lastName = "last_name"
            case image
        }
    }

    enum CodingKeys: String, CodingKey {
        case id
        case email
        case userMetadata = "user_metadata"
    }

    var fullName: String {

        PersonNameComponents(
            givenName: userMetadata.firstName,
            familyName: userMetadata.lastName
        ).formatted()
    }

    var initials: String {
        [userMetadata.firstName, userMetadata.lastName]
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    var avatarURL: URL? {
        userMetadata.image.flatMap(URL.init(string:))
    }
}

// Holds version information for checking if the app needs an update.
struct VersionCheck: Decodable, Sendable {

    let minimumVersion: String

    let latestVersion: String?
    let message: String?

    let isMandatory: Bool

    enum CodingKeys: String, CodingKey {
        case minimumVersion = "minimum_version"
        case latestVersion = "latest_version"
        case message
        case isMandatory = "is_mandatory"
    }
}

struct DeviceRegistration: Encodable, Sendable {
    let token: String
    let platform: String
    let appVersion: String
    let locale: String

    init(pushToken: String) {
        self.token = pushToken
        self.platform = ClientMetadata.platform
        self.appVersion = ClientMetadata.appVersion
        self.locale = Locale.current.identifier
    }
}

struct Item: Codable, Identifiable, Equatable, Hashable, Sendable {
    // Assumes a uuid primary key — change to Int if yours is serial/bigserial.
    let id: UUID
    let title: String
    let description: String
    let price: Double
    let thumbnail: String?

    var thumbnailURL: URL? {
        thumbnail.flatMap(URL.init(string:))
    }
}

struct ItemDraft: Encodable, Sendable {
    let title: String
    let description: String
    let price: Double
}
