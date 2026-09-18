# WorkBuddy (Tencent) — install plan for latif

Status: **INTL INSTALLED AND RUNNING (2026-09-18).** CN 5.5.6 was removed —
its login requires Chinese citizenship (user-reported, ground truth), so it
could never authenticate here. International 5.5.2 (`workbuddy-intl-bin`) is
now the working setup; §9 stays as the CN packaging record, §10 records intl.

---

## 1. Headline finding — do NOT build from source

WorkBuddy is **closed-source Electron**, shipped as a single `app.asar` inside a
self-contained bundle (it vendors its own Electron runtime — `libffmpeg.so`,
`chrome-sandbox`, `resources.pak`, `v8_context_snapshot.bin`). There is no source
to build. Every AUR entry is a *repackager*, not a builder:

| AUR pkg | Ver | What it actually does | Verdict |
|---|---|---|---|
| `workbuddy` | 5.5.6.38337834_5f969292 | Unpacks the **CN official .deb**, swaps `better-sqlite3` for a Linux build, de-asar's to patch `process.resourcesPath` | Legit, but **CN edition only** |
| `workbuddy-international-bin` | 5.5.2.37849279_910352f0 | Unpacks the **macOS DMG**, grafts a Linux Electron 37.10.3 runtime, rebuilds native modules, applies ~42 KB of runtime patches | **Now obsolete — see below** |
| `workbuddy-bin` | 4.10.4.26327962 | Stale (flagged out-of-date 2026-09-09), macOS DMG | Dead |

**The decisive find: Tencent's own update API serves a Linux x64 build of the
international edition** (vendor-provided, hosted on Tencent-associated CDN; see
the authenticity caveats in §2 — this is *not* an independently verified
binary). The AUR `workbuddy-international-bin` maintainer never noticed and kept
porting the macOS DMG. We use the real .deb and skip the whole patch/rebuild
toolchain.

---

## 2. Verified artifacts

All URLs below were fetched and confirmed (HTTP 200 + `Content-Length` + real
`.deb` `ar` header `!<arch>` / members `debian-binary`, `control.tar.xz`,
`data.tar.xz`).

**CN edition (chosen — newest, and the only edition Tencent publishes a digest for)**

```
https://download.codebuddy.cn/workbuddy/saas/linux-x64-deb/WorkBuddy-linux-x64-deb-5.5.6.38337834-5f969292.deb
size    : 429,302,312 B   (429 MB)
mtime   : 2026-09-10
sha256  : 2ef1bca217d29d9c2ba988c82079aa6ea0077e9f1ff882c6ab5dd7998bddf721
          (SELF-MEASURED — see the digest mismatch note below)
```

**Digest mismatch — the CN API's advertised hash does not describe the bytes it
serves.** The CN API reports `sha256hash:
03d756b259d7086c22098fa077589a032d60948d1de7313473360eefe11e240f` for this
platform, but the object at that URL hashes to `2ef1bca2…`. Investigated
2026-09-18 and closed as an upstream publication defect, not evidence of
tampering:

- the local file's md5 equals the object's own `x-cos-meta-md5` exactly, and
  fresh ranged GETs of head and tail match the local bytes → byte-exact to the
  served object
- all 11,345 file MD5s in the deb's own `md5sums` verify → internally consistent
- the object is stable (`last-modified: Thu, 10 Sep 2026 10:00:45 GMT`, unchanged
  across HEADs)
- `03d756b2…` matches neither `control.tar.xz` nor `data.tar.xz`, and appears
  nowhere in the payload
- the API *does* vary `sha256hash` per platform (rpm, arm64-deb, darwin-arm64 all
  differ), so the field is real — just wrong for x64-deb

No sidecar checksums exist (`.sha256`, `SHA256SUMS`, `checksums.txt`, `.sig`,
`.asc` — all 404) and there is no directory listing. **The deb is not GPG-signed**
(`control.tar.xz` contains only `control`, `preinst`, `postinst`, `prerm`,
`postrm`, `md5sums` — no `_gpgbuilder`). The user explicitly deprioritized
reconciling this; `cn/PKGBUILD` pins the measured value with a comment recording
the discrepancy. Do not describe this artifact as "signed" or "authenticated".

**International edition** (reference)

