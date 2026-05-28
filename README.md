# Vikunja Kanban

A 10-day kanban view for [Vikunja](https://vikunja.io) tasks — columns for Overdue, Today + N future days (configurable), Future, and No Date. Drag-and-drop to reschedule, with drop-between using a midpoint time so cards land exactly where you drop them.

Single static HTML file. Zero JS dependencies. Talks to Vikunja's REST API with a personal token.

## Files

- `index.html` — the entire app (HTML + CSS + JS inline)
- `config.example.js` — template; copy to `config.js` for local dev
- `config.js` — local-only, gitignored, holds your Vikunja URL + token
- `Dockerfile`, `nginx.conf`, `docker-entrypoint.d/` — production container
- `cors_test.html` — first-run CORS probe; not deployed

## Local development

1. Copy the template and fill in your URL + token:

   ```powershell
   Copy-Item config.example.js config.js
   notepad config.js
   ```

   Generate a token in Vikunja: avatar → **Settings** → **API Tokens**. Required scopes:

   - **Tasks**: `read_all` + `update` + `create`
   - **Projects**: `read_all`

2. Make sure Vikunja's CORS allows your dev origin. Either set on the Docker container:

   ```
   VIKUNJA_CORS_ENABLE=true
   VIKUNJA_CORS_ORIGINS=*
   ```

   …or list specific origins (e.g. `http://localhost:8000,https://fritz-tasks.fritzhurst.com`).

3. Serve the directory with any static server. With Python on Windows:

   ```powershell
   python -m http.server 8000
   ```

   Open `http://localhost:8000/`.

## First-time setup: push to GitHub

If this isn't already a git repo:

```powershell
cd c:\Projects\Tasks
git init
git add .
git status                              # sanity-check — no config.js, no token file
git commit -m "Initial commit"
gh repo create vikunja-kanban --private --source . --push
```

(or create the repo manually on github.com and `git remote add origin … && git push -u origin main`).

If you'd rather not use git, you can `scp` the project directory directly to Unraid and skip the clone step below.

## Production deploy on Unraid

The container is a stock `nginx:alpine` that writes `config.js` from env vars at startup, so the token never lives in the image — it's read from environment at container start.

### Build the image

On your Unraid server (or any Docker host):

```sh
git clone https://github.com/<you>/vikunja-kanban.git
cd vikunja-kanban
docker build -t vikunja-kanban:latest .
```

### Run the container

```sh
docker run -d \
  --name vikunja-kanban \
  --restart unless-stopped \
  -p 8081:8080 \
  -e VIKUNJA_URL='https://tasks.fritzhurst.com' \
  -e VIKUNJA_TOKEN='tk_yourtokenhere' \
  vikunja-kanban:latest
```

The container listens on **8080** internally (the `nginx-unprivileged` base image runs nginx as a non-root user, which can't bind to port 80). The host port can be anything you've not already used — `8081` in this example.

…or add a custom container in Unraid's Docker UI with:

- **Repository**: `vikunja-kanban:latest`
- **Network type**: bridge
- **Port**: container `8080` → host `8081` (or whichever host port is free)
- **Variables**:
  - `VIKUNJA_URL` = `https://tasks.fritzhurst.com`
  - `VIKUNJA_TOKEN` = `tk_...`

Verify locally on the Unraid box:

```sh
curl http://localhost:8081/config.js
# should print the three window.VIKUNJA_* lines with your values
```

### Optional: lock down LAN access

Cloudflare Access blocks the **public internet** from reaching the app, but anyone on your home LAN can still hit `http://<unraid-ip>:8081` directly and read the token from `config.js`. If that matters to you, bind the host port to loopback only:

```sh
docker run -d ... -p 127.0.0.1:8081:8080 ... vikunja-kanban:latest
```

Caveat: `cloudflared` must be able to reach `127.0.0.1:8081` on the Unraid host. That works if `cloudflared` is configured to use the host's network (e.g., Unraid Community Apps `cloudflared` with `--network=host`, or running as a host-level service). If `cloudflared` runs on a Docker bridge network, it can't see the host's loopback and this binding will break the tunnel — leave the default `-p 8081:8080` in that case.

### Route through Cloudflare Tunnel

In **Cloudflare Zero Trust** → **Networks** → **Tunnels**, edit the existing tunnel that serves `tasks.fritzhurst.com` and add a **Public Hostname**:

- **Subdomain**: `fritz-tasks` (or whatever name you want)
- **Domain**: `fritzhurst.com`
- **Service**: `http://<unraid-internal-ip>:8081` (or `http://localhost:8081` if cloudflared runs on the Unraid host)

Save. After a few seconds, `https://fritz-tasks.fritzhurst.com` should hit the container.

### **Important: Protect with Cloudflare Access**

`config.js` is served as plain text — anyone who reaches the URL can read the token and use it against your Vikunja API. Unlike the Vikunja API hostname (where Access is disabled), this hostname **must** be gated.

In **Cloudflare Zero Trust** → **Access** → **Applications** → **Add an application** → **Self-hosted**:

- **Application name**: `Vikunja Kanban`
- **Session duration**: a generous value (e.g. 30 days) so you're not re-authing constantly
- **Application domain**: `fritz-tasks.fritzhurst.com`

Add a policy:

- **Policy name**: `Just me`
- **Action**: `Allow`
- **Rules**: Include → **Emails** → `fhurst@gmail.com` (or whichever identity provider you use)

Save. Visit `https://fritz-tasks.fritzhurst.com` — you should get a Cloudflare login screen, then the app. Random visitors get blocked at the edge before the container is ever reached.

## Updates

Pull and rebuild:

```sh
cd vikunja-kanban
git pull
docker build -t vikunja-kanban:latest .
docker stop vikunja-kanban && docker rm vikunja-kanban
docker run -d --name vikunja-kanban --restart unless-stopped \
  -p 8081:8080 \
  -e VIKUNJA_URL='https://tasks.fritzhurst.com' \
  -e VIKUNJA_TOKEN='tk_yourtokenhere' \
  vikunja-kanban:latest
```

`nginx.conf` sets `Cache-Control: no-store` on everything, so users see updates on the next page load — no hard refresh needed.

## Rotating the token

When you rotate the Vikunja API token, just update the `VIKUNJA_TOKEN` env var on the container and restart it. The entrypoint regenerates `config.js`. No image rebuild required.

```sh
docker stop vikunja-kanban && docker rm vikunja-kanban
docker run -d --name vikunja-kanban --restart unless-stopped \
  -p 8081:8080 \
  -e VIKUNJA_URL='https://tasks.fritzhurst.com' \
  -e VIKUNJA_TOKEN='tk_new_token_here' \
  vikunja-kanban:latest
```

## What does NOT go in git

The `.gitignore` excludes:

- `config.js` (local token-bearing config)
- `Vikunja_Tasks_Token.txt` (raw token file)
- `node_modules/`, `dist/`, `.env*`, editor folders

Before pushing, run `git status` and make sure none of those appear in the diff.
