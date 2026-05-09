//
//  AddRecorViewModelTests.swift
//  BabySleepTrackerTests
//
//  Created by MacBook on 9.05.2026.
//

import Foundation
import XCTest

@testable import BabySleepTracker

@MainActor
final class AddRecordViewModelTests: XCTestCase {

    var sut: AddRecordViewModel!

    override func setUp() {
        super.setUp()
        sut = AddRecordViewModel()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func test_buildRecord_whenDurationIsNegative_shouldReturnNilAndSetErrorMessage() {
        sut.durationText = "-10"

        let record = sut.buildRecord()

        XCTAssertNil(record, "The record should return nil when a negative time period is entered.")
        XCTAssertEqual(sut.validationMessage, "Duration must be between 1–1440 minutes.")
    }


    func test_buildRecord_whenDurationIsValid_shouldReturnRecordAndClearErrorMessage() {
        sut.durationText = "120"
        sut.kind = .nightSleep

        let record = sut.buildRecord()


        XCTAssertNotNil(record)
        XCTAssertEqual(record?.duration, 120)
        XCTAssertNil(sut.validationMessage, "The error message should have been cleared within the allotted time.")
    }
}
