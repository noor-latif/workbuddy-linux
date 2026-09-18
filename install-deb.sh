#!/usr/bin/env bash
# Direct .deb install for Debian/Ubuntu (no Arch/pacman needed).
#
# One-liner (international edition):
#   curl -fsSL https://raw.githubusercontent.com/noor-latif/workbuddy-linux/main/install-deb.sh | bash
# CN edition:
#   curl -fsSL .../install-deb.sh | bash -s -- cn
#
# Resolves Tencent's update API to the real .deb URL (working around the
# international API's 404ing URL), downloads with resume, sanity-checks the
# size against Content-Length, and installs with dpkg + apt -f.
#
#   install-deb.sh [intl|cn] [--check]   # --check: print URL + size, download nothing
set -euo pipefail

EDITION="intl"
CHECK=0
for a in "$@"; do
  case "$a" in
    cn|intl) EDITION="$a" ;;
    --check) CHECK=1 ;;
    *) echo "usage: $0 [intl|cn] [--check]" >&2; exit 2 ;;
  esac
done

if [[ "$EDITION" == intl ]]; then
  API='https://www.workbuddy.ai/v2/update?platform=workbuddy-linux-x64-deb'
else
  API='https://copilot.tencent.com/v2/update?platform=workbuddy-linux-x64-deb'
fi

json=$(curl -fsSL "$API")
api_ver=$(jq -r '.version' <<<"$json")
api_url=$(jq -r '.url' <<<"$json")

if [[ "$EDITION" == intl ]]; then
  good_url=$(sed -e 's|/linux-x64-deb/|/linux-x64/|' -e 's|/WorkBuddy-linux-x64-deb-|/WorkBuddy-linux-x64-|' <<<"$api_url")
else
  good_url="$api_url"
fi

base=${good_url##*/}
echo "version : $api_ver ($EDITION)"
echo "url     : $good_url"

expected=$(curl -fsSLI "$good_url" | tr -d '\r' | sed -n 's/^[Cc]ontent-[Ll]ength: //p' | tail -1)
[[ -n "$expected" ]] || { echo "no Content-Length; refusing blind download" >&2; exit 1; }
echo "size    : $expected bytes"
[[ "$CHECK" == 1 ]] && exit 0

dest="/tmp/$base"
for ((i = 1; i <= 10; i++)); do
  if [[ -f "$dest" && "$(stat -c%s "$dest")" == "$expected" ]]; then break; fi
  echo "download pass $i/10..."
  curl -fL --retry 3 --retry-all-errors -C - -o "$dest" "$good_url" || true
done
got=$(stat -c%s "$dest")
[[ "$got" == "$expected" ]] || { echo "incomplete: got $got / $expected" >&2; exit 1; }

# No trustworthy checksum exists (intl publishes none; the CN API's advertised
# digest does not match what its CDN serves), so size + HTTPS is the check.
echo "installing $dest ..."
sudo dpkg -i "$dest"
sudo apt-get install -f -y

echo "done. Launch: workbuddyai (intl) or workbuddy (CN)."
