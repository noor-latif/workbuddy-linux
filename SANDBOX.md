# Running the agent's Bash tool on the real host

WorkBuddy's Bash tool runs commands inside `sandbox-cli` (bwrap / minijail) by default. That
namespace has no systemd, so `systemctl`, `journalctl` and anything touching `/run/systemd`
fail — which blocks operational work on the machine.

**`"sandbox": {"enabled": false}` in `~/.workbuddy-ai/settings.json` does not turn it off.**
The desktop app ignores that key. This document records what actually controls the sandbox.

Applies to WorkBuddy AI 5.5.x on Linux. Unofficial workaround — see [DISCLAIMER](DISCLAIMER).

Agent-facing version of this document, for dropping into any agent that reads `SKILL.md` (OMP,
[CC], WorkBuddy itself): [`skills/workbuddy-sandbox-control/SKILL.md`](skills/workbuddy-sandbox-control/SKILL.md).

## Symptom

From the agent's Bash tool:

```console
$ ps -p 1 -o comm=
bash
$ ls -d /run/systemd/system
ls: cannot access '/run/systemd/system': No such file or directory
```

PID 1 is `bash` because the command is inside a namespace, not on the host. `sudo` also fails
(`setresuid: EINVAL`). Turning on `bypassPermissions` does not change any of this — see
[Sandbox and permissions are separate switches](#sandbox-and-permissions-are-separate-switches).

## Why `sandbox.enabled` in settings.json does nothing

The app resolves the sandbox from its own Security Center setting, never from the user
settings file:

1. Renderer `resolveSandboxSafetyEnabled()` reads `securityCenterGetState()` (honoured only when
   its `managed` flag is true) → else `configGet("sandboxSafetyEnabled")` → else a **hardcoded
   default of `true`**.
2. The result is persisted per session as `sessions.use_sandbox_cli` in
   `~/.workbuddy-ai/workbuddy.db`.
3. The daemon's `buildDesiredConfig()` replays it into the CLI spawn arguments:
   `--settings {"sandbox":{"enabled":true}, …}`. **CLI arguments outrank every settings file**
   (user → project → local → CLI), so nothing you write to `settings.json` can win.
4. Inside the CLI, `SandboxAgentRunInterceptor` computes
   `useSandboxCLI = shouldUseSandboxCLI(sandbox.enabled)`, and that value arms the sandbox
   lifecycle for the turn.

The fix therefore has to change (1) — the app-side value — and optionally (4) — the CLI gate.

## Fix

### 1. App-side lever (required)

In `~/.workbuddy-ai/app/app-config.json`, add:

```json
"sandboxSafetyEnabled": false
```

This file is `AppConfigService`'s store. It is loaded into memory at app start and the whole
object is rewritten on any config save, so an externally added key can be silently dropped by
an unrelated save (e.g. changing a personalization setting). Edit it while WorkBuddy is
**stopped**, and re-check it after the next start.

### 2. CLI gate (belt-and-braces)

The session CLI runs with `CODEBUDDY_FORCE_HEADLESS_BUNDLE=1`, so it loads
**`codebuddy-headless.js`**; the interactive TUI path loads `codebuddy.js`. Patch both, or the
change appears to do nothing.

In each of

- `/opt/WorkBuddy AI/resources/app.asar.unpacked/cli/dist/codebuddy.js`
- `/opt/WorkBuddy AI/resources/app.asar.unpacked/cli/dist/codebuddy-headless.js`

replace

```js
function shouldUseSandboxCLI(eA){return eA&&(0,iY.isSandboxCLIPlatformSupported)()}
```

with

```js
function shouldUseSandboxCLI(eA){return false}
```

The minified alias differs between the two bundles (`iY` vs `iG`), so **match by regex, not by
literal string**. Back each file up first:

```bash
sudo cp -p "$F" "$F.bak-$(date +%Y%m%d-%H%M%S)"
```

`configuredSandboxEnabled=false` in the verification log (below) shows the step-1 lever
propagating on its own, so this step may be redundant. It is kept as a fallback for builds where
step 1 alone does not take.

### 3. Re-apply after an app update

Updates overwrite `/opt`, so the bundle patch is lost. Re-run:

```bash
sudo node -e '
const fs=require("fs");
const dir="/opt/WorkBuddy AI/resources/app.asar.unpacked/cli/dist/";
for (const f of ["codebuddy.js","codebuddy-headless.js"]) {
  const p=dir+f;
  let c=fs.readFileSync(p,"utf8");
  const re=/function shouldUseSandboxCLI\(eA\)\{return eA&&\(0,\w+\.isSandboxCLIPlatformSupported\)\(\)\}/;
  if(!re.test(c)){console.log("NO MATCH (already patched, or bundle changed):",f);continue;}
  fs.writeFileSync(p,c.replace(re,"function shouldUseSandboxCLI(eA){return false}"),"utf8");
  console.log("patched",f);
}'
```

Then confirm `~/.workbuddy-ai/app/app-config.json` still contains
`"sandboxSafetyEnabled": false`.

## Verify

Sandbox settings are read at session start, so **restart the app and open a new session**. In
that session's Bash tool:

> **A new session is required — restarting is not enough on its own.** The sandbox flag is
> persisted per session as `use_sandbox_cli` in `~/.workbuddy-ai/workbuddy.db`, and the daemon
> replays that stored value into the CLI's spawn arguments. Only sessions created *after* the fix
> pick up the new value; every pre-existing row keeps its old one. So a *reopened* conversation
> may still be sandboxed even though the app now reports the flag as off. Judge the fix on a
> session created after the restart.

```console
$ ps -p 1 -o comm=
systemd
$ ls -d /run/systemd/system
/run/systemd/system
$ systemctl is-active <some-unit>
active
```

The app also records the decision itself. In `~/.workbuddy-ai/logs/<YYYY-MM-DD>/<username>__*.log`
(the filename is `<username>__<hash>.log`, so `*.log` also works if you are unsure of your
username):

```
[SandboxFinalState] sessionId=… permissionMode=fullAccess
  configuredSandboxEnabled=false effectiveSandboxEnabled=false
  ruleProfile=sandbox-disabled platform=linux
[SandboxAgentRunInterceptor] sandboxTurnConfig={"useSandboxCLI":false, …}
```

Judge success by `effectiveSandboxEnabled` and `useSandboxCLI`. `configuredSandboxEnabled` may
still read `true` on builds where step 1 does not apply.

A second confirmation: no per-session `vendor/sandbox/<version>/sandbox-cli` process is spawned.
The app-level `sandbox-center` service is unrelated to Bash isolation and keeps running — that
is normal.

## Revert

```bash
sudo cp -p "$F.bak-<timestamp>" "$F"
```

and remove the `sandboxSafetyEnabled` key from `app-config.json`.

## Side effects

- Automatic modify-backups / checkpoints stop: `enableFileBackup` is gated on the same flag
  (`isFileSafetyEnabled() && useSandboxCLI && …`).
- The patch lives inside the installed app, so any update reverts it.
- The agent's Bash tool then has full user-level access to the machine. That is the point, but
  it is worth being deliberate about.

## Sandbox and permissions are separate switches

These are commonly confused, and setting one does not affect the other:

| Switch | Removes | Set in |
|---|---|---|
| `permissions.defaultMode: "bypassPermissions"` | the *asking* (approval prompts) | `~/.workbuddy-ai/settings.json` |
| `sandboxSafetyEnabled` / `shouldUseSandboxCLI` | the *box* (namespace isolation) | `app-config.json` + bundle, per this document |

`bypassPermissions` is also not unconditional: `deny` and `ask` rules are still evaluated first,
and dangerous Bash commands may still require confirmation. This one *is* read from
`settings.json` and survives the app's settings merge — the app injects a `permissions` object
containing only a `deny` array, and `permissions` deep-merges across scopes.

## Untested alternative

`sandbox.excludedCommands` (in `~/.workbuddy-ai/settings.json`) exempts named commands from
isolation, and would avoid patching the app at all. It was not verified against the current
build — the `sandbox` object is deep-merged across scopes, so the list should survive the
injected `enabled: true`, but that has not been confirmed empirically. Try it first if you would
rather not touch `/opt`:

```json
"sandbox": {
  "excludedCommands": ["systemctl", "journalctl", "ps", "ls"]
}
```

Note the matching is per command root, so a compound line (`a; b`) may not be exempted as a
whole.
