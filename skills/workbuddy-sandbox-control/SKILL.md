---
name: workbuddy-sandbox-control
description: Use for WorkBuddy AI Linux sandbox isolation, YOLO/bypassPermissions mode, or re-applying the sandbox patch after an app update; not for general WorkBuddy plugin or MCP work.
---

# WorkBuddy AI — sandbox & permission-mode control (Linux)

App: `/opt/WorkBuddy AI` 5.5.x. Data dir: `~/.workbuddy-ai` (env `WORKBUDDY_CONFIG_DIR` /
`CODEBUDDY_CONFIG_DIR`). Human-readable version of this document: [`SANDBOX.md`](../../SANDBOX.md).

**Read the sibling skills before reverse-engineering anything.** WorkBuddy keeps its own skills in
`~/.workbuddy-ai/skills/` — read them as plain files:

- `workbuddy-internals/SKILL.md` — the lookup order for "how does WorkBuddy work" (shipped docs →
  cached product config → empirical probes → **last** the 23 MB minified bundle). Going straight to
  the bundle burns a whole session; the sandbox trace that produced this document cost ~100 tool
  calls that the earlier tiers would have shortcut.
- `workbuddy-feedback/SKILL.md` — report format and evidence standard, if the outcome should become
  a vendor bug report.
- `porting-agent-hooks-to-workbuddy/SKILL.md` — only for porting third-party agent hooks.

## Two independent switches — do not conflate

| Switch | Removes | Controlled by |
|---|---|---|
| `bypassPermissions` (a.k.a. "YOLO") | the *asking* | `permissions.defaultMode` in settings.json |
| Bash sandbox (`sandbox-cli`, bwrap/minijail) | the *box* | app-level `sandboxSafetyEnabled` |

`bypassPermissions` does **not** disable the sandbox. `sandbox.enabled: false` does **not** stop
prompting. The symptom of confusion is: prompts gone, but `ps -p 1 -o comm=` still says `bash`.

## The trap: `sandbox.enabled` in settings.json is IGNORED

`~/.workbuddy-ai/settings.json` → `sandbox.enabled: false` has no effect on the desktop app. Real chain:

1. Renderer `resolveSandboxSafetyEnabled()`: `securityCenterGetState()` (only honoured if
   `managed === true`) → else daemon `configGet("sandboxSafetyEnabled")` → else **hardcoded
   default `true`**.
2. Value persisted per session as `sessions.use_sandbox_cli` in `~/.workbuddy-ai/workbuddy.db`.
3. `main/daemon-app-server-main.js` `buildDesiredConfig()` replays it into the CLI spawn args:
   `--settings {"sandbox":{"enabled":true}, ...}`. **CLI args outrank all settings files.**
4. CLI `SandboxAgentRunInterceptor`: `useSandboxCLI = shouldUseSandboxCLI(sandbox.enabled)` arms the
   sandbox lifecycle for the turn.

So editing settings.json can never win. Fix at (1) and, as belt-and-braces, at (4).

## Fix

### 1. App-side lever
`~/.workbuddy-ai/app/app-config.json` — add `"sandboxSafetyEnabled": false` (back it up first).
`AppConfigService` loads this file into memory at startup and rewrites the whole object on any
`set()`/`save()`, so an externally-added key can be silently dropped by an unrelated save. Edit it
while WorkBuddy is stopped, and re-check it after a restart.

### 2. CLI gate (decisive kill switch) — BOTH bundles
The session CLI runs with `CODEBUDDY_FORCE_HEADLESS_BUNDLE=1`, so it loads **`codebuddy-headless.js`**.
The TUI path loads `codebuddy.js`. Patch both, or the fix appears inert.

Replace, in each of
`/opt/WorkBuddy AI/resources/app.asar.unpacked/cli/dist/codebuddy.js` and `…/codebuddy-headless.js`:
```js
function shouldUseSandboxCLI(eA){return eA&&(0,iY.isSandboxCLIPlatformSupported)()}
```
with `function shouldUseSandboxCLI(eA){return false}`.