```
primary : https://codebuddy-1328495429.cos.accelerate.myqcloud.com/workbuddy/saas/linux-x64/WorkBuddy-linux-x64-5.5.2.37849279-910352f0.deb
mirror  : https://download.codebuddy.ai/workbuddy/saas/linux-x64/WorkBuddy-linux-x64-5.5.2.37849279-910352f0.deb
size    : 429,231,636 B   (429 MB)
mtime   : 2026-09-04
appimage: same dir, WorkBuddy-linux-x64-5.5.2.37849279-910352f0.AppImage (580,783,721 B)
```

**Version-discovery APIs**

```
intl : https://www.workbuddy.ai/v2/update?platform=workbuddy-linux-x64-deb
CN   : https://copilot.tencent.com/v2/update?platform=workbuddy-linux-x64-deb
```

### Two gotchas that will bite you

1. **The intl API hands back a URL that 404s.** It returns
   `.../saas/linux-x64-deb/WorkBuddy-linux-x64-deb-<v>.deb`, but the bucket only
   serves `.../saas/linux-x64/WorkBuddy-linux-x64-<v>.deb`. Verified both ways:
   `/linux-x64-deb/` → **404**, `/linux-x64/` → **200**. Rewrite the API URL:
   drop `-deb` from the directory *and* from the filename.
2. **The intl API's `sha256hash` field is empty**; the CN API's is populated.
   The CN value is *upstream-published* — **not** a cryptographic signature, and
   not authenticated in any way we can verify. The international build has no
   published digest at all.

### On authenticity — read this before trusting anything above

Nothing in this plan proves the binary is genuine Tencent software. What we
actually have is weaker:

- The `.deb` `control` file asserts `Vendor`/`Maintainer: Tencent Technology
  (Shenzhen) Company Limited <workbuddy@tencent.com>`. Those are **self-asserted
  fields inside the package** — anyone repacking a .deb can write them. They are
  evidence of intent, not of origin.
- The artifact is served from Tencent-associated infrastructure
  (`codebuddy-1328495429.cos.accelerate.myqcloud.com`, mirror
  `download.codebuddy.ai`) over HTTPS, and Tencent's own update API names it as
  the `linux-x64-deb` artifact. That is **consistent with Tencent distribution**
  — it establishes delivery/association, not genuine origin.
- Structural verification (real `ar` archive, expected member list, sane
  `control`, matching size) confirms it is a well-formed Electron deb — not that
  it is trustworthy.

**A locally computed SHA-256 is not authenticity proof.** It only detects that
the file changed between two downloads. If the CDN were compromised on the first
download, our pinned hash would faithfully pin the compromised file forever.

Residual risk: unverified binary. Mitigations if that matters to you — install
the CN edition (upstream publishes a digest) or run it under a sandbox/VM. Both
editions are closed-source; neither can be independently audited.

---

## 3. Option comparison

| | Source | Update path | UI language | Checksum | Effort |
|---|---|---|---|---|---|
| **A. Intl .deb → own PKGBUILD** | workbuddy.ai | `check-upstream` script + manual bump | English | pin ourselves | low |
| B. AUR `workbuddy` (CN) | codebuddy.cn | maintainer bumps | English-capable (documented setting) | upstream-published | lowest |
| C. AUR `workbuddy-international-bin` | macOS DMG port | maintainer bumps | English | DMG sha256 | low, but unofficial patching |
| D. AppImage | workbuddy.ai | manual | English | none | lowest, but no /opt, no pacman tracking |

Language is **not** a clean differentiator: the CN client documents an English
option too. See §8 for what remains unverified about it.

**Chosen: B, but repackaged by us rather than via the AUR.** Vendor CN `.deb` →
own PKGBUILD (`cn/PKGBUILD`). This gets the newer build and the upstream-published
checksum, keeps pacman tracking and clean rollback, and avoids the AUR recipe's
`sha256sums=('SKIP')` — that AUR entry performs **no integrity check at all** on
the downloaded deb.

Why not A (intl): it is the same product two patch versions older (5.5.2 vs
5.5.6), Tencent publishes no digest for it, and its API returns a URL that 404s.
It remains the fallback if the CN build misbehaves.

Pick **C** only if you'd rather let someone else carry the packaging — it ports
the macOS DMG and applies ~42 KB of patches, which is strictly more third-party
mutation than repacking a vendor Linux deb.

---

## 4. Preflight — already verified on this machine

```
OS        Omarchy 4.0.2 / Arch x86_64, kernel 7.1.9
disk      786 GB free on /        (installed size ≈ 1.67 GB)
sudo      passwordless (sudo -n true → OK)
userns    kernel.unprivileged_userns_clone = 1; unshare --user true → OK
          → chrome-sandbox gets 0755, not the 4755 SUID fallback
```

