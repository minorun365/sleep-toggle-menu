#!/bin/zsh

set -euo pipefail

label="com.minorun365.sleep-toggle-menu"
app_target="${HOME}/Applications/SleepToggleMenu.app"
agent_target="${HOME}/Library/LaunchAgents/${label}.plist"
helper_target="/usr/local/libexec/sleep-toggle-helper"
sudoers_target="/etc/sudoers.d/sleep-toggle-menu"
domain="gui/$(/usr/bin/id -u)"

if [[ -x "${helper_target}" ]]; then
  /usr/bin/sudo "${helper_target}" 0
fi

/bin/launchctl bootout "${domain}/${label}" 2>/dev/null || true
/usr/bin/pkill -x SleepToggleMenu 2>/dev/null || true
/bin/rm -rf "${app_target}"
/bin/rm -f "${agent_target}"
/usr/bin/sudo /bin/rm -f "${helper_target}" "${sudoers_target}"

print "スリープを許可状態へ戻し、Sleep Toggleを削除しました。"
