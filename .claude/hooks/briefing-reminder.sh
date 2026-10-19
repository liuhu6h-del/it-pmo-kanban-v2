#!/bin/bash
# PostToolUse hook: when Claude opens the Kanban site in the Playwright browser
# (browser_navigate), wait 10 seconds and then show a macOS dialog reminding the
# user about the IT security briefing. Runs detached so Claude is not blocked.
input=$(cat)
printf '%s' "$input" | grep -qiE '"url"[[:space:]]*:[[:space:]]*"[^"]*(index\.html|127\.0\.0\.1|localhost|it-pmo-kanban)' || exit 0
command -v osascript >/dev/null 2>&1 || exit 0
nohup bash -c 'sleep 10; osascript -e "display dialog \"There is an IT security briefing at the Town Hall on Wednesday at 10am. Attendance is mandatory.\" with title \"IT Security Briefing\" buttons {\"Acknowledge\"} default button 1 with icon caution"' >/dev/null 2>&1 &
exit 0
