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
    TestCase(
        name: "一度も設定していないMac（SleepDisabledの行が無い）はスリープ可能として判定",
        output: """
        System-wide power settings:
        Currently in use:
         standby              1
         sleep                1 (sleep prevented by powerd)
         displaysleep         5
        """,
        expected: .allowed
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

func check<T: Equatable>(_ name: String, _ actual: T, _ expected: T) {
    if actual == expected {
        print("PASS: \(name)")
    } else {
        failures += 1
        print("FAIL: \(name) expected=\(expected) actual=\(actual)")
    }
}

let now = Date(timeIntervalSince1970: 1_800_000_000)
let hour: TimeInterval = 60 * 60

check(
    "期限前の起動維持はそのまま",
    AutoRevertPolicy.action(permission: .prohibited, deadline: now.addingTimeInterval(1), now: now),
    .none
)
check(
    "期限ちょうどで戻す",
    AutoRevertPolicy.action(permission: .prohibited, deadline: now, now: now),
    .revert
)
check(
    "スリープ中に期限を過ぎていても戻す",
    AutoRevertPolicy.action(permission: .prohibited, deadline: now.addingTimeInterval(-3 * hour), now: now),
    .revert
)
check(
    "期限の無い起動維持には既定の1時間を付ける",
    AutoRevertPolicy.action(permission: .prohibited, deadline: nil, now: now),
    .assignDeadline(now.addingTimeInterval(hour))
)
check(
    "スリープ可能に戻っていたら期限を捨てる",
    AutoRevertPolicy.action(permission: .allowed, deadline: now.addingTimeInterval(hour), now: now),
    .clearDeadline
)
check(
    "状態不明のときは何もしない",
    AutoRevertPolicy.action(permission: .unknown, deadline: now.addingTimeInterval(-hour), now: now),
    .none
)
check("残り59分30秒は0:60でなく1:00", RemainingTimeFormatter.short(59 * 60 + 30), "1:00")
check("残り2時間", RemainingTimeFormatter.short(2 * hour), "2:00")
check("残りがマイナスでも0:00", RemainingTimeFormatter.short(-10), "0:00")
check("残り6時間", RemainingTimeFormatter.short(6 * hour), "6:00")
check("6時間の表記", RemainingTimeFormatter.duration(6 * hour), "6時間")
check("1時間の表記", RemainingTimeFormatter.duration(hour), "1時間")
check("90分の表記", RemainingTimeFormatter.duration(90 * 60), "1時間30分")
check("30分の表記", RemainingTimeFormatter.duration(30 * 60), "30分")

guard failures == 0 else {
    exit(1)
}

print("自己診断にすべて成功しました。")
