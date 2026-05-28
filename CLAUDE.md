# CLAUDE.md — Vikunja 10-Day Kanban View

Project context for Claude Code. Read this at the start of every session.

## What we're building

A single-page web app that displays Vikunja tasks in a **10-day kanban view**:
one column per day for today and the the next 9 days, plus an **Overdue** column on the left.
Allow me to reduce the number of days via a drop down (10, 9, 8, etc).
Tasks are **drag-and-drop** between columns to reschedule their due date.

This fills a gap in Vikunja's built-in views — it has List, Table, Gantt, and a
status-based Kanban, but nothing that shows tasks as day-columns the way Any.do's
"7 Day" view did. (This project exists because the user migrated off Any.do and
misses that specific view.)

## Goal / definition of done (MVP)

1. Authenticates to a self-hosted Vikunja instance via REST API + personal token
2. Fetches incomplete tasks due within the next 7 days, plus overdue ones
3. Renders 8 columns: Overdue, Today, +1, +2, +3, +4, +5, +6, etc. (day names/dates as headers)
4. Each task card shows: title, project, priority indicator, and a link to open it in Vikunja
5. Drag a card from one column to another -> PATCH the task's due date to that day
6. Visual feedback on drag (highlight target column, optimistic UI update)
7. Refresh button (or auto-refresh) to re-pull from the server
8. Add Task box at the top to add a new task.  New tasks should be dropped into the current day column with today as a due date.
9, Search/filter box
10. Click on the task to edit

Nice-to-haves (later, not MVP): label badges, color-coding by
project, "no due date" backlog column, dark mode.

## Tech stack decision

- **Vanilla HTML + CSS + JS in a single file** for the MVP. No framework needed —
  the HTML5 drag-and-drop API + CSS Grid (8 columns) handle this cleanly.
  Keep dependencies at zero if possible so deployment is trivial.
- If complexity grows enough to justify it, we can revisit (lightweight options
  like Alpine.js or Svelte), but start vanilla.
- **Deployment target**: a small nginx Docker container on the user's Unraid server,
  serving the static file(s). Develop locally (open the HTML in a browser or run a
  local nginx container), then push to GitHub, then pull/build on Unraid.

## Vikunja instance details

- **Base URL**: https://tasks.fritzhurst.com
- **API base**: https://tasks.fritzhurst.com/api/v1
- **Version**: Vikunja 1.x (post-1.0 release, "latest" Docker tag)
- Exposed publicly via a Cloudflare Tunnel (Cloudflare Access has been disabled
  on this hostname so API clients can reach it directly).
- CORS is enabled on the server by default. The app's origin may need to be
  allowed, OR (since this is a static file the user controls) we may serve it
  from the same origin / handle CORS via the Vikunja config. Test early — CORS
  is the most likely first roadblock when calling the API from a browser app
  hosted on a different origin.

## Key Vikunja API facts (verify against live API, these are from prior work)

- **List tasks**: `GET /api/v1/tasks/all` — supports filtering. (Note: in Vikunja
  1.0 the endpoint to fetch all tasks moved from `/tasks/all` to `/tasks` for
  consistency — CHECK which one this instance uses by testing both.)
- **Update a task**: `POST /api/v1/tasks/{id}` (Vikunja uses POST for updates here,
  not PATCH — verify by inspecting the network tab in the web UI, or the API docs
  at https://tasks.fritzhurst.com/api/v1/docs which serves Swagger for the instance)
- **Filter syntax** (used in saved filters; may apply to API query params):
  `done = false && dueDate < now+7d`
  Date math supports now+Nd / now-Nd. Overdue = `dueDate < now`.
- **Date fields** on a task: `due_date`, `start_date`, `end_date`, `reminders`.
  Dates are ISO-8601 (e.g. `2026-05-29T02:21:03Z`). A "no date" value serializes
  as `0001-01-01T00:00:00Z` in Vikunja, not null — watch for this when checking
  whether a task has a due date.
- Confirm the exact JSON shape by hitting the live API first (see first task below).

## Auth — IMPORTANT security rule

- Auth is via a **personal API token** generated in Vikunja: Settings -> API Tokens,
  with read + write scopes on tasks.
- **NEVER commit the token to git.** Not in the HTML, not in a JS file, not in
  CLAUDE.md, nowhere that gets pushed.
- Approaches, in order of preference:
  1. A `config.js` (or `config.local.js`) file that is in `.gitignore`, holding the
     token + base URL. Provide a `config.example.js` template that IS committed.
  2. Or prompt the user for the token at runtime and store in sessionStorage (note:
     artifacts/sandboxes ban localStorage, but this is a real deployed app so
     browser storage is fine here).
- Create/maintain `.gitignore` from the start. Include `config.js`, `config.local.js`,
  `node_modules/`, `.env`, and anything else token-bearing.

## Recommended first step

Before building any UI: write a tiny throwaway script (or a minimal HTML page with
a fetch + console.log) that authenticates with the token and dumps a few tasks to
the console. 
Server is located at: https://tasks.fritzhurst.com and is exposed through a Cloudflare tunnel back to the user's UnRaid server where Vikunja is running in a Docker.
Confirm:
- Which list-tasks endpoint works (`/tasks` vs `/tasks/all`)
- Whether the update verb is POST or PATCH
- The exact JSON field names and date formats
- Whether CORS lets the browser call the API at all from a local file/origin

Get the data shape nailed down, THEN build the columns, THEN wire up drag-and-drop.
Small steps, verify each one. This matches how the rest of this project was built.

## Deployment workflow (for later)

1. Develop + test locally (browser, then local nginx container)
2. `git push` to the user's GitHub repo
3. On Unraid: clone the repo (or pull) and run an nginx container serving the file,
   OR build an image and pull it. For a static site, cloning + nginx is simplest.
4. Optionally route it through the existing Cloudflare Tunnel as its own subdomain
   (e.g. fritz-tasks.fritzhurst.com). Remember to keep the API token client-side
   and out of any committed config.

## User background (useful for calibrating help)

- Comfortable with Python, Docker, Unraid, command line, Cloudflare Tunnels.
- Less experienced with frontend JS frameworks — vanilla JS is a good fit and keeps
  things approachable. Explain frontend-specific concepts (drag events, fetch,
  CORS) a bit more than backend ones.
- Prefers incremental, verify-as-you-go development.