//
//  RouterTests.swift
//  ClearDutyTests
//

import Foundation
import Testing
@testable import ClearDuty

// The Router is generic, so its tests carry their own route rather than
// depending on whichever screens the app happens to have.
private enum TestRoute: AppRoute {
    case detail
    case sheet(note: String)
    case cover
}

@MainActor
struct RouterTests {

    @Test func presentsAndDismissesASheet() {
        let router = Router<TestRoute>()

        router.present(sheet: .sheet(note: "Weekend trip"))
        #expect(router.sheet == .sheet(note: "Weekend trip"))

        router.dismissSheet()
        #expect(router.sheet == nil)
    }

    @Test func presentsAndDismissesACover() {
        let router = Router<TestRoute>()

        router.present(cover: .cover)
        #expect(router.cover == .cover)

        router.dismissCover()
        #expect(router.cover == nil)
    }

    @Test func keepsSheetAndCoverIndependent() {
        let router = Router<TestRoute>()

        router.present(sheet: .sheet(note: "a"))
        router.present(cover: .cover)
        router.dismissSheet()

        #expect(router.sheet == nil)
        #expect(router.cover == .cover)
    }

    @Test func leavesModalsOutOfRestoration() throws {
        let router = Router<TestRoute>()
        router.push(.detail)
        router.present(sheet: .sheet(note: "a"))
        router.present(cover: .cover)

        let restored = Router<TestRoute>()
        restored.restore(from: router.restorationData)

        #expect(restored.path == [.detail])
        #expect(restored.sheet == nil)
        #expect(restored.cover == nil)
    }

    @Test func doesNotPresentAModalWhenPushing() {
        let router = Router<TestRoute>()

        router.push(.detail)

        #expect(router.sheet == nil)
        #expect(router.cover == nil)
    }
}
