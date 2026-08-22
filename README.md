# Sleep Toggle Menu

MacBookの強制スリープを許可するかどうかを、macOSのメニューバーで確認・切り替える小さなアプリ。

macOS 13以降。

## 表示と操作

- `🔥`（色つきの炎）: `SleepDisabled 1`。蓋を閉じてもスリープしない。
- 白い炎（中が抜けたアイコン）: `SleepDisabled 0`。蓋を閉じると通常どおりスリープする。
- 左クリック: 2状態を即時切り替え。
- 右クリック: 現在状態、切り替え、アプリ終了を表示。

状態は3秒ごと、およびMacの復帰時に `/usr/bin/pmset -g` から読み直す。アプリの内部状態だけを表示せず、OSの実設定を正とする。

## インストール

```bash
./Scripts/install.sh
```

初回だけ管理者認証が必要。次の2操作だけをパスワードなしで許可する。

```text
/usr/local/libexec/sleep-toggle-helper 0
/usr/local/libexec/sleep-toggle-helper 1
```

ヘルパーは `root:wheel`、モード `0755` で配置し、一般ユーザーは内容を書き換えられない。`pmset` 全体や任意コマンドを許可しない。

アプリは `~/Applications/SleepToggleMenu.app` へ置き、LaunchAgentでログイン時に自動起動する。

## アンインストール

```bash
./Scripts/uninstall.sh
```

スリープを許可状態へ戻してから、アプリ、LaunchAgent、ヘルパー、限定したsudoers設定を削除する。

## 注意

`pmset disablesleep` はmacOSの `pmset` マニュアルに記載されていない設定。macOS更新後は、表示と実際の蓋閉じ動作を再確認する。

起動維持のまま鞄やケースへ入れない。蓋を閉じても処理が続くため、発熱とバッテリー消費につながる。移動後はメニューバーの表示を確認して、白い炎へ戻す。

## 開発

```bash
swift run SleepToggleMenuSelfTest
./Scripts/build-app.sh
```

## ライセンス

Apache License 2.0
