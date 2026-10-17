# Sleep Toggle Menu

MacBookの強制スリープを許可するかどうかを、macOSのメニューバーで確認・切り替える小さなアプリ。

macOS 13以降。

## 表示と操作

- `🔥 0:59`（色つきの炎と残り時間）: `SleepDisabled 1`。蓋を閉じてもスリープしない。残り時間が0になると自動で `SleepDisabled 0` へ戻る。
- 白い炎（中が抜けたアイコン）: `SleepDisabled 0`。蓋を閉じると通常どおりスリープする。
- 左クリック: スリープ可能なら1時間だけ起動維持にする。起動維持中ならすぐ通常へ戻す。
- 右クリック: 現在状態と戻る時刻、1時間／2時間の起動維持（起動維持中は「いまから◯時間に延長」）、通常へ戻す、アプリ終了を表示。

状態は3秒ごと、およびMacの復帰時に `/usr/bin/pmset -g` から読み直す。アプリの内部状態だけを表示せず、OSの実設定を正とする。

### 自動で戻す仕組み

起動維持のまま紛失したときに、スリープしない状態が続かないようにするため、起動維持には必ず期限を付ける。

- 期限は UserDefaults（`com.minorun365.sleep-toggle-menu` の `keepAwakeDeadline`）に保存し、アプリやMacを再起動しても引き継ぐ。起動時に期限を過ぎていれば、その場で戻す。
- 経過時間は壁時計で数える。スリープしていた時間も経過に含む。
- ターミナルで `pmset` を打つなど、期限の無い起動維持を見つけたら、その時点から1時間の期限を付ける。
- 「終了」を選ぶと、スリープ可能へ戻してから終わる。

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

自動で戻すのはアプリが動いている間だけ。アプリを強制終了したまま起動維持にしていると、次にアプリが起動するまで戻らない。

## 開発

```bash
swift run SleepToggleMenuSelfTest
./Scripts/build-app.sh
```

## ライセンス

Apache License 2.0
