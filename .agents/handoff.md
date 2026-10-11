# Session Handoff — 2026-10-11 16:48 UTC

## Completed Work
- [x] Documented disabling the agent Bash sandbox (bwrap/minijail) so `systemctl`/`journalctl` reach
      the real host: added `SANDBOX.md`, linked from `README.md` under a new Troubleshooting section
      (`README.md:37-40`, `SANDBOX.md`).
- [x] Added the agent-facing copy at `skills/workbuddy-sandbox-control/SKILL.md` (drop into any agent
      that reads `SKILL.md`) and cross-linked it from `SANDBOX.md:12-13`.
- [x] Corrected the verification grep: it globbed `<username>__*.log` with a hardcoded username, so
      for every other reader it matched nothing and the documented check looked like a failure. Now
      `*.log` (`SANDBOX.md:130`, `skills/workbuddy-sandbox-control/SKILL.md:87-88`).
- [x] Documented that the sandbox flag is persisted per session (`use_sandbox_cli` in
      `~/.workbuddy-ai/workbuddy.db`) and replayed into the CLI spawn args, so a **new** session is
      required — a reopened pre-existing conversation may still be sandboxed (`SANDBOX.md:124-129`).
- [x] Published to `main`: `3e96a46`, `abf410f`, `1e36b27`.

## Current State & Verification
- **Branch / Commit:** `main` at `1e36b27`, in sync with `origin/main`.
- **Working Tree:** clean.
- **Tests & Build:** not run — this repo has no test suite, and the changes are documentation only.
  The published fix was verified independently of this repo, via the app's own log
  (`[SandboxFinalState] … effectiveSandboxEnabled=false ruleProfile=sandbox-disabled` and
  `sandboxTurnConfig={"useSandboxCLI":false}`) plus the absence of any per-session `sandbox-cli`
  process. See the Verification section of `SANDBOX.md`.
- **Processes:** no background jobs from this session. Generated package/build artifacts remain
  ignored.

## Immediate Next Steps (Actionable)
1. **Nothing is pending.** The three commits are pushed and the working tree is clean.
2. **Optional — simplify the fix.** `configuredSandboxEnabled=false` in the verification log shows the
   app-side `sandboxSafetyEnabled` key propagating on its own, so the `/opt` bundle patch may be
   redundant. To test: restore both `codebuddy*.js.bak-*` files in
   `/opt/WorkBuddy AI/resources/app.asar.unpacked/cli/dist/`, restart the app, open a new session,
   and re-check the `[SandboxFinalState]` line. If it still reads
   `effectiveSandboxEnabled=false`, the bundle patch can be dropped from the doc.
3. **Optional — convenience script.** If an automated `--unsandbox` target is wanted, add it as a
   separate explicitly-invoked target that prints what it will change. Do **not** wire it into
   `intl/PKGBUILD`'s `package()` or `update.sh`: that would silently disable a security control for
   every user and contradict the README's "without changing source" claim, and it would become a
   silent no-op if a future build moves the gate.
4. **For package maintenance**, run `make check` and `make check-cn`; update the matching `PKGBUILD`
   only when the API version/build changes.

## Known Traps & Gotchas
- **`sandbox.enabled` in `~/.workbuddy-ai/settings.json` is ignored.** The app resolves the sandbox
  from its own Security Center value, then injects it as a CLI argument (`--settings`), and CLI args
  outrank every settings file. Editing the user settings file cannot work. Full chain in `SANDBOX.md`.
- **The session CLI loads the headless bundle.** With `CODEBUDDY_FORCE_HEADLESS_BUNDLE=1` the session
  routes to `codebuddy-headless.js`, not `codebuddy.js`. Patching only one bundle makes the change
  appear inert. The minified alias also differs per bundle (`iY` vs `iG`) — match by regex, not by
  literal string.
- **Sandbox settings arm at session start and are persisted per session** in `workbuddy.db`
  (`use_sandbox_cli`). Restarting is not sufficient on its own; judge the fix on a newly created session.
- **Disabling the sandbox also turns off automatic modify-backups/checkpoints** — `enableFileBackup`
  is gated on the same flag.
- **The `/opt` patch is reverted by any app update.** Re-apply recipe is in `SANDBOX.md`; the script
  prints `NO MATCH` rather than failing silently if the bundle changes.
- The canonical repository URL is `https://github.com/noor-latif/workbuddy-linux`; the configured
  `origin` still uses the old `workbuddy-pacman` URL, which GitHub redirects.
- `remote-packages/`, `cn/src/`, `cn/pkg/`, `intl/src/`, and `intl/pkg/` are generated or downloaded
  artifacts and are intentionally ignored.
- The CN API advertises a checksum that does not match the served object. Do not replace the pinned
  measured digest without re-verifying the artifact.
- CN login requires Chinese citizenship; use the international edition outside China.
