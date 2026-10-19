---
description: Security-scan the project, push it to GitHub, write the README and About section, and deploy GitHub Pages with a CI/CD workflow
argument-hint: <github repo, e.g. owner/repo or https://github.com/owner/repo> [public|private]
allowed-tools: Bash(git:*), Bash(gh:*), Bash(node:*), Bash(grep:*), Bash(ls:*), Bash(cat:*), Read, Write, Edit, Glob, Grep, mcp__playwright__browser_resize, mcp__playwright__browser_navigate, mcp__playwright__browser_take_screenshot, mcp__playwright__browser_close
---

# Publish this project to GitHub

GitHub info from the user: `$ARGUMENTS`

Do the steps below in order. Stop and report when a step fails; do not skip ahead.
Follow every rule in `CLAUDE.md`, and do not change `index.html` unless a step below says to.

## 0. Gather the GitHub info

- Parse `$ARGUMENTS` into `OWNER/REPO`, and a visibility of `public` or `private` if one is given.
- If `$ARGUMENTS` is empty or unclear, ask the user for the repo (owner/name or URL) and its visibility before doing anything else.
- Run `gh auth status`. If the user is not logged in, tell them to run `gh auth login` and stop.
- Note that GitHub Pages on a **private** repo needs a paid plan. If the repo is private, warn the user and ask whether to continue.

## 1. Security scan (before anything leaves this machine)

Nothing goes to the internet until this step passes.

1. List every file that would be pushed: `git ls-files` plus `git status --porcelain` (include untracked files that are not ignored).
2. Scan those files, and the full git history (`git log -p --all`), for:
   - secrets: API keys, tokens, passwords, private keys (`BEGIN .*PRIVATE KEY`), `AKIA…`, `ghp_…`, `github_pat_…`, `sk-…`, `xox[bap]-…`, connection strings, `.env` content
   - personal data: email addresses, phone numbers, internal hostnames or IP addresses
   - files that should not be published: `.env*`, `*.pem`, `*.key`, `*.p12`, `.DS_Store`, `.claude/settings.local.json`, editor or OS junk, large binaries
3. Run the project's own checks from `CLAUDE.md`:
   - JS syntax check:
     ```sh
     node -e 'const h=require("fs").readFileSync("index.html","utf8");new Function(h.split("<script>")[1].split("</script>")[0]);console.log("ok")'
     ```
   - constraint check (the only hit should be the formsubmit.co URL):
     ```sh
     grep -nE 'localStorage|sessionStorage|indexedDB|document\.cookie|confirm\(|alert\(|!important|https?://' index.html
     ```
   - confirm the page loads no external resources (no CDN scripts, fonts or images) and makes no network call other than `FORMSUBMIT_ENDPOINT`.
4. Create or update `.gitignore` so it covers `.DS_Store`, `.env*`, `*.pem`, `*.key`, `node_modules/` and `.claude/settings.local.json`.
5. Report the findings as a short table (file, line, what was found, risk).
   - **The email address in `FORMSUBMIT_ENDPOINT` will become public.** Point this out, and ask the user whether to publish it as is or replace it with a placeholder.
   - If any real secret is found, **stop**. Do not push. Tell the user what to remove, and that a secret already in git history has to be rotated and removed from history.
   - Continue only after the user confirms the findings are acceptable.

## 2. Push the code to GitHub

1. If the repo does not exist (`gh repo view OWNER/REPO` fails), create it: `gh repo create OWNER/REPO --<visibility> --source . --remote origin`.
2. If it exists, set `origin` to it (`git remote add origin …` or `git remote set-url origin …`). If the remote already has commits that are not in local history, stop and ask; never force-push.
3. Commit the files created in the steps below as they are made. End every commit message with the attribution lines from the system reminder, if there are any.
4. Push `main`: `git push -u origin main`.

## 3. Create or update README.md

If `README.md` exists, read it and keep any content that is still accurate. The README must contain:

- the title and a one-paragraph summary: an IT PMO Kanban board, a demo and training tool for a fictitious bank, built as one self-contained `index.html`
- **tech badges** (shields.io), including:
  - HTML5, CSS3 and JavaScript (vanilla)
  - "No dependencies" or "Zero build"
  - a GitHub Actions CI status badge for the workflow from step 5: `https://github.com/OWNER/REPO/actions/workflows/ci.yml/badge.svg`
  - a GitHub Pages / live demo badge linking to the Pages URL
  - a license badge, only if a LICENSE file exists
