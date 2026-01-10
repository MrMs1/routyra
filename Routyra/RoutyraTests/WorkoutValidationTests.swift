//
//  WorkoutValidationTests.swift
//  RoutyraTests
//
//  Tests for workout set input validation.
//

import Testing
@testable import Routyra

@MainActor
struct WorkoutValidationTests {

    // MARK: - weightReps Tests

    @Test("weightReps: weight=0 は無効")
    func testWeightRepsZeroWeightInvalid() {
        let result = WorkoutService.validateSetInput(
            metricType: .weightReps,
            weight: 0,
            reps: 10
        )
        #expect(result == false)
    }

    @Test("weightReps: reps=0 は無効")
    func testWeightRepsZeroRepsInvalid() {
        let result = WorkoutService.validateSetInput(
            metricType: .weightReps,
            weight: 60.0,
            reps: 0
        )
        #expect(result == false)
    }

    @Test("weightReps: weight=0 && reps=0 は無効")
    func testWeightRepsBothZeroInvalid() {
        let result = WorkoutService.validateSetInput(
            metricType: .weightReps,
            weight: 0,
            reps: 0
        )
        #expect(result == false)
    }

    @Test("weightReps: weight>0 && reps>0 は有効")
    func testWeightRepsValidInput() {
        let result = WorkoutService.validateSetInput(
            metricType: .weightReps,
            weight: 60.0,
            reps: 10
        )
        #expect(result == true)
    }

    @Test("weightReps: 小数点重量は有効")
    func testWeightRepsDecimalWeightValid() {
        let result = WorkoutService.validateSetInput(
            metricType: .weightReps,
            weight: 62.5,
            reps: 8
        )
        #expect(result == true)
    }

    // MARK: - bodyweightReps Tests

    @Test("bodyweightReps: reps=0 は無効")
    func testBodyweightRepsZeroRepsInvalid() {
        let result = WorkoutService.validateSetInput(
            metricType: .bodyweightReps,
            weight: 0,
            reps: 0
        )
        #expect(result == false)
    }

    @Test("bodyweightReps: reps>0 は有効")
    func testBodyweightRepsValidInput() {
        let result = WorkoutService.validateSetInput(
            metricType: .bodyweightReps,
            weight: 0,
            reps: 15
        )
        #expect(result == true)
    }

    @Test("bodyweightReps: weight は無視される")
    func testBodyweightRepsWeightIgnored() {
        // weight が設定されていても reps > 0 なら有効
        let result = WorkoutService.validateSetInput(
            metricType: .bodyweightReps,
            weight: 10.0,
            reps: 12
        )
        #expect(result == true)
    }

    // MARK: - timeDistance Tests

    @Test("timeDistance: duration > 0 で有効")
    func testTimeDistanceValidWithDuration() {
        let result = WorkoutService.validateSetInput(
            metricType: .timeDistance,
            weight: 0,
            reps: 0,
            durationSeconds: 60
        )
        #expect(result == true)
    }

    @Test("timeDistance: duration = 0 で無効")
    func testTimeDistanceInvalidWithZeroDuration() {
        let result = WorkoutService.validateSetInput(
            metricType: .timeDistance,
            weight: 0,
            reps: 0,
            durationSeconds: 0
        )
        #expect(result == false)
    }

    // MARK: - completion Tests

    @Test("completion: 常に有効")
    func testCompletionAlwaysValid() {
        let result = WorkoutService.validateSetInput(
            metricType: .completion,
            weight: 0,
            reps: 0
        )
        #expect(result == true)
    }
}