Runtime deps from the deb `control` file, mapped to Arch:

| deb | Arch | status |
|---|---|---|
| libgtk-3-0 | `gtk3` | installed |
| libnotify4 | `libnotify` | installed |
| libnss3 | `nss` | installed |
| libxss1 | `libxss` | installed |
| libxtst6 | `libxtst` | installed |
| xdg-utils | `xdg-utils` | installed |
| libatspi2.0-0 | `at-spi2-core` | installed |
| libuuid1 | `util-linux` | core, installed |
| libsecret-1-0 | `libsecret` | installed |
| *(Recommends)* libappindicator3-1 | `extra/libappindicator` | **not installed** — optional, tray icon only |
| *(Recommends)* imagemagick | `imagemagick` | installed |

No `electron` package needed — the bundle is self-contained.

---

## 5. Package layout (CN edition; from the deb's own `md5sums`, 11,345 files)

```
/opt/WorkBuddy/workbuddy               ← Electron binary (NO space in this one)
/opt/WorkBuddy/chrome-sandbox
/opt/WorkBuddy/resources/app.asar      ← the whole app
/opt/WorkBuddy/resources/apparmor-profile   ← optional, see note below
/opt/WorkBuddy/version
/usr/share/applications/workbuddy.desktop
/usr/share/icons/hicolor/{16..512}x*/apps/workbuddy.png
/usr/share/doc/...
/usr/bin/workbuddy                     ← created by postinst, symlink into /opt
```

Deb `control`: `Package: workbuddy`, `Version: 5.5.6`, `Homepage:
https://www.codebuddy.ai`, `Vendor`/`Maintainer: Tencent Technology (Shenzhen)
Company Limited <workbuddy@tencent.com>`, `Installed-Size: 1669891` (KB).

The install root is `/opt/WorkBuddy` — **no space**, unlike the international
edition's `/opt/WorkBuddy AI`. The binary is `workbuddy`, not `workbuddyai`, and
the desktop file is `workbuddy.desktop`. An intl PKGBUILD will not work here.

The deb's `postinst` installs `/usr/bin/workbuddy` via `update-alternatives`
(falling back to a plain symlink) and does the `chrome-sandbox` mode dance. We
replicate both directly in `package()` instead of running maintainer scripts.

---

## 6. Execution steps

### Step 0 — bandwidth

Measured on this network, 2026-09-18: `download.codebuddy.cn` gave **~150–270
KB/s** single-connection. 429 MB ≈ **30–45 min**.

**Parallel ranges were tested and do NOT help.** Two concurrent range requests
scored 36 KB/s + 106 KB/s = 142 KB/s aggregate versus 159 KB/s for one
connection — the CDN rate-limits per client, so extra connections only split the
same budget. Use a single resumable `curl -C -`; `aria2c` would be wasted effort.

### Step 1 — download + verify the checksum

**Done 2026-09-18.** The download took 37m44s at ~185 KB/s single-connection.

`SHA256` holds the **self-measured** digest of the served artifact
(`2ef1bca2…`). It deliberately does **not** hold the CN API's advertised value
(`03d756b2…`), which does not describe the bytes the CDN serves — see the digest
mismatch note in §2 before "correcting" this file.

```bash
cd ~/dev/workbuddy/cn
curl -L -C - --retry 20 --retry-delay 5 --retry-all-errors \
  -o WorkBuddy-linux-x64-deb-5.5.6.38337834-5f969292.deb \
  "https://download.codebuddy.cn/workbuddy/saas/linux-x64-deb/WorkBuddy-linux-x64-deb-5.5.6.38337834-5f969292.deb"

stat -c '%s' WorkBuddy-linux-x64-deb-5.5.6.38337834-5f969292.deb   # expect 429302312
ar t WorkBuddy-linux-x64-deb-5.5.6.38337834-5f969292.deb            # debian-binary control.tar.xz data.tar.xz
sha256sum -c SHA256
```

Note the CN URL is served **correctly as-is** — the 404 rewrite that the intl
endpoint needs does **not** apply here. (Verified again 2026-09-18: the intl-style
`saas/linux-x64/WorkBuddy-linux-x64-<v>.deb` path returns 404 for this build.)

### Step 2 — build the pacman package (the only supported install path)

