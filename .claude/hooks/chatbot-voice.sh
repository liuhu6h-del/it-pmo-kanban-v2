#!/bin/bash
# PostToolUse hook: when Claude clicks the floating WhatsApp chatbot icon in the
# browser (Playwright MCP browser_click), speak "How can I help you" aloud.
# Claude Code passes the tool call as JSON on stdin; we only look at the clicked
# element's description, so other clicks stay silent.
input=$(cat)
if printf '%s' "$input" | grep -qiE '"element"[[:space:]]*:[[:space:]]*"[^"]*(chat|whatsapp)'; then
  if command -v say >/dev/null 2>&1; then
    say "How can I help you" >/dev/null 2>&1 &
  elif command -v spd-say >/dev/null 2>&1; then
    spd-say "How can I help you" >/dev/null 2>&1 &
  fi
fi
exit 0
