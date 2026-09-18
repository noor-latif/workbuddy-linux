#!/usr/bin/env bash
# Update the WorkBuddy pacman package from Tencent's own update API.
#   ./update.sh          # international edition
#   ./update.sh cn       # mainland-China edition
#
# Exits 0 saying "up to date" when there is nothing to do. Otherwise it bumps
# _pkgver/_build in the PKGBUILD, (re)downloads the .deb with resume across
# the CDN's habit of cutting the connection, re-pins sha256sums to the
# measured digest, and rebuilds + reinstalls via makepkg -si.
#
# It never touches the running app: after an update, relaunch WorkBuddy
# yourself to run the new build.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
EDITION="${1:-${EDITION:-intl}}"
case "$EDITION" in
  intl)
    API='https://www.workbuddy.ai/v2/update?platform=workbuddy-linux-x64-deb'
    PKGDIR="$ROOT/intl"
    ;;
  cn)
    API='https://copilot.tencent.com/v2/update?platform=workbuddy-linux-x64-deb'
    PKGDIR="$ROOT/cn"
    ;;
  *)
    echo "unknown edition: $EDITION (expected 'intl' or 'cn')" >&2
    exit 2
    ;;
esac

json=$(curl -sf "$API")
api_url=$(jq -r '.url' <<<"$json")

# The international API returns a URL that 404s; the bucket only serves the
# rewritten form. The CN URL is served correctly as-is.
if [[ "$EDITION" == intl ]]; then
  good_url=$(sed -e 's|/linux-x64-deb/|/linux-x64/|' -e 's|/WorkBuddy-linux-x64-deb-|/WorkBuddy-linux-x64-|' <<<"$api_url")
else
  good_url="$api_url"
fi

# The artifact basename carries BOTH version and build hash; compare both so a
# same-version rebuild is not missed.
base=${good_url##*/}
stem=${base%.deb}
stem=${stem#WorkBuddy-linux-x64-}
stem=${stem#deb-}
new_build=${stem##*-}
new_ver=${stem%-*}

cur_ver=$(sed -n 's/^_pkgver=\(.*\)$/\1/p' "$PKGDIR/PKGBUILD")
cur_build=$(sed -n 's/^_build=\(.*\)$/\1/p' "$PKGDIR/PKGBUILD")
pkgname=$(sed -n 's/^pkgname=\(.*\)$/\1/p' "$PKGDIR/PKGBUILD")

if [[ "$new_ver" == "$cur_ver" && "$new_build" == "$cur_build" ]]; then
  echo "workbuddy-$EDITION up to date: ${cur_ver}-${cur_build} ($(pacman -Q "$pkgname" 2>/dev/null || echo 'not installed'))"
  exit 0
fi

echo "updating $cur_ver-$cur_build -> $new_ver-$new_build"
sed -i -e "s/^_pkgver=.*$/_pkgver=$new_ver/" -e "s/^_build=.*$/_build=$new_build/" "$PKGDIR/PKGBUILD"

expected=$(curl -sfI "$good_url" | tr -d '\r' | sed -n 's/^[Cc]ontent-[Ll]ength: //p' | tail -1)
[[ -n "$expected" ]] || { echo "no Content-Length for $good_url; refusing blind download" >&2; exit 1; }

dest="$PKGDIR/$base"
# A new build means a new filename; drop stale .debs so they don't pile up.
find "$PKGDIR" -maxdepth 1 -name '*.deb' ! -name "$base" -delete

for ((i = 1; i <= 10; i++)); do
  if [[ -f "$dest" && "$(stat -c%s "$dest")" == "$expected" ]]; then break; fi
  echo "download pass $i/10..."
  curl -fL --retry 3 --retry-all-errors -C - -o "$dest" "$good_url" || true
done
got=$(stat -c%s "$dest")
[[ "$got" == "$expected" ]] || { echo "incomplete: got $got / $expected after 10 passes" >&2; exit 1; }

digest=$(sha256sum "$dest" | cut -d' ' -f1)
sed -i "s/^sha256sums=(.*)$/sha256sums=('$digest')/" "$PKGDIR/PKGBUILD"
echo "$digest  $base" > "$PKGDIR/SHA256"

cd "$PKGDIR" && makepkg -si --noconfirm

echo
echo "installed: $(pacman -Q "$pkgname")"
echo "Relaunch WorkBuddy to run the new build (quit the old one first)."
