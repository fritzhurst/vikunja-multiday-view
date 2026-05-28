#!/bin/sh
# Renders /usr/share/nginx/html/config.js and /etc/nginx/conf.d/default.conf
# from env vars at container startup, so the same image works for any Vikunja
# instance and token.
#
# Required vars:
#   VIKUNJA_URL    e.g. https://tasks.fritzhurst.com (no trailing slash needed)
#   VIKUNJA_TOKEN  a personal API token from Vikunja
set -e

: "${VIKUNJA_URL:?VIKUNJA_URL is required (e.g. https://tasks.fritzhurst.com)}"
: "${VIKUNJA_TOKEN:?VIKUNJA_TOKEN is required}"

# Strip any trailing slash so we don't end up with //api/v1 etc.
VIKUNJA_URL="${VIKUNJA_URL%/}"

cat > /usr/share/nginx/html/config.js <<EOF
window.VIKUNJA_URL = '${VIKUNJA_URL}';
window.VIKUNJA_BASE = '${VIKUNJA_URL}/api/v1';
window.VIKUNJA_TOKEN = '${VIKUNJA_TOKEN}';
EOF

# Render the nginx server config — the CSP needs the live VIKUNJA_URL in connect-src
# so the browser only allows fetch() to self + your Vikunja instance.
sed "s|__VIKUNJA_URL__|${VIKUNJA_URL}|g" \
  /etc/nginx/conf.d/default.conf.tmpl > /etc/nginx/conf.d/default.conf

echo "[vikunja-config] rendered config.js and default.conf with VIKUNJA_URL=${VIKUNJA_URL}"
