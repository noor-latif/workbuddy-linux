# workbuddy-linux

Arch support for [WorkBuddy](https://www.workbuddy.ai) (Tencent's AI agent):
verbatim repacks of the official Linux `.deb`s, plus a Debian/Ubuntu
installer. No source changes, no rebuilt modules, no runtime swaps.

The international update API serves an official Linux build behind a
404ing URL (rewritten here); the AUR's intl package is a macOS port
built on the assumption that none exists.

| dir | pkgname | edition | version |
|---|---|---|---|
| `pkg/` | `workbuddy-intl-bin` | international | 5.5.2.37849279_910352f0 |
| `cn/` | `workbuddy-cn-bin` | mainland-China | 5.5.6.38337834_5f969292 |

## Install

**Pick an edition first:** outside China, use **international** — CN login
requires Chinese citizenship and cannot authenticate here.

**Arch** (clone the repo, build the edition you picked):

```bash
cd workbuddy-linux/pkg   # international → command: workbuddyai
cd workbuddy-linux/cn    # mainland-China → command: workbuddy
makepkg -si
```

**Debian/Ubuntu** (one-liner, no repo needed):

```bash
# international:
curl -fsSL https://raw.githubusercontent.com/noor-latif/workbuddy-linux/main/install-deb.sh | bash
# mainland-China:
curl -fsSL https://raw.githubusercontent.com/noor-latif/workbuddy-linux/main/install-deb.sh | bash -s -- cn
```

## Update

```bash
workbuddy-update   # alias → ./update.sh
```

Checks the API (version **and** build hash), resumes the ~430 MB
download, re-pins the digest, runs `makepkg -si`.

## Notes

- Outside China use intl — **CN login requires Chinese citizenship.**
- Neither `.deb` is GPG-signed. Intl publishes no checksum; the CN API's
  advertised digest doesn't match its CDN object — both pin measured values.
- No self-update (`/opt` is root-owned, bundle ships no updater).
- `wb-errors.sh` dumps renderer errors via `--remote-debugging-port`.
- `PLAN.md` is the full install log.

Not affiliated with Tencent. No vendor binaries in this repo (see
[DISCLAIMER](DISCLAIMER); packaging under [LICENSE](LICENSE)).