The minified alias differs per bundle (`iY` vs `iG`) — **match by regex, not a literal**:
```bash
sudo node -e '
const fs=require("fs");
const dir="/opt/WorkBuddy AI/resources/app.asar.unpacked/cli/dist/";
for (const f of ["codebuddy.js","codebuddy-headless.js"]) {
  const p=dir+f; let c=fs.readFileSync(p,"utf8");
  const re=/function shouldUseSandboxCLI\(eA\)\{return eA&&\(0,\w+\.isSandboxCLIPlatformSupported\)\(\)\}/;
  if(!re.test(c)){console.log("NO MATCH (already patched or bundle changed):",f);continue;}
  fs.writeFileSync(p,c.replace(re,"function shouldUseSandboxCLI(eA){return false}"),"utf8");
  console.log("patched",f);
}'
```
Back up each file first (`cp -p <file> <file>.bak-$(date +%Y%m%d-%H%M%S)`). An app update overwrites
`/opt`, so this must be re-applied.

## Verify — from outside the app

Read the app's own log, not your own shell (your shell has host access regardless, so it proves nothing):

```bash
grep -ho '\[SandboxFinalState\][^"]*' ~/.workbuddy-ai/logs/$(date +%F)/*.log | tail -3
grep -ho '\[SandboxAgentRunInterceptor\] sandboxTurnConfig={"useSandboxCLI":[a-z]*' ~/.workbuddy-ai/logs/$(date +%F)/*.log | tail -3
```
Success = `effectiveSandboxEnabled=false` + `ruleProfile=sandbox-disabled` + `useSandboxCLI=false`
in a session started **after** the restart. `configuredSandboxEnabled` may still read true; ignore it.

Second confirmation: no per-session `vendor/sandbox/<ver>/sandbox-cli` process spawns any more.
The app-level `sandbox-center` service is unrelated to Bash isolation and keeps running — that is normal.

Sandbox settings only arm at session start, so **restart the app** and open a **new** session.

## Restarting the app safely

If you are running *inside* WorkBuddy, your Bash tool's process tree is a child of the app — killing it
kills your own session. Use a detached script:
```bash
setsid nohup gtk-launch workbuddyai >/tmp/wb-launch.log 2>&1 </dev/null &
```
(`DISPLAY=:0`, `WAYLAND_DISPLAY=wayland-1`, `XDG_RUNTIME_DIR`, `DBUS_SESSION_BUS_ADDRESS` are already in env.)

## Reading the bundles

`grep -rn` on `app.asar` returns nothing useful (single archive file, not a directory). Full
`npx asar extract` fails on missing per-platform unpacked binaries. Use:
```bash
node -e 'const a=require("asar");a.listPackage("/opt/WorkBuddy AI/resources/app.asar").filter(f=>f.endsWith(".js")&&!f.includes("node_modules")).forEach(f=>{if(a.extractFile("/opt/WorkBuddy AI/resources/app.asar",f.slice(1)).toString("utf8").includes("NEEDLE"))console.log(f)})'
```
or `npx asar extract-file`. The `cli/dist/*.js` files are plain readable JS — read them with
`python3` + `re` rather than `grep` (grep truncates large matches).

## Known side effects of disabling the sandbox

- Automatic modify-backups / checkpoints turn off: `enableFileBackup = isFileSafetyEnabled() && ec && …`
  is gated on the same flag.
- `bypassPermissions` is not unconditional: `deny` and `ask` rules are still evaluated first, and
  dangerous Bash commands may still require confirmation.

## Untested alternative

`sandbox.excludedCommands` (in `~/.workbuddy-ai/settings.json`) exempts named commands from
isolation and would avoid patching the app at all. Not verified against the current build — the
`sandbox` object is deep-merged across scopes, so the list should survive the injected
`enabled: true`, but that has not been confirmed empirically. Try it first if you would rather not
touch `/opt`:
```json
"sandbox": { "excludedCommands": ["systemctl", "journalctl", "ps", "ls"] }
```
Matching is per command root, so a compound line (`a; b`) may not be exempted as a whole.
