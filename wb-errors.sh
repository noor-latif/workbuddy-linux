#!/usr/bin/env bash
# Dump renderer errors from WorkBuddy's DevTools endpoint.
#
# The app runs with --remote-debugging-port=9222 on purpose, so errors can be
# identified live. This attaches, enables the Log and Runtime domains (Log.enable
# replays entries buffered before we attached), collects for a short window, and
# prints anything at error/warning level.
#
# Usage: wb-errors.sh [port] [collect-seconds]
set -uo pipefail
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  sed -n '2,9p' "$0"
  exit 0
fi
PORT="${1:-9222}"
SECS="${2:-3}"

list=$(curl -s -m 8 "http://127.0.0.1:${PORT}/json/list") || { echo "CDP unreachable on :${PORT}" >&2; exit 1; }
wsurl=$(jq -r '.[] | select(.type=="page") | .webSocketDebuggerUrl' <<<"$list" | head -1)
if [[ -z "$wsurl" || "$wsurl" == "null" ]]; then
  echo "no page target on :${PORT}" >&2
  exit 1
fi

exec node -e '
const [url, secs] = process.argv.slice(1);
const out = [];
let id = 0;
const pending = new Map();
const ws = new WebSocket(url);

// Handler MUST be attached before any send(), or the first reply is lost and
// the promise never settles.
ws.onmessage = (e) => {
  const m = JSON.parse(e.data);
  if (m.id !== undefined && pending.has(m.id)) {
    pending.get(m.id)(m);
    pending.delete(m.id);
    return;
  }
  const p = m.params ?? {};
  if (m.method === "Log.entryAdded") {
    const { level, text, url: src } = p.entry ?? {};
    if (level === "error" || level === "warning")
      out.push(`[log:${level}] ${text}${src ? `  (${src})` : ""}`);
  } else if (m.method === "Runtime.consoleAPICalled") {
    if (p.type === "error" || p.type === "warning") {
      const txt = (p.args ?? []).map(a => a.value ?? a.description ?? "").join(" ").trim();
      if (txt) out.push(`[console:${p.type}] ${txt}`);
    }
  } else if (m.method === "Runtime.exceptionThrown") {
    const ex = p.exceptionDetails ?? {};
    out.push(`[exception] ${ex.exception?.description ?? ex.text ?? "unknown"}`);
  }
};

const send = (method, params = {}) =>
  new Promise(r => { const n = ++id; pending.set(n, r); ws.send(JSON.stringify({ id: n, method, params })); });

ws.onerror = (e) => { console.error("websocket error:", e?.message ?? String(e)); process.exit(1); };

ws.onopen = async () => {
  await send("Log.enable");
  await send("Runtime.enable");
  setTimeout(() => {
    const uniq = [...new Set(out)];
    console.log(uniq.length ? uniq.join("\n") : "(no errors or warnings)");
    process.exit(0);
  }, Number(secs) * 1000);
};
' "$wsurl" "$SECS"