#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
label="com.minorun365.sleep-toggle-menu"
app_target="${HOME}/Applications/SleepToggleMenu.app"
agent_target="${HOME}/Library/LaunchAgents/${label}.plist"
helper_target="/usr/local/libexec/sleep-toggle-helper"
sudoers_target="/etc/sudoers.d/sleep-toggle-menu"
domain="gui/$(/usr/bin/id -u)"

app_source="$(${script_dir}/build-app.sh)"

current_state="$(/usr/bin/pmset -g | /usr/bin/awk '$1 == "SleepDisabled" { print $2; exit }')"
if [[ ("${current_state}" == "0" || "${current_state}" == "1") \
  && -x "${helper_target}" ]] \
  && /usr/bin/sudo -n "${helper_target}" "${current_state}" >/dev/null 2>&1; then
  print "登録済みの管理者権限ヘルパーを利用します。"
else
  print "管理者権限ヘルパーを登録します。"
  /usr/bin/sudo /usr/bin/install -d -o root -g wheel -m 0755 /usr/local/libexec
  /usr/bin/sudo /usr/bin/install -o root -g wheel -m 0755 \
    "${project_dir}/Resources/sleep-toggle-helper" "${helper_target}"
  /usr/bin/sudo /usr/bin/install -o root -g wheel -m 0440 \
    "${project_dir}/Resources/sleep-toggle-menu.sudoers" "${sudoers_target}"
  /usr/bin/sudo /usr/sbin/visudo -cf "${sudoers_target}"
fi

/bin/launchctl bootout "${domain}/${label}" 2>/dev/null || true
/usr/bin/pkill -x SleepToggleMenu 2>/dev/null || true

/usr/bin/install -d "${HOME}/Applications" "${HOME}/Library/LaunchAgents"
/bin/rm -rf "${app_target}"
/usr/bin/ditto "${app_source}" "${app_target}"
/usr/bin/install -m 0644 \
  "${project_dir}/Resources/${label}.plist" "${agent_target}"
/usr/libexec/PlistBuddy -c \
  "Set :ProgramArguments:0 ${app_target}/Contents/MacOS/SleepToggleMenu" \
  "${agent_target}"

/bin/launchctl bootstrap "${domain}" "${agent_target}"
/bin/launchctl kickstart -k "${domain}/${label}"

print "インストールしました: ${app_target}"