- a **Live demo** link: `https://OWNER.github.io/REPO/`
- a **screenshot** of the live site under the Live demo link: `![…](docs/screenshot.png)` (captured in step 7)
- **Features**: a short list taken from what `index.html` actually does (columns, drag and drop, filters, Move menu, inline delete, email notification through FormSubmit, overdue tasks)
- **How to install**: `git clone https://github.com/OWNER/REPO.git` and `cd REPO`. No npm or build step is needed.
- **How to run**: open `index.html` in a browser (`open index.html` on macOS, double-click on Windows), or use the live demo. Mention that refreshing resets the board on purpose, because nothing is stored.
- **Configuration**: the FormSubmit email lives in the `FORMSUBMIT_ENDPOINT` constant in the `CONFIG` block, and the address has to be activated once with FormSubmit
- **CI/CD**: what the workflow checks and that pushes to `main` deploy to Pages
- **Project constraints**: a short summary of the hard constraints in `CLAUDE.md`
- a disclaimer that this is a demo for a fictitious bank and is not affiliated with any real bank or system

Do not use real bank logos or trademarks.

## 4. Update the GitHub About section

```sh
gh repo edit OWNER/REPO \
  --description "IT PMO Kanban board: a single-file vanilla HTML/CSS/JS demo and training tool" \
  --homepage "https://OWNER.github.io/REPO/" \
  --add-topic kanban --add-topic vanilla-js --add-topic html --add-topic css \
  --add-topic javascript --add-topic github-pages --add-topic project-management
```

Adjust the description if the README summary differs.

## 5. CI/CD with GitHub Actions

Create `.github/workflows/ci.yml` with:

- triggers: `push` to `main`, `pull_request`, and `workflow_dispatch`
- permissions: `contents: read`, `pages: write`, `id-token: write`
- a `concurrency` group for Pages so deploys don't overlap
- **job `check`** (runs on every trigger):
  - `actions/checkout`, then `actions/setup-node` with an LTS Node version
  - the JS syntax check from step 1
  - the constraint check: fail if `grep` finds `localStorage|sessionStorage|indexedDB|document\.cookie|confirm\(|alert\(|!important`, or any `https?://` URL other than formsubmit.co
  - a secret scan (for example `gitleaks/gitleaks-action`, or a grep for the secret patterns from step 1)
- **job `deploy`**: `needs: check`, runs only on `push` to `main`
  - `actions/configure-pages`
  - copy only the site files (`index.html`, plus any other assets it needs) into a `_site/` folder, so that `.claude/`, `CLAUDE.md` and the workflows are not published
  - `actions/upload-pages-artifact` with `path: _site`
  - `actions/deploy-pages`, with `environment: github-pages` and the page URL as its output

Pin each action to a current major version (for example `@v4`).

## 6. Create the GitHub Page

1. Turn on Pages with GitHub Actions as the source:
   ```sh
   gh api -X POST repos/OWNER/REPO/pages -f build_type=workflow \
     || gh api -X PUT repos/OWNER/REPO/pages -f build_type=workflow
   ```
2. Commit the README, the workflow and `.gitignore`, then push.
3. Watch the run with `gh run watch` (or `gh run list --limit 1`). If it fails, read the logs with `gh run view --log-failed`, fix the problem and push again.
4. Get the live URL with `gh api repos/OWNER/REPO/pages --jq .html_url`, then check that it responds:
   ```sh
   curl -sI <url> | head -1
   ```

## 7. Capture a screenshot of the live site

Use the Playwright MCP server (configured in `.mcp.json`). If its tools are not available, tell the user to reload Claude Code and approve the `playwright` server, then stop this step and carry on with step 8.

1. `browser_resize` to 1440 × 900.
2. `browser_navigate` to the Pages URL from step 6.
3. `browser_take_screenshot` with `filename: "docs/screenshot.png"`, `type: "png"` and `scale: "css"` (viewport only, not full page).
4. Read the image and check that it shows the header, the filters and all four columns with cards. Retake it if the page had not finished loading.
5. `browser_close`.
6. Make sure the README shows the image under the Live demo link: `![IT PMO Kanban board with Backlog, In Progress, Blocked and Done columns](docs/screenshot.png)`.
7. Do not commit `.playwright-mcp/` (it holds Playwright's snapshots and console logs). Commit `docs/screenshot.png` and the README, then push.

The deploy job copies only `index.html`, so the screenshot appears in the README on GitHub but is not published to Pages.

## 8. Add the Pages link to the About section

Run `gh repo edit OWNER/REPO --homepage "<pages url>"` with the real URL from step 6. If the URL differs from the one used in the README, update the README and push again.

## 9. Final security check of what is public

- Run `git ls-files` on the pushed branch and confirm that no file flagged in step 1 is in it.
- Confirm the Pages artifact holds only the site files: open `<pages url>/CLAUDE.md` and `<pages url>/.claude/` and check they return 404.
- Confirm the live page makes no network request except FormSubmit, by re-running the constraint grep on the deployed `index.html`.

## 10. Report

Finish with a short summary:

- repo URL, Pages URL and the latest CI run status
- files created or changed
- security scan results, including what was published on purpose (such as the FormSubmit email)
- anything the user still has to do by hand (for example, activating the FormSubmit address)
