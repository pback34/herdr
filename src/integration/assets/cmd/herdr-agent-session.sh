#!/bin/sh
# managed by herdr; reinstalling the integration replaces this file.
# HERDR_INTEGRATION_ID=cmd
# HERDR_INTEGRATION_VERSION=1

[ "${1:-}" = "session" ] || exit 0
[ "${HERDR_ENV:-}" = "1" ] || exit 0
[ -n "${HERDR_PANE_ID:-}" ] || exit 0
[ -n "${HERDR_SOCKET_PATH:-}" ] || exit 0
if [ -n "${HERDR_BIN_PATH:-}" ]; then
    [ -x "$HERDR_BIN_PATH" ] || exit 0
else
    command -v herdr >/dev/null 2>&1 || exit 0
fi
command -v python3 >/dev/null 2>&1 || exit 0

# Command Code invokes this as a SessionStart hook with the hook payload on
# stdin. It reports session identity only: the screen manifest owns agent state,
# so this must never call `pane report-agent`. A SessionStart hook's stdout can
# be injected into the agent's next message, so every path stays silent.
python3 -c '
import json
import os
import subprocess
import sys
import time

try:
    payload = json.load(sys.stdin)
    event = payload.get("hook_event_name")
    if event not in (None, "SessionStart"):
        raise ValueError
    session_id = payload.get("session_id")
    if not isinstance(session_id, str) or not session_id:
        raise ValueError
    command = os.environ.get("HERDR_BIN_PATH") or "herdr"
    args = [
        command, "pane", "report-agent-session", os.environ["HERDR_PANE_ID"],
        "--source", "herdr:cmd", "--agent", "cmd",
        "--agent-session-id", session_id,
        "--seq", str(time.time_ns()),
        # Command Code emits SessionStart once per process, and the id it carries
        # is the session that process now owns.
        "--session-start-source", "new",
    ]
    subprocess.run(
        args,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        timeout=1,
        check=False,
    )
except Exception:
    pass
' 2>/dev/null || true
