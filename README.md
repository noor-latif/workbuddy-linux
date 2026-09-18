# workbuddy-linux

## Install

Use **international** outside China. CN login requires Chinese citizenship.

### Arch

```bash
git clone https://github.com/noor-latif/workbuddy-linux.git
cd workbuddy-linux
make install       # international
make install-cn    # mainland China
```

Launch with `workbuddyai` (international) or `workbuddy` (CN).

### Debian/Ubuntu

```bash
# international
curl -fsSL https://raw.githubusercontent.com/noor-latif/workbuddy-linux/main/install-deb.sh | bash

# mainland China
curl -fsSL https://raw.githubusercontent.com/noor-latif/workbuddy-linux/main/install-deb.sh | bash -s -- cn
```

## Update and check (Arch)

```bash
make update       # international
make update-cn    # mainland China
make check        # check international
make check-cn     # check mainland China
```

## Community

[WorkBuddy Discord](https://discord.gg/MKB4JVtKab) — ask for a corrected
Linux URL, published checksum, and confirmation of Linux support.

## About

This repo repackages Tencent's official Linux `.deb`s without changing source,
Electron, or native modules. The international API currently returns a broken
CDN URL; `intl/` corrects it. Builds are generated locally, so this repo ships
no vendor binaries.

Not affiliated with Tencent. See [DISCLAIMER](DISCLAIMER) and [LICENSE](LICENSE).
