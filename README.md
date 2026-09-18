# WorkBuddy on Arch — verbatim repacks of Tencent's official Linux builds

Two pacman packages for [WorkBuddy](https://www.workbuddy.ai) (Tencent's AI
agent), repacked from the vendor `.deb` served by Tencent's own update API.
No source is modified, no native modules are rebuilt, no Electron runtime is
swapped: the exact bytes Tencent ships, installed via pacman.

## Why this exists

- The AUR's international package (`workbuddy-international-bin`) is a
  **macOS-DMG-to-Linux conversion** — it assumes no official Linux build
  exists. One does: the international update API serves a Linux x64 `.deb`
  (its URL just 404s until you rewrite it; see below). This repo packages
  that official binary instead.
- The AUR's CN package (`workbuddy`) ships `sha256sums=('SKIP')` and mutates
  the tree. Here the digest is pinned to a locally measured value and the
  tree is installed verbatim.
- Heads-up that cost us a day: **the CN edition's login requires Chinese
  citizenship.** Outside China, install the international edition.

## Packages

| dir | pkgname | edition | version (2026-09-18) |
|---|---|---|---|
| `pkg/` | `workbuddy-intl-bin` | international | 5.5.2.37849279_910352f0 |
| `cn/` | `workbuddy-cn-bin` | mainland-China | 5.5.6.38337834_5f969292 |

## Install (Arch)

```bash
cd pkg   # or cn/
makepkg -si
```

## Not on Arch?

Everything below the packaging is distro-independent — the API bugs, the
digest mismatch, and the login gotcha bite Ubuntu/Fedora users identically:

- **Direct `.deb` download (Debian/Ubuntu):** the international API
  (`https://www.workbuddy.ai/v2/update?platform=workbuddy-linux-x64-deb`)
  returns a URL that 404s; rewrite `/linux-x64-deb/` → `/linux-x64/` and
  `WorkBuddy-linux-x64-deb-` → `WorkBuddy-linux-x64-`, then
  `dpkg -i` the file (`Depends: libgtk-3-0, libnotify4, libnss3, libxss1,
  libxtst6, xdg-utils, libatspi2.0-0, libuuid1, libsecret-1-0`).
  CN: `https://copilot.tencent.com/v2/update?platform=workbuddy-linux-x64-deb`
  serves a correct URL, no rewrite needed.
- **Fedora/RHEL:** the CN API also publishes an rpm checksum per platform,
  so an official rpm path likely exists on the same bucket — not verified
  here.
- **Outside China use the international edition** — CN login requires
  Chinese citizenship regardless of distro.


The app launches as `workbuddyai` (intl) / `workbuddy` (CN). Run with
`--remote-debugging-port=9222` to use the error helper below.

## Update

```bash
workbuddy-update        # alias → ./update.sh ; add it to your shell rc
```

`update.sh` queries the update API, compares version **and** build hash
(Tencent ships same-version rebuilds), resumes the ~430 MB download across
drops, re-pins the digest, and runs `makepkg -si`. `check-upstream.sh` is
the read-only probe behind it.

## Gotchas, verified 2026-09-18

- **Intl API URL bug:** the API returns
  `.../saas/linux-x64-deb/WorkBuddy-linux-x64-deb-<v>.deb` (404). The
  bucket serves `.../saas/linux-x64/WorkBuddy-linux-x64-<v>.deb`.
  The CN API's URL needs no rewrite.
- **CN digest mismatch:** the CN API advertises `03d756b2…`, but the object
  it points at hashes to `2ef1bca2…` — confirmed byte-exact via COS
  metadata and ranged re-fetches. Pinned the measured value.
- **No self-update:** `/opt` is root-owned and the bundle ships no updater;
  updates go through pacman (see above).
- Neither `.deb` is GPG-signed.

## Helpers

- `wb-errors.sh [port] [seconds]` — dump renderer console errors/warnings
  and uncaught exceptions via the DevTools endpoint.
- `PLAN.md` — full install log, including everything that went wrong.

Not affiliated with Tencent. WorkBuddy is closed-source; this repo contains
only packaging scripts, no vendor binaries.
