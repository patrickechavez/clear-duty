//
//  Mocks.swift
//  ClearDuty
//  Created by John Patrick Echavez on 7/29/26.
//

#if DEVELOPMENT

import Foundation
import UIKit

enum SampleData {

    static let user = User(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        email: "raven@example.com",
        userMetadata: User.UserMetadata(
            username: "raven",
            firstName: "Raven",
            lastName: "Solis",
            image: nil
        )
    )

    static let tokens = AuthTokens(
        accessToken: "sample-access-token",
        refreshToken: "sample-refresh-token",
        expiresAt: Date().addingTimeInterval(3600)
    )
}

extension SampleData {

    static let driver = Employee(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000d1")!,
        employeeNo: "D-1042",
        firstName: "Ronnie",
        lastName: "Dela Cruz",
        role: .driver,
        status: .active,
        photoPath: nil
    )

    static let suspendedDriver = Employee(
        id: UUID(uuidString: "00000000-0000-0000-0000-0000000000d2")!,
        employeeNo: "D-1131",
        firstName: "Benjie",
        lastName: "Torres",
        role: .driver,
        status: .suspended,
        photoPath: nil
    )

    static let supervisor = Employee(
        id: UUID(uuidString: "00000000-0000-0000-0000-00000000005a")!,
        employeeNo: "S-014",
        firstName: "Ben",
        lastName: "Hernandez",
        role: .supervisor,
        status: .active,
        photoPath: nil
    )
}

// Looks up cards from an in-memory roster.
final class MockEmployeeRepository: EmployeeRepository, @unchecked Sendable {

    var roster: [String: Employee] = [
        "CARD-4F2A91": SampleData.driver,
        "CARD-0FA983": SampleData.suspendedDriver,
        "CARD-S014": SampleData.supervisor
    ]

    var error: Error?

    var delay: Duration = .zero

    private(set) var lookups: [String] = []

    func driver(withCard code: String) async throws -> Employee {
        lookups.append(code)

        if delay > .zero { try await Task.sleep(for: delay) }
        if let error { throw error }

        guard let employee = roster[code] else { throw CardLookupFailure.unknownCard }
        guard employee.role == .driver else { throw CardLookupFailure.notADriver }
        guard employee.status == .active else { throw CardLookupFailure.suspended }
        return employee
    }
}

final class MockAuthRepository: AuthRepository, @unchecked Sendable {

    var loginResult: Result<AuthTokens, APIError> = .success(SampleData.tokens)
    var registerResult: Result<RegisterResponse, APIError> = .success(
        RegisterResponse(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, username: "raven")
    )
    var passwordResetResult: Result<Void, APIError> = .success(())
    var logoutResult: Result<Void, APIError> = .success(())

    private(set) var loginCallCount = 0
    private(set) var lastLoginUsername: String?
    private(set) var logoutCallCount = 0

    init() {}

    func login(username: String, password: String) async throws -> AuthTokens {
        loginCallCount += 1
        lastLoginUsername = username
        return try loginResult.get()
    }

    func register(_ request: RegisterRequest) async throws -> RegisterResponse {
        try registerResult.get()
    }

    func requestPasswordReset(email: String) async throws {
        try passwordResetResult.get()
    }

    func resetPassword(token: String, newPassword: String) async throws {
        try passwordResetResult.get()
    }

    func logout(refreshToken: String?) async throws {
        logoutCallCount += 1
        try logoutResult.get()
    }
}

final class MockUserRepository: UserRepository, @unchecked Sendable {

    var currentUserResult: Result<User, APIError> = .success(SampleData.user)
    var uploadResult: Result<User, APIError> = .success(SampleData.user)

    private(set) var currentUserCallCount = 0
    private(set) var uploadCallCount = 0
    private(set) var registeredPushToken: String?

    init() {}

    func currentUser() async throws -> User {
        currentUserCallCount += 1
        return try currentUserResult.get()
    }

    func updateProfile(_ user: User) async throws -> User {
        user
    }

    func uploadAvatar(_ image: UIImage, compression: ImageCompression) async throws -> User {
        uploadCallCount += 1
        return try uploadResult.get()
    }

    func registerForPushNotifications(token: String) async throws {
        registeredPushToken = token
    }

    func unregisterForPushNotifications(token: String) async throws {
        registeredPushToken = nil
    }
}

actor MockImageLoader: ImageLoading {

    private(set) var evictedURLs: [URL] = []

    init() {}

    func image(for url: URL) async throws -> UIImage {
        throw ImageLoaderError.invalidImageData
    }

    func evict(_ url: URL) async {
        evictedURLs.append(url)
    }

    func clear() async {
        evictedURLs.removeAll()
    }

    func trimMemory() async {}
}

#endif
