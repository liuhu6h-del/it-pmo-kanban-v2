# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An IT PMO Kanban board: an internal demo and training tool for a fictitious bank. The whole app is one file, `index.html`, which holds the markup, one `<style>` block and one `<script>` block.

## Hard constraints (from the original spec — do not violate)

- **No frameworks or tooling.** Use vanilla HTML, CSS and JS only: no React, jQuery, Tailwind, npm, bundler or build step.
- **Runs from `file://`.** The page must work when double-clicked, with no server.
- **No external resources.** That means no CDN scripts, web fonts or image files. Use the system font stacks (`--font`, `--font-serif`, `--font-mono`) and inline SVG icons. Design skills such as `.claude/skills/ui-ux-pro-max` may suggest Google Fonts or GSAP; ignore those parts.
- **No persistence of any kind.** Do not use localStorage, sessionStorage, IndexedDB or cookies. Refreshing resets the board to the seed data on purpose, and the UI shows a note that says so.
- **Only one network call.** The FormSubmit AJAX endpoint (`FORMSUBMIT_ENDPOINT`, in the `CONFIG` block at the top of the script) is the only network target. Keep the email address in that one constant.
- **No UOB branding.** Do not use UOB's real logo or trademarks, and do not imitate an official UOB system. The wordmark is the plain text "IT PMO". The `UOB-ITPM-####` task ID format and the `[UOB IT PMO]` email subject are kept because the spec asks for them.
- **No native dialogs.** Do not use `alert()` or `confirm()`. Delete uses an inline "Delete? Yes / No" inside the card, and validation errors appear inline under each field.
- **No `!important`.** Colours, spacing and motion come from the semantic CSS custom properties on `:root`, such as `--bg`, `--surface`, `--accent`, `--status-*`, `--prio-*` and `--dur-*`. Component rules never use raw hex values.
  - The dark palette redefines the same tokens under `:root[data-theme="dark"]`. A new colour needs a value in both places.
  - Reduced motion sets `--dur-fast`/`--dur-slow` to `0ms`, rather than overriding transitions. Use those tokens for any new transition or animation.

## Commands

There is no build, lint or test tooling.

- Run the app: `open index.html`
- Check JS syntax:
  ```sh
  node -e 'const h=require("fs").readFileSync("index.html","utf8");new Function(h.split("<script>")[1].split("</script>")[0]);console.log("ok")'
  ```
- Check for constraint violations (the only hit should be the formsubmit.co URL):
  ```sh
  grep -nE 'localStorage|sessionStorage|indexedDB|document\.cookie|confirm\(|alert\(|!important|https?://' index.html
  ```
- The syntax check assumes exactly one `<script>` block. Keep all JS in it, with no second inline script in `<head>`.
- Browser checks with the Playwright MCP: it blocks `file://` URLs, so serve the folder for the test only (`python3 -m http.server 8765 --bind 127.0.0.1`) and stop the server afterwards. Check both themes (use the header toggle or `browser_emulate_media`) and 375px width. With the placeholder email, a FormSubmit 4xx error in the console is expected.

## CI/CD and repos

- `.github/workflows/ci.yml` runs the same syntax and constraint checks plus a secret scan. On a push to `main`, it copies **only `index.html`** to `_site/` and deploys it to GitHub Pages. Any new asset must be added to that copy step, though the no-external-resources rule means there shouldn't be any.
- There are two published versions. Keep them apart:
  - local `main` → `origin` (`liuhu6h-del/it-pmo-kanban`): the original design, at https://liuhu6h-del.github.io/it-pmo-kanban/
  - local `v2` → the `v2` remote's `main` (`liuhu6h-del/it-pmo-kanban-v2`): the redesign, at https://liuhu6h-del.github.io/it-pmo-kanban-v2/. Push it with `git push v2 v2:main`.
  - Never push the `v2` branch to `origin`. Doing so would overwrite the original site.
- Keep these out of commits: `PP Assessment … .docx` (a personal assessment document), `.claude/skills/` and `skills-lock.json` (third-party skills), and `.playwright-mcp/` (ignored).

## Architecture (inside the `<script>` block)

- **One state object.** `state` holds `tasks`, `filters`, `ui` (`openMoveId`, `pendingDeleteId`, `focusAfterRender`, `theme`), `nextId` and `sending`. It is the only source of truth.
- **Theme.** `bindTheme()` (called first in `init()`) sets the starting theme from `prefers-color-scheme`. `applyTheme()` writes `data-theme` on `<html>` and updates the header `#theme-toggle` button's icon and `aria-label`. The theme is deliberately not saved, so a refresh goes back to the OS setting.
- **Icons.** Icons used in templates are `ICON_*` constants built by the `svg()` helper. They are `aria-hidden`, so the button or text around them carries the label. Static markup uses the same SVGs inline.
- **Re-render instead of patching.** Every change edits `state` and then calls `renderBoard()`, which rebuilds all columns from scratch. `renderBoard()` builds each card with `renderCard()` and then calls `renderSummary()` and `renderProgress()`. Do not change card DOM anywhere else.
  - `renderProgress()` is the one exception to rebuilding: it builds the progress-panel bars once and then updates their widths and `aria-valuenow` in place, so the CSS width transitions animate.
  - Progress is always computed from all of `state.tasks`, not the filtered list. The per-card stage stepper maps statuses through `STAGES` (Blocked shares the In Progress step).
  - Inline UI states (an open Move menu or a pending delete) live in `state.ui`, so they survive a re-render.
  - `restoreFocus()` uses `state.ui.focusAfterRender` to put keyboard focus back after the DOM is replaced.
- **Escape everything in templates.** All user-supplied strings in HTML template strings must go through `escapeHtml()`.
- **Delegated events.** One set of listeners on `#board` handles clicks (routed by `data-action` on buttons) and the HTML5 drag and drop events. Listeners are never attached to individual cards.
- **Mutations.** `addTask()`, `moveTask()` and `deleteTask()` are the only functions that change `state.tasks`. `applyFilters()` is a pure filter over the array.
- **Optimistic submit.** `handleSubmit()` validates with `validateForm()`, then calls `addTask()` (the card appears at once), closes the modal, and only then awaits `notifyNewTask()`.
  - If that call fails, a warning toast appears and the card stays on the board.
  - `notifyNewTask()` also treats a 200 response with `{ success: "false" }` as a failure. FormSubmit sends that response until the address has been activated.
- **Local dates.** Dates are local `YYYY-MM-DD` strings, from `toLocalISO()` and `todayISO()`, and are compared as strings. Do not use `toISOString()` for dates, because it is UTC and can be off by a day. Seed due dates are offsets from today (`addDays()`), so the demo always has overdue tasks.
