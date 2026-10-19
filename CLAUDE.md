# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An IT PMO Kanban board: an internal demo and training tool for a fictitious bank. The whole app is one file, `index.html`, which holds the markup, one `<style>` block and one `<script>` block.

## Hard constraints (from the original spec — do not violate)

- **No frameworks or tooling.** Use vanilla HTML, CSS and JS only: no React, jQuery, Tailwind, npm, bundler or build step.
- **Runs from `file://`.** The page must work when double-clicked, with no server.
- **No external resources.** That means no CDN scripts, web fonts or image files. Use the system font stack and Unicode or inline SVG icons.
- **No persistence of any kind.** Do not use localStorage, sessionStorage, IndexedDB or cookies. Refreshing resets the board to the seed data on purpose, and the UI shows a note that says so.
- **Only one network call.** The FormSubmit AJAX endpoint (`FORMSUBMIT_ENDPOINT`, in the `CONFIG` block at the top of the script) is the only network target. Keep the email address in that one constant.
- **No UOB branding.** Do not use UOB's real logo or trademarks, and do not imitate an official UOB system. The wordmark is the plain text "IT PMO". The `UOB-ITPM-####` task ID format and the `[UOB IT PMO]` email subject are kept because the spec asks for them.
- **No native dialogs.** Do not use `alert()` or `confirm()`. Delete uses an inline "Delete? Yes / No" inside the card, and validation errors appear inline under each field.
- **No `!important`.** Colours and spacing come from the CSS custom properties on `:root`.

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

## Architecture (inside the `<script>` block)

- **One state object.** `state` holds `tasks`, `filters`, `ui` (`openMoveId`, `pendingDeleteId`, `focusAfterRender`), `nextId` and `sending`. It is the only source of truth.
- **Re-render instead of patching.** Every change edits `state` and then calls `renderBoard()`, which rebuilds all columns from scratch. `renderBoard()` builds each card with `renderCard()` and then calls `renderSummary()` and `renderProgress()`. Do not change card DOM anywhere else.
  - `renderProgress()` is the one exception to rebuilding: it builds the progress-panel bars once and then updates their widths and `aria-valuenow` in place, so the CSS width transitions animate.
  - Inline UI states (an open Move menu or a pending delete) live in `state.ui`, so they survive a re-render.
  - `restoreFocus()` uses `state.ui.focusAfterRender` to put keyboard focus back after the DOM is replaced.
- **Escape everything in templates.** All user-supplied strings in HTML template strings must go through `escapeHtml()`.
- **Delegated events.** One set of listeners on `#board` handles clicks (routed by `data-action` on buttons) and the HTML5 drag and drop events. Listeners are never attached to individual cards.
- **Mutations.** `addTask()`, `moveTask()` and `deleteTask()` are the only functions that change `state.tasks`. `applyFilters()` is a pure filter over the array.
- **Optimistic submit.** `handleSubmit()` validates with `validateForm()`, then calls `addTask()` (the card appears at once), closes the modal, and only then awaits `notifyNewTask()`.
  - If that call fails, a warning toast appears and the card stays on the board.
  - `notifyNewTask()` also treats a 200 response with `{ success: "false" }` as a failure. FormSubmit sends that response until the address has been activated.
- **Local dates.** Dates are local `YYYY-MM-DD` strings, from `toLocalISO()` and `todayISO()`, and are compared as strings. Do not use `toISOString()` for dates, because it is UTC and can be off by a day. Seed due dates are offsets from today (`addDays()`), so the demo always has overdue tasks.
