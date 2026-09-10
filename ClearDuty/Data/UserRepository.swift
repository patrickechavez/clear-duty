//
//  UserRepository.swift
//  ClearDuty
//  Created by John Patrick Echavez on 7/29/26.
//

import Foundation
import UIKit

protocol UserRepository: Sendable {
    func currentUser() async throws -> User
    func updateProfile(_ user: User) async throws -> User
    func uploadAvatar(_ image: UIImage, compression: ImageCompression) async throws -> User
    func registerForPushNotifications(token: String) async throws
    func unregisterForPushNotifications(token: String) async throws
}

extension UserRepository {

    func uploadAvatar(_ image: UIImage) async throws -> User {
        try await uploadAvatar(image, compression: .profile)
    }
}

nonisolated struct LiveUserRepository: UserRepository {

    private let api: any APIClient

    init(api: any APIClient) {
        self.api = api
    }

    func currentUser() async throws -> User {
        try await api.get(APIRoute.Auth.currentUser)
    }

    // Email is omitted — sending it triggers a change-email confirmation.
    func updateProfile(_ user: User) async throws -> User {
        let body = UpdateUserRequest(
            data: UpdateUserRequest.Metadata(
                firstName: user.userMetadata.firstName,
                lastName: user.userMetadata.lastName,
                username: user.userMetadata.username
            )
        )
        let endpoint = try Endpoint(APIRoute.Auth.currentUser, method: .put, body: .json(body))
        return try await api.send(endpoint)
    }

    // Supabase Storage uses raw binary, not this multipart flow — needs its own.
    func uploadAvatar(_ image: UIImage, compression: ImageCompression) async throws -> User {
        throw APIError.notSupported(message: "Avatar upload isn't implemented for Supabase yet.")
    }

    // No Supabase-native equivalent — would need a custom devices table.
    func registerForPushNotifications(token: String) async throws {
        throw APIError.notSupported(message: "Push registration isn't implemented for Supabase yet.")
    }

    func unregisterForPushNotifications(token: String) async throws {
        throw APIError.notSupported(message: "Push registration isn't implemented for Supabase yet.")
    }
}

// Supabase's update-user request nests fields under "data".
private struct UpdateUserRequest: Encodable {
    let data: Metadata

    struct Metadata: Encodable {
        let firstName: String
        let lastName: String
        let username: String

        enum CodingKeys: String, CodingKey {
            case firstName = "first_name"
            case lastName = "last_name"
            case username
        }
    }
}
