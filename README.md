# Vikunja Multi-day View

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
gh repo create vikunja-multiday-view --private --source . --push
```

(or create the repo manually on github.com and `git remote add origin … && git push -u origin main`).

If you'd rather not use git, you can `scp` the project directory directly to Unraid and skip the clone step below.

## Production deploy on Unraid

The container is a stock `nginxinc/nginx-unprivileged:alpine` that writes `config.js` from env vars at startup, so the token never lives in the image — it's read from environment at container start.

The repo ships an Unraid container template (`vikunja-multiday-view.xml`) so the Docker → Add Container form pre-populates everything except the values you must customize (URL and token).

### Install via the Unraid template (recommended)

On the Unraid box:

```sh
mkdir -p /mnt/user/appdata/vikunja-multiday-view
cd /mnt/user/appdata/vikunja-multiday-view
git clone https://github.com/fritzhurst/vikunja-multiday-view.git .
docker build -t vikunja-multiday-view:latest .

# Drop the template where Unraid's Docker tab will find it:
cp vikunja-multiday-view.xml /boot/config/plugins/dockerMan/templates-user/my-vikunja-multiday-view.xml
```

Then in Unraid's WebUI:

1. **Docker** → **Add Container**.
2. **Template** dropdown at the top → pick **vikunja-multiday-view**. All fields pre-fill (name, repository, port `3457`, env vars with helpful descriptions and a masked token field).
3. Replace the placeholder **Vikunja URL** (`https://tasks.example.com`) with your real Vikunja URL.
4. Paste your **Vikunja API Token** (the field is masked).
5. *(Optional)* Change host port `3457` if it conflicts with something on your box.
6. **Apply**. Unraid runs the container, the entrypoint renders `config.js` and `default.conf`, and the new container shows up in the Docker tab.

Future updates:
```sh
cd /mnt/user/appdata/vikunja-multiday-view
git pull
docker build -t vikunja-multiday-view:latest .
```
Then in the Docker tab, click the container icon → **Update** (or stop/start). The template stays as-is.

### Build the image (manual / non-Unraid Docker hosts)

On your Unraid server (or any Docker host):

```sh
git clone https://github.com/<you>/vikunja-multiday-view.git
cd vikunja-multiday-view
docker build -t vikunja-multiday-view:latest .
```

### Run the container

```sh
docker run -d \
  --name vikunja-multiday-view \
  --restart unless-stopped \
  -p 8081:8080 \
  -e VIKUNJA_URL='https://tasks.fritzhurst.com' \
  -e VIKUNJA_TOKEN='tk_yourtokenhere' \
  vikunja-multiday-view:latest
```

The container listens on **8080** internally (the `nginx-unprivileged` base image runs nginx as a non-root user, which can't bind to port 80). The host port can be anything you've not already used — `8081` in this example.

…or add a custom container in Unraid's Docker UI with:

- **Repository**: `vikunja-multiday-view:latest`
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
docker run -d ... -p 127.0.0.1:8081:8080 ... vikunja-multiday-view:latest
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

- **Application name**: `Vikunja Multi-day View`
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
cd vikunja-multiday-view
git pull
docker build -t vikunja-multiday-view:latest .
docker stop vikunja-multiday-view && docker rm vikunja-multiday-view
docker run -d --name vikunja-multiday-view --restart unless-stopped \
  -p 8081:8080 \
  -e VIKUNJA_URL='https://tasks.fritzhurst.com' \
  -e VIKUNJA_TOKEN='tk_yourtokenhere' \
  vikunja-multiday-view:latest
```

`nginx.conf` sets `Cache-Control: no-store` on everything, so users see updates on the next page load — no hard refresh needed.

## Rotating the token

When you rotate the Vikunja API token, just update the `VIKUNJA_TOKEN` env var on the container and restart it. The entrypoint regenerates `config.js`. No image rebuild required.

```sh
docker stop vikunja-multiday-view && docker rm vikunja-multiday-view
docker run -d --name vikunja-multiday-view --restart unless-stopped \
  -p 8081:8080 \
  -e VIKUNJA_URL='https://tasks.fritzhurst.com' \
  -e VIKUNJA_TOKEN='tk_new_token_here' \
  vikunja-multiday-view:latest
```

## What does NOT go in git

The `.gitignore` excludes:

- `config.js` (local token-bearing config)
- `Vikunja_Tasks_Token.txt` (raw token file)
- `node_modules/`, `dist/`, `.env*`, editor folders

Before pushing, run `git status` and make sure none of those appear in the diff.

## License

MIT — see [LICENSE](LICENSE). Use it, fork it, ship a fancier version, no obligation to publish your changes back. A heads-up if you do something cool with it is appreciated but not required.
