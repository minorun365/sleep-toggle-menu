import Foundation

public enum SleepPermission: Equatable {
    case prohibited
    case allowed
    case unknown
}

public enum PMSetOutputParser {
    public static func sleepPermission(from output: String) -> SleepPermission {
        let pattern = #"(?m)^\s*SleepDisabled\s+([01])\s*$"#

        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(
                  in: output,
                  range: NSRange(output.startIndex..., in: output)
              ),
              let valueRange = Range(match.range(at: 1), in: output)
        else {
            return .unknown
        }

        return output[valueRange] == "1" ? .prohibited : .allowed
    }
}

struct CommandResult {
    let terminationStatus: Int32
    let standardOutput: String
    let standardError: String
}

enum CommandRunner {
    static func run(_ executableURL: URL, arguments: [String]) throws -> CommandResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()

        process.executableURL = executableURL
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        process.waitUntilExit()

        let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()

        return CommandResult(
            terminationStatus: process.terminationStatus,
            standardOutput: String(decoding: outputData, as: UTF8.self),
            standardError: String(decoding: errorData, as: UTF8.self)
        )
    }
}

enum PowerManagementError: LocalizedError {
    case commandFailed(String)
    case stateDidNotChange

    var errorDescription: String? {
        switch self {
        case let .commandFailed(message):
            return message
        case .stateDidNotChange:
            return "設定変更後の状態を確認できませんでした。"
        }
    }
}

public enum PowerManagement {
    private static let pmsetURL = URL(fileURLWithPath: "/usr/bin/pmset")
    private static let sudoURL = URL(fileURLWithPath: "/usr/bin/sudo")
    private static let helperPath = "/usr/local/libexec/sleep-toggle-helper"

    public static func currentPermission() -> SleepPermission {
        guard let result = try? CommandRunner.run(pmsetURL, arguments: ["-g"]),
              result.terminationStatus == 0
        else {
            return .unknown
        }

        return PMSetOutputParser.sleepPermission(from: result.standardOutput)
    }

    public static func setSleepProhibited(_ prohibited: Bool) throws {
        let desiredValue = prohibited ? "1" : "0"
        let result = try CommandRunner.run(
            sudoURL,
            arguments: ["-n", helperPath, desiredValue]
        )

        guard result.terminationStatus == 0 else {
            let detail = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
            throw PowerManagementError.commandFailed(
                detail.isEmpty ? "スリープ設定を変更できませんでした。" : detail
            )
        }

        let expected: SleepPermission = prohibited ? .prohibited : .allowed
        guard currentPermission() == expected else {
            throw PowerManagementError.stateDidNotChange
        }
    }
}
