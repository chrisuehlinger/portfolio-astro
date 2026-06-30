#!/usr/bin/env bash
set -euo pipefail

cat >/opt/bitnami/portfolio-cms-bootstrap.txt <<'EOF'
portfolio-astro Lightsail WordPress instance.

Repository setup scripts will install the site plugin, secrets, and HTTPS after DNS is delegated.
EOF

if command -v /opt/bitnami/wp-cli/bin/wp >/dev/null 2>&1; then
  ln -sf /opt/bitnami/wp-cli/bin/wp /usr/local/bin/wp || true
fi