`PKGBUILD` is already written at `cn/PKGBUILD` (`makepkg --printsrcinfo` parses
it). It repacks the vendor `.deb` verbatim: extracts `data.tar.xz` from the ar
archive, installs `/opt/WorkBuddy/` and `/usr/share/` as the deb intends, and
adds the two things the deb's `postinst` would have done — the `/usr/bin/workbuddy`
symlink and the `chrome-sandbox` mode.

Its `sha256sums` holds the **self-measured** digest of the served artifact, so the
build verifies itself against the bytes actually received — not against Tencent's
advertised value, which is wrong for this platform (§2).

```bash
cd ~/dev/workbuddy/cn
makepkg -si
```

That registers the package with pacman, so `pacman -Rns workbuddy-cn-bin`
removes it completely.

**Do not extract the deb by hand** (`ar x` + `tar xf -C /`). It skips the
symlink and sandbox-permission steps the deb's maintainer scripts perform, and
its rollback has to delete shared icon/desktop paths. The package path costs
nothing extra and is correct.

### Step 3 — verify the install

Confirm the package owns exactly the paths it should (a missing symlink or a
wrongly-moded sandbox is the most likely packaging failure):

```bash
pacman -Ql workbuddy-cn-bin | grep -E '/usr/bin/workbuddy|/opt/WorkBuddy/workbuddy|\.desktop$'
stat -c '%a %n' /opt/WorkBuddy/chrome-sandbox   # expect 755
readlink -f /usr/bin/workbuddy                  # expect /opt/WorkBuddy/workbuddy
```

Then **launch it from the app launcher** (not the terminal) so the Wayland
`app_id` association is exercised — that is the real proof the desktop entry and
icon resolve. Confirm the window appears and you can sign in.

If it fails to start, get the actual error rather than guessing:

```bash
/opt/WorkBuddy/workbuddy 2>&1 | head -40
```

Wayland note: Omarchy runs Hyprland. If the window is blank or the process dies
on start, Electron may need `--ozone-platform-hint=auto` added to the `Exec=`
line (try `--ozone-platform=wayland`, then `--ozone-platform=x11` under
XWayland). Don't pre-emptively add it — test the default first.

### Step 4 — updates

Use the checker with the `cn` argument — it compares **both** the version and
the build hash:

```bash
~/dev/workbuddy/check-upstream.sh cn
```

It reads `_pkgver` **and** `_build` from `cn/PKGBUILD` and compares them against
the artifact basename `WorkBuddy-linux-x64-deb-<version>-<build>.deb`. Comparing
only `.version` would miss a same-version rebuild — which upstream does ship, and
is precisely why the hash is in the filename. The script has a distinct
`SAME VERSION, DIFFERENT BUILD HASH` branch for that case.

The CN URL needs no 404 rewrite (the intl one does); the script branches on
edition for that. Run `check-upstream.sh intl` for the other edition.

Then bump `_pkgver`/`_build`, re-download, update `sha256sums`, and `makepkg -si`.

Reminder: the CN digest is upstream-published, so it verifies the bytes against
what Tencent advertises — but a published digest is still not a signature. See §2.

---

## 7. Rollback

The pacman package is the only supported install path, so removal is clean and
complete — no manual file deletion, and no shared icon/desktop paths touched:

```bash
sudo pacman -Rns workbuddy-cn-bin
```

If a `makepkg` run was interrupted, its partial download lives in `cn/`; delete
`cn/*.deb.part` before retrying so the eventual checksum is trustworthy.

User data lives under `~/.config/` and `~/.local/share/` (Electron
`app.getPath('userData')`, typically `~/.config/WorkBuddy/`) — pacman does not
remove it. Delete separately for a clean slate.

---

## 8. Decisions

