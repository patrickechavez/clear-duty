//
//  AppEnvironmentTests.swift
//  ClearDutyTests
//

import Testing
@testable import ClearDuty

struct AppEnvironmentTests {

    // The test target builds Development, so this fails if the compilation
    // conditions or the #if ladder break.
    @Test func resolvesTheBuildConfiguration() {
        #expect(AppEnvironment.current == .development)
    }

    @Test func labelsDevelopmentAndStaging() {
        #expect(AppEnvironment.development.label == "dev")
        #expect(AppEnvironment.staging.label == "staging")
    }

    @Test func showsNoLabelInProduction() {
        #expect(AppEnvironment.production.label == nil)
    }

    // Only the Demo scheme passes the flag, so a plain run stays on live data.
    @Test func runsOnLiveDataWithoutTheDemoFlag() {
        #expect(!AppEnvironment.runsOnMockData(arguments: ["ClearDuty", "-other"]))
        #expect(!AppEnvironment.isDemo)
    }

    @Test func runsOnMockDataWithTheDemoFlag() {
        #expect(AppEnvironment.runsOnMockData(arguments: ["ClearDuty", AppEnvironment.demoFlag]))
    }
}
