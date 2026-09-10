//
//  OfflineWriteLoggerTests.swift
//  ClearDutyTests
//

import Testing
@testable import ClearDuty

struct OfflineWriteLoggerTests {

    @Test func marksTheWriteAsNeverSent() {
        let summary = OfflineWriteLogger.summary(.post)

        #expect(summary.hasPrefix("offline POST"))
    }

    @Test func includesThePathWhenGiven() {
        let summary = OfflineWriteLogger.summary(.patch, path: "/rest/v1/items")

        #expect(summary.hasPrefix("offline PATCH /rest/v1/items"))
    }

    @Test func stampsTheBuildThatWroteTheRow() {
        let summary = OfflineWriteLogger.summary(.delete)

        #expect(summary.contains("client=\(ClientMetadata.appVersion)(\(ClientMetadata.appBuild))"))
    }
}