1. **Edition — DECIDED: CN (5.5.6).** Chosen 2026-09-18 for the newer build, the
   upstream-published checksum, and the WeCom/Tencent Docs integrations, accepting
   China-region infrastructure and a WeChat-first login.

   **RESOLVED 2026-09-18 — the CN client comes up in English by default.** The
   user's system locale is `en_US.UTF-8` and the app resolves to English with no
   intervention. Verified four ways on the live app:

   | Evidence | Value |
   |---|---|
   | renderer URL | `index.html?locale=en-US` |
   | `navigator.language` / `documentElement.lang` | `en-US` |
   | `localStorage.CODEBUDDY_IDE_STORAGE_LANG` | `en-US` |
   | rendered UI text | `Work Less, Deliver More`, `Sign In`, `Privacy Policy`, `Terms of Service` |
   | CJK glyphs in rendered DOM | **0** |

   Resolution order, read out of the bundle: `CODEBUDDY_IDE_STORAGE_LANG` → host
   URL `locale` → version default. The CN build's compiled-in default *is*
   `zh-cn` (`DEFAULT_LOCALE = INTERNAL_LOCALE_ZH_CN`), but the persisted key
   overrides it, and the app writes `en-US` on first run from the system locale.

   The setting is `设置 → 通用 → 语言`, persisted under `preferences.language`;
   legacy keys are `CODEBUDDY_IDE_STORAGE_LANG` and `workbuddy-language`.
   Supported set is `zh-CN`, `zh-TW`, `en-US`, `pt-BR`, `id-ID` — so English is
   first-class on the CN edition, not a fallback.

   The user has since said this is settled and asked to stop investigating it.
   **Do not re-open.**

2. **Package or plain extract — DECIDED: package only.** See Step 2. Hand
   extraction skips the symlink and sandbox-mode steps and makes rollback messy.

3. **Parallel download — DECIDED: no.** Tested 2026-09-18: two concurrent range
   requests scored 36 + 106 = 142 KB/s aggregate versus 159 KB/s for a single
   connection. The CDN rate-limits per client, so `aria2c` multi-connection would
   only split the same budget. Single resumable `curl -C -` is correct.

> Note on AUR `workbuddy` (option B): its `PKGBUILD` uses
> `sha256sums_x86_64=('SKIP')`, i.e. **no integrity check at all** on the
> downloaded deb. If you go that route, either accept that or pin the hash
> yourself in a local fork. Our own `PKGBUILD` deliberately does not use SKIP.

---

## 9. Install record — what was actually verified (2026-09-18)

Built and installed as `workbuddy-cn-bin 5.5.6.38337834_5f969292-1`
(1630.74 MiB installed). `makepkg -si` completed clean: source checksum passed,
`bsdtar` auto-extracted the deb, package built and installed in 27s.

| Check | Command | Result |
|---|---|---|
| package installed | `pacman -Q workbuddy-cn-bin` | `5.5.6.38337834_5f969292-1` |
| symlink | `readlink -f /usr/bin/workbuddy` | `/opt/WorkBuddy/workbuddy` |
| sandbox mode | `stat -c '%a' /opt/WorkBuddy/chrome-sandbox` | **755** (userns available) |
| desktop entry | `/usr/share/applications/workbuddy.desktop` | `Exec=/opt/WorkBuddy/workbuddy %U` |
| binary | `file /opt/WorkBuddy/workbuddy` | ELF 64-bit LSB pie, x86-64, dynamically linked |
| window | `hyprctl clients` | `class=WorkBuddy initialClass=WorkBuddy` |
| sign-in | live DOM 2026-09-18 | **NOT yet signed in** — `Sign In` still rendered |

**The AUR recipe's `better-sqlite3` swap is NOT needed here.** The AUR `workbuddy`
PKGBUILD replaces that native module because it runs the app under **system**
`electron`; this repack uses the bundle's **own** vendored runtime, and the app
started with no native-module error. Confirmed at runtime, not inferred.

The deb's `postinst` semantics are preserved in `package()` rather than by running
maintainer scripts: the `/usr/bin/workbuddy` symlink (upstream uses
`update-alternatives` with an `ln -sf` fallback — a plain symlink is equivalent
here since nothing else provides that name), and the userns-dependent
`chrome-sandbox` mode. The AppArmor profile is deliberately not shipped; Arch does
not enable AppArmor by default and upstream treats the profile as optional.

### Debugging — remote debugging is intentionally left ON

The running instance was started with `--remote-debugging-port=9222`, and the user
asked to **keep it that way** to identify errors. Do not relaunch it without the
flag. Endpoint:

```bash
curl -s http://127.0.0.1:9222/json/version     # Browser: Chrome/138.0.7204.251
curl -s http://127.0.0.1:9222/json/list        # page targets
```

`~/dev/workbuddy/wb-errors.sh` attaches and dumps renderer console
errors/warnings plus uncaught exceptions:

```bash
~/dev/workbuddy/wb-errors.sh          # defaults to port 9222
```

The app's own logs live under `~/.workbuddy/logs/` (`main.log`, `renderer.log`,
`daemon.log`, `vendor-extract.log`), with a per-day directory and a `startup/`
subdir.

