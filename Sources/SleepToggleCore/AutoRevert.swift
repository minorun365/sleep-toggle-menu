import Foundation

/// 起動維持を何分で自動的に戻すか。メニューに並べる選択肢と、左クリック時の既定値。
public enum KeepAwakeDuration {
    public static let choices: [TimeInterval] = [60 * 60, 2 * 60 * 60]
    public static let defaultDuration: TimeInterval = 60 * 60
}

public enum AutoRevertAction: Equatable {
    /// 何もしない。
    case none
    /// 期限が過ぎたのでスリープ可能へ戻す。
    case revert
    /// 起動維持なのに期限が無い（手動で pmset を打った等）ので、いまから既定時間の期限を付ける。
    case assignDeadline(Date)
    /// スリープ可能に戻っているので、残っている期限を捨てる。
    case clearDeadline
}

public enum AutoRevertPolicy {
    /// OSの実設定と保存済みの期限から、次にやることを決める。
    /// 時刻は壁時計で比べるので、スリープしていた時間も経過時間に数える。
    public static func action(
        permission: SleepPermission,
        deadline: Date?,
        now: Date,
        defaultDuration: TimeInterval = KeepAwakeDuration.defaultDuration
    ) -> AutoRevertAction {
        switch permission {
        case .prohibited:
            guard let deadline else {
                return .assignDeadline(now.addingTimeInterval(defaultDuration))
            }
            return now >= deadline ? .revert : .none
        case .allowed:
            return deadline == nil ? .none : .clearDeadline
        case .unknown:
            return .none
        }
    }
}

public enum RemainingTimeFormatter {
    /// メニューバー用の短い表記。59分30秒 → "0:60" にならないよう分単位で切り上げる。
    public static func short(_ remaining: TimeInterval) -> String {
        let minutes = max(0, Int((remaining / 60).rounded(.up)))
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    /// メニュー項目用の日本語表記（"1時間" / "30分" / "1時間30分"）。
    public static func duration(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int((interval / 60).rounded(.up)))
        let hours = minutes / 60
        let rest = minutes % 60
        switch (hours, rest) {
        case (0, _):
            return "\(rest)分"
        case (_, 0):
            return "\(hours)時間"
        default:
            return "\(hours)時間\(rest)分"
        }
    }
}
