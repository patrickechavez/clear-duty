//
//  EmployeeTests.swift
//  ClearDutyTests
//

import Foundation
import Testing
@testable import ClearDuty

struct EmployeeTests {

    private func employee(role: Employee.Role, status: Employee.Status) -> Employee {
        Employee(
            id: UUID(),
            employeeNo: "D-1042",
            firstName: "Ronnie",
            lastName: "Dela Cruz",
            role: role,
            status: status,
            photoPath: nil
        )
    }

    @Test func allowsAnActiveDriver() {
        #expect(employee(role: .driver, status: .active).canBeTested)
    }

    @Test func refusesASuspendedDriver() {
        #expect(!employee(role: .driver, status: .suspended).canBeTested)
    }

    @Test func refusesStaff() {
        #expect(!employee(role: .supervisor, status: .active).canBeTested)
        #expect(!employee(role: .admin, status: .active).canBeTested)
    }

    @Test func buildsADisplayName() {
        let driver = employee(role: .driver, status: .active)

        #expect(driver.fullName.contains("Ronnie"))
        #expect(driver.initials == "RD")
    }

    // The wire format is snake case; the decoder has no key strategy.
    @Test func decodesTheSupabaseShape() throws {
        let json = Data("""
        {
          "id": "00000000-0000-0000-0000-0000000000d1",
          "employee_no": "D-1042",
          "first_name": "Ronnie",
          "last_name": "Dela Cruz",
          "role": "driver",
          "status": "active",
          "photo_path": null
        }
        """.utf8)

        let employee = try JSONDecoder.api.decode(Employee.self, from: json)

        #expect(employee.employeeNo == "D-1042")
        #expect(employee.role == .driver)
        #expect(employee.status == .active)
        #expect(employee.photoPath == nil)
        #expect(employee.canBeTested)
    }
}

struct MockEmployeeRepositoryTests {

    @Test func findsADriverByCard() async throws {
        let repository = MockEmployeeRepository()

        let driver = try await repository.driver(withCard: "CARD-4F2A91")

        #expect(driver.employeeNo == "D-1042")
        #expect(repository.lookups == ["CARD-4F2A91"])
    }

    @Test func refusesAnUnknownCard() async {
        let repository = MockEmployeeRepository()

        await #expect(throws: CardLookupFailure.unknownCard) {
            try await repository.driver(withCard: "CARD-NOTREAL")
        }
    }

    @Test func refusesASuspendedDriver() async {
        let repository = MockEmployeeRepository()

        await #expect(throws: CardLookupFailure.suspended) {
            try await repository.driver(withCard: "CARD-0FA983")
        }
    }

    // A supervisor's card must not start a test, even though they are in the roster.
    @Test func refusesAStaffCard() async {
        let repository = MockEmployeeRepository()

        await #expect(throws: CardLookupFailure.notADriver) {
            try await repository.driver(withCard: "CARD-S014")
        }
    }

    // Every sample the mock can return is constructed here, so an invalid
    // literal cannot sit unnoticed until something touches it.
    @Test func buildsEverySample() {
        #expect(SampleData.driver.canBeTested)
        #expect(!SampleData.suspendedDriver.canBeTested)
        #expect(!SampleData.supervisor.canBeTested)
    }
}
