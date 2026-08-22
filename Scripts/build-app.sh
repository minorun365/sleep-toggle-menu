#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
project_dir="${script_dir:h}"
dist_dir="${project_dir}/dist"
app_dir="${dist_dir}/SleepToggleMenu.app"
contents_dir="${app_dir}/Contents"

/usr/bin/swift build --package-path "${project_dir}" -c release --product SleepToggleMenu >&2
binary_dir="$(/usr/bin/swift build --package-path "${project_dir}" -c release --show-bin-path)"

/bin/rm -rf "${app_dir}"
/usr/bin/install -d "${contents_dir}/MacOS" "${contents_dir}/Resources"
/usr/bin/install -m 0755 "${binary_dir}/SleepToggleMenu" "${contents_dir}/MacOS/SleepToggleMenu"
/usr/bin/install -m 0644 "${project_dir}/Resources/Info.plist" "${contents_dir}/Info.plist"
/usr/bin/codesign --force --sign - "${app_dir}" >/dev/null 2>&1

print "${app_dir}"
