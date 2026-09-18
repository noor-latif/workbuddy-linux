# workbuddy-linux

Arch support for [WorkBuddy](https://www.workbuddy.ai) (Tencent's AI agent):
verbatim repacks of the official Linux `.deb`s, plus a Debian/Ubuntu
installer. No source changes, no rebuilt modules, no runtime swaps.

The international update API serves an official Linux build behind a
404ing URL (rewritten here); the AUR's intl package is a macOS port
built on the assumption that none exists.

| dir | pkgname | edition | version |
|---|---|---|---|
| `intl/` | `workbuddy-intl-bin` | international | 5.5.2.37849279_910352f0 |
| `cn/` | `workbuddy-cn-bin` | mainland-China | 5.5.6.38337834_5f969292 |

## Install

Choose an edition first: outside China use **international** — CN login
requires Chinese citizenship.

### Arch

Clone this repository, then run one command:

```bash
git clone https://github.com/noor-latif/workbuddy-linux.git
cd workbuddy-linux
make install       # international
make install-cn    # mainland-China
```

Launch: `workbuddyai` (international) or `workbuddy` (CN).

### Debian/Ubuntu

No repository needed:

```bash
# international:
curl -fsSL https://raw.githubusercontent.com/noor-latif/workbuddy-linux/main/install-deb.sh | bash
# mainland-China:
curl -fsSL https://raw.githubusercontent.com/noor-latif/workbuddy-linux/main/install-deb.sh | bash -s -- cn
```

### Update and checks

```bash
make update       # international
make update-cn    # mainland-China
make check        # check international without changing files
make check-cn     # check mainland-China without changing files
```

## Notes

- Outside China use intl — **CN login requires Chinese citizenship.**
- Neither `.deb` is GPG-signed. Intl publishes no checksum; the CN API's
  advertised digest doesn't match its CDN object — both pin measured values.
- No self-update (`/opt` is root-owned, bundle ships no updater).
- `wb-errors.sh` dumps renderer errors via `--remote-debugging-port`.
- `PLAN.md` is the full install log.

Not affiliated with Tencent. No vendor binaries in this repo (see
[DISCLAIMER](DISCLAIMER); packaging under [LICENSE](LICENSE)).