Note: `hub stop workbuddy` kills only the launcher wrapper — the Electron process
survives and a later launch hands off to it via `~/.workbuddy/app/SingletonLock`.
To actually restart, terminate the **whole process tree** (`pkill -TERM -f
/opt/WorkBuddy/workbuddy`, then `-KILL` if needed) and confirm nothing matches
before touching anything. The `Singleton*` entries are *live coordination
symlinks* while the app runs — remove them **only** after verifying no WorkBuddy
process remains, or a second instance can be started against a running one.

### Cleanup still available (not done — disk, not correctness)

- `cn/src` (2.1 GB) and `cn/pkg` (1.7 GB) are makepkg's extracted tree and
  staging dir. `rm -rf` them freely; makepkg recreates both.
- `cn/*.pkg.tar.zst` (520 MB) is the built package, kept so reinstall needs no
  rebuild. Delete if not wanted.
- Rollback: `sudo pacman -Rns workbuddy-cn-bin`. User data in `~/.workbuddy/` and
  `~/.config/WorkBuddy/` is **not** removed by pacman.

---

## 10. Intl install record — what was actually verified (2026-09-18)

Why the switch: the CN client gates login behind Chinese citizenship. The user
reported this directly after attempting sign-in on CN 5.5.6, which was itself
running fine. Intl is older (5.5.2 vs 5.5.6) but it is the only edition that
can authenticate here.

- Upstream (`./check-upstream.sh intl`): `5.5.2.37849279-910352f0`, already
  matching `pkg/PKGBUILD`. No checksum published for intl (API field empty).
- Download: `.../saas/linux-x64/WorkBuddy-linux-x64-5.5.2.37849279-910352f0.deb`
  (rewritten from the API's 404ing `/linux-x64-deb/...-deb-...` URL),
  exactly **429231636 bytes** per `Content-Length`. The CDN cut the connection
  three times (curl exit 18, roughly every ~170 MB); resumed with `curl -C -`
  each time. Never hashed until the size matched exactly.
- Pinned digest (self-measured, `pkg/PKGBUILD`): 
  `807159ff6d26f596cd5716b82c20ad09bbfb68d7a0264da8aa2f48ec46734cb9`
- Deb verified before build: `ar` members `debian-binary control.tar.xz
  data.tar.xz`, no GPG signature; layout `./opt/WorkBuddy AI/{workbuddyai,
  chrome-sandbox, ...}` + `./usr/share/applications/workbuddyai.desktop`;
  `Depends` identical set to CN (maps to the same 8 pacman packages);
  `postinst` creates `/usr/bin/workbuddyai` via update-alternatives with
  `ln -sf` fallback — all matching the PKGBUILD's assumptions.

| Check | Result |
|---|---|
| package | `workbuddy-intl-bin 5.5.2.37849279_910352f0-1`, installed clean via `makepkg -si`, no file conflicts |
| symlink | `/usr/bin/workbuddyai` → `/opt/WorkBuddy AI/workbuddyai` |
| sandbox | `chrome-sandbox` **755** (userns available) |
| desktop | `Exec="/opt/WorkBuddy AI/workbuddyai" %U` |
| window | `class=WorkBuddy AI` under Hyprland |
| renderer | `file:///opt/WorkBuddy%20AI/resources/app.asar/renderer/index.html?locale=en-US`, CDP `Chrome/138.0.7204.251` on :9222 |
| debug | running with `--remote-debugging-port=9222`, intentionally left on |

Swap procedure used: `pkill -TERM` the CN tree (main pid survived, `pkill
-KILL` finished it), verified `pgrep` empty, *then* removed the stale
`~/.workbuddy/app/Singleton*` symlinks, then `pacman -Rns workbuddy-cn-bin`.
CN user data (`~/.workbuddy/`, `~/.config/WorkBuddy/`) left in place.

First `wb-errors.sh` run against intl (pre-auth): same cosmetic
`[MenuRegistry] Duplicate builtin menu key` warnings (×12); `featureFlag.check`
fails with **HTTP 404** here rather than CN's 401; `[WorkBuddy Renderer] scoped
display language sync failed` was observed once — impact unknown. Re-run after
sign-in; if the 404s persist past login, that is a genuine finding.

Future updates: run `make update` (international) or `make update-cn` (CN).
It checks the API, and only if version *or* build hash changed, re-downloads
(resumable), re-pins the digest, and runs `makepkg -si`. Tested 2026-09-18 on
the up-to-date path (exits 0, no work done).
