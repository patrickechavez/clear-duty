//
//  AppEnvironment.swift
//  ClearDuty
//  Created by John Patrick Echavez on 9/8/26.
//

import Foundation

// Which configuration is running, resolved from the flags the xcconfigs set.
enum AppEnvironment {

    case development
    case staging
    case production

    static let current: AppEnvironment = {
        #if DEVELOPMENT
        return .development
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }()

    // The Demo scheme passes this, so the app runs on mock data alone.
    static let demoFlag = "-demo"

    #if DEVELOPMENT
    static let isDemo = runsOnMockData(arguments: ProcessInfo.processInfo.arguments)
    #else
    // Never in Production, whatever the app is launched with.
    static let isDemo = false
    #endif

    static func runsOnMockData(arguments: [String]) -> Bool {
        arguments.contains(demoFlag)
    }

    // nil in Production, which shows no ribbon.
    var label: String? {
        switch self {
        case .development: "dev"
        case .staging: "staging"
        case .production: nil
        }
    }
}
