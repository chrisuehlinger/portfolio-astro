#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp"
SSH_DIR="$TMP_DIR/lightsail"
REGION="${AWS_REGION:-us-east-1}"
INSTANCE_NAME="${CMS_INSTANCE_NAME:-portfolio-cms}"
PLUGIN_SOURCE="$ROOT_DIR/wordpress/portfolio-content-plugin"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

get_lightsail_access() {
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"

  local details_file="$SSH_DIR/${INSTANCE_NAME}-access.json"
  local key_file="$SSH_DIR/${INSTANCE_NAME}.pem"
  local cert_file="${key_file}-cert.pub"

  aws lightsail get-instance-access-details \
    --instance-name "$INSTANCE_NAME" \
    --protocol ssh \
    --region "$REGION" >"$details_file"

  jq -r '.accessDetails.privateKey' "$details_file" >"$key_file"
  jq -r '.accessDetails.certKey' "$details_file" >"$cert_file"
  chmod 600 "$key_file" "$cert_file"

  CMS_HOST="$(jq -r '.accessDetails.ipAddress' "$details_file")"
  CMS_USER="$(jq -r '.accessDetails.username' "$details_file")"
  CMS_KEY="$key_file"
}

require_command aws
require_command jq
require_command scp
require_command ssh
require_command tar

if [[ ! -d "$PLUGIN_SOURCE" ]]; then
  echo "Missing plugin source: ${PLUGIN_SOURCE}" >&2
  exit 1
fi

mkdir -p "$TMP_DIR"
archive="$TMP_DIR/portfolio-content-plugin.tgz"
tar -czf "$archive" -C "$PLUGIN_SOURCE" .

get_lightsail_access

scp -i "$CMS_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new "$archive" "${CMS_USER}@${CMS_HOST}:/tmp/portfolio-content-plugin.tgz" >/dev/null
ssh -i "$CMS_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new "${CMS_USER}@${CMS_HOST}" <<'REMOTE'
set -euo pipefail

WP_ROOT="/opt/bitnami/wordpress"
WP_CLI="/opt/bitnami/wp-cli/bin/wp"
PLUGIN_DIR="${WP_ROOT}/wp-content/plugins/portfolio-content"

if [[ ! -x "$WP_CLI" ]]; then
  WP_CLI="$(command -v wp)"
fi

sudo rm -rf "$PLUGIN_DIR"
sudo mkdir -p "$PLUGIN_DIR"
sudo tar -xzf /tmp/portfolio-content-plugin.tgz -C "$PLUGIN_DIR"
sudo chown -R daemon:daemon "$PLUGIN_DIR"
sudo rm -f /tmp/portfolio-content-plugin.tgz

sudo "$WP_CLI" --path="$WP_ROOT" plugin activate portfolio-content --allow-root
sudo "$WP_CLI" --path="$WP_ROOT" plugin install simple-page-ordering --activate --allow-root
sudo "$WP_CLI" --path="$WP_ROOT" plugin install amazon-s3-and-cloudfront --activate --allow-root
REMOTE

echo "Installed and activated the portfolio WordPress plugin and companion plugins."
