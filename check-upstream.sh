#!/usr/bin/env bash
# Check a WorkBuddy edition for a new Linux build.
#
#   ./check-upstream.sh            # international (default)
#   ./check-upstream.sh cn         # mainland-China
#
# Handles the upstream API bug: the *international* update API returns a URL
# under /linux-x64-deb/ with "-deb" in the filename, which 404s. The bucket
# only serves /linux-x64/ without "-deb". We rewrite it and verify with a HEAD.
# The CN API's URL is served correctly as-is, so no rewrite is applied there.
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
EDITION="${1:-${EDITION:-intl}}"
case "$EDITION" in
  intl)
    API='https://www.workbuddy.ai/v2/update?platform=workbuddy-linux-x64-deb'
    PKGDIR="${PKGDIR:-$ROOT/pkg}"
    ;;
  cn)
    API='https://copilot.tencent.com/v2/update?platform=workbuddy-linux-x64-deb'
    PKGDIR="${PKGDIR:-$ROOT/cn}"
    ;;
  *)
    echo "unknown edition: $EDITION (expected 'intl' or 'cn')" >&2
    exit 2
    ;;
esac

json=$(curl -sf "$API")
api_ver=$(jq -r '.version' <<<"$json")
api_url=$(jq -r '.url' <<<"$json")
api_sha=$(jq -r '.sha256hash' <<<"$json")

if [[ "$EDITION" == intl ]]; then
  # Rewrite the broken path: .../linux-x64-deb/WorkBuddy-linux-x64-deb-<v>.deb
  #                   ->  .../linux-x64/WorkBuddy-linux-x64-<v>.deb
  good_url=$(sed -e 's|/linux-x64-deb/|/linux-x64/|' -e 's|/WorkBuddy-linux-x64-deb-|/WorkBuddy-linux-x64-|' <<<"$api_url")
else
  good_url="$api_url"
fi

installed_ver=$(sed -n 's/^_pkgver=\(.*\)$/\1/p' "$PKGDIR/PKGBUILD" 2>/dev/null || echo '?')
installed_build=$(sed -n 's/^_build=\(.*\)$/\1/p' "$PKGDIR/PKGBUILD" 2>/dev/null || echo '?')

# The artifact basename carries BOTH the version and the build hash:
#   WorkBuddy-linux-x64-<version>-<build>.deb      (international)
#   WorkBuddy-linux-x64-deb-<version>-<build>.deb  (CN)
# Compare both. Comparing only .version would miss a same-version rebuild,
# which upstream does ship (that is exactly why the hash is in the filename).
base=${good_url##*/}
stem=${base%.deb}
stem=${stem#WorkBuddy-linux-x64-}
stem=${stem#deb-}                 # CN filenames carry a "-deb-" segment
api_build_from_url=${stem##*-}    # <build>
api_ver_from_url=${stem%-*}       # <version>

echo "edition   : $EDITION"
echo "installed : ${installed_ver}-${installed_build}"
echo "upstream  : ${api_ver}-${api_build_from_url}  (from API .version + artifact name)"
echo "artifact  : $base"
echo "api url   : $api_url"
echo "fixed url : $good_url"
if [[ -z "$api_sha" || "$api_sha" == "null" ]]; then
  echo "checksum  : (none published for this edition)"
else
  echo "checksum  : $api_sha"
fi

# Confirm the URL we would actually fetch resolves before recommending it.
code=$(curl -s -o /dev/null -w '%{http_code}' -r 0-0 "$good_url")
len=$(curl -sI "$good_url" | tr -d '\r' | sed -n 's/^[Cc]ontent-[Ll]ength: //p')
echo "reachable : HTTP $code, ${len:-?} bytes"

if [[ "$api_ver_from_url" == "$installed_ver" && "$api_build_from_url" == "$installed_build" ]]; then
  echo
  echo "Up to date (version and build hash both match)."
elif [[ "$api_ver_from_url" == "$installed_ver" ]]; then
  echo
  echo "SAME VERSION, DIFFERENT BUILD HASH — upstream rebuilt $api_ver_from_url."
  echo "Re-download and re-pin; the binary has changed."
  echo "  1. set _build=$api_build_from_url in $PKGDIR/PKGBUILD"
  echo "  2. curl -L -o '$PKGDIR/$base' '$good_url'"
  echo "  3. sha256sum, compare against the stored SHA256, update sha256sums=()"
  echo "  4. cd '$PKGDIR' && makepkg -si"
else
  echo
  echo "Update available. Next steps:"
  echo "  1. bump _pkgver/_build in $PKGDIR/PKGBUILD to ${api_ver_from_url}/${api_build_from_url}"
  echo "  2. curl -L -o '$PKGDIR/$base' '$good_url'"
  echo "  3. sha256sum the file, diff against the stored SHA256, put it in sha256sums=()"
  echo "  4. cd '$PKGDIR' && makepkg -si"
fi
