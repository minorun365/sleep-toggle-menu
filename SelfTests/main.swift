import Foundation
import SleepToggleCore

struct TestCase {
    let name: String
    let output: String
    let expected: SleepPermission
}

let testCases = [
    TestCase(
        name: "SleepDisabled 1をスリープ禁止として判定",
        output: """
        System-wide power settings:
         SleepDisabled\t\t1
        Currently in use:
         sleep\t\t0
        """,
        expected: .prohibited
    ),
    TestCase(
        name: "SleepDisabled 0をスリープ可能として判定",
        output: """
        System-wide power settings:
         SleepDisabled  0
        """,
        expected: .allowed
    ),
    TestCase(
        name: "設定が無い場合は不明として判定",
        output: "Currently in use:\n sleep 0",
        expected: .unknown
    ),
    TestCase(
        name: "sleep 0をSleepDisabledと誤認しない",
        output: """
        Currently in use:
         sleep 0
         displaysleep 0
        """,
        expected: .unknown
    ),
]

var failures = 0
for testCase in testCases {
    let actual = PMSetOutputParser.sleepPermission(from: testCase.output)
    if actual == testCase.expected {
        print("PASS: \(testCase.name)")
    } else {
        failures += 1
        print("FAIL: \(testCase.name) expected=\(testCase.expected) actual=\(actual)")
    }
}

guard failures == 0 else {
    exit(1)
}

print("全\(testCases.count)件の自己診断に成功しました。")
