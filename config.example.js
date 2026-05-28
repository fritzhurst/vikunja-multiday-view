// Template — copy to config.js and fill in. config.js is gitignored so the token
// stays local. In the Docker deployment, config.js is generated at container
// startup from the VIKUNJA_URL and VIKUNJA_TOKEN env vars (see Dockerfile +
// docker-entrypoint.d/10-vikunja-config.sh), so you do NOT bake config.js into
// the image.
window.VIKUNJA_URL = 'https://tasks.example.com';
window.VIKUNJA_BASE = window.VIKUNJA_URL + '/api/v1';
window.VIKUNJA_TOKEN = 'tk_paste_your_token_here';
