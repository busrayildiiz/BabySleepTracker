//
//  SleepAPITests.swift
//  BabySleepTrackerTests
//
//  Created by MacBook on 9.05.2026.
//

import Foundation
import  XCTest
@testable import BabySleepTracker

class SleepAPITests: XCTestCase {

    func test_fetchRecords_shouldReturnTwoRecords() async throws {
        let sut = MockSleepAPI()

        let records = try await sut.fetchRecords()

        XCTAssertEqual(records.count, 2, "The expected number of records from the API was 2!")
        XCTAssertEqual(records.first?.duration, 90, "The initial registration period should have been 90 days!")
    }
}
