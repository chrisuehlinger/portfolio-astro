#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STACK_DIR="$ROOT_DIR/infra/stacks/main"
TMP_DIR="$ROOT_DIR/.tmp"
SECRET_DIR="$TMP_DIR/secrets"
SSH_DIR="$TMP_DIR/lightsail"
REGION="${AWS_REGION:-us-east-1}"
INSTANCE_NAME="${CMS_INSTANCE_NAME:-portfolio-cms}"
GITHUB_REPO="${PORTFOLIO_GITHUB_REPO:-chrisuehlinger/portfolio-astro}"
GITHUB_WORKFLOW="${PORTFOLIO_GITHUB_WORKFLOW:-deploy.yml}"
GITHUB_REF="${PORTFOLIO_GITHUB_REF:-main}"
MEDIA_DOMAIN="${PORTFOLIO_MEDIA_DOMAIN:-media.chrisuehlinger.com}"

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

ensure_file_token() {
  local path="$1"

  mkdir -p "$(dirname "$path")"
  chmod 700 "$(dirname "$path")"

  if [[ ! -f "$path" ]]; then
    openssl rand -hex 32 >"$path"
    chmod 600 "$path"
  fi

  tr -d '\n' <"$path"
}

ensure_github_token() {
  if [[ -n "${PORTFOLIO_GITHUB_TOKEN:-}" ]]; then
    printf '%s' "$PORTFOLIO_GITHUB_TOKEN"
    return
  fi

  local token_file="$SECRET_DIR/github-actions-pat"
  if [[ -f "$token_file" ]]; then
    tr -d '\n' <"$token_file"
    return
  fi

  local token
  read -rsp "GitHub fine-grained PAT with Actions write access (leave empty to skip rebuild trigger): " token
  echo

  if [[ -n "$token" ]]; then
    mkdir -p "$SECRET_DIR"
    chmod 700 "$SECRET_DIR"
    printf '%s' "$token" >"$token_file"
    chmod 600 "$token_file"
  fi

  printf '%s' "$token"
}

ensure_media_key() {
  local user_name="$1"
  local access_key_file="$SECRET_DIR/wp-media-access-key-id"
  local secret_key_file="$SECRET_DIR/wp-media-secret-access-key"

  mkdir -p "$SECRET_DIR"
  chmod 700 "$SECRET_DIR"

  if [[ -n "${WP_MEDIA_ACCESS_KEY_ID:-}" && -n "${WP_MEDIA_SECRET_ACCESS_KEY:-}" ]]; then
    MEDIA_ACCESS_KEY_ID="$WP_MEDIA_ACCESS_KEY_ID"
    MEDIA_SECRET_ACCESS_KEY="$WP_MEDIA_SECRET_ACCESS_KEY"
    return
  fi

  if [[ -f "$access_key_file" && -f "$secret_key_file" ]]; then
    MEDIA_ACCESS_KEY_ID="$(tr -d '\n' <"$access_key_file")"
    MEDIA_SECRET_ACCESS_KEY="$(tr -d '\n' <"$secret_key_file")"
    return
  fi

  local existing_keys
  existing_keys="$(aws iam list-access-keys --user-name "$user_name" --output json)"
  local existing_count
  existing_count="$(jq '.AccessKeyMetadata | length' <<<"$existing_keys")"

  if [[ "$existing_count" == "0" ]]; then
    local key_json
    key_json="$(aws iam create-access-key --user-name "$user_name" --output json)"
    MEDIA_ACCESS_KEY_ID="$(jq -r '.AccessKey.AccessKeyId' <<<"$key_json")"
    MEDIA_SECRET_ACCESS_KEY="$(jq -r '.AccessKey.SecretAccessKey' <<<"$key_json")"
    printf '%s' "$MEDIA_ACCESS_KEY_ID" >"$access_key_file"
    printf '%s' "$MEDIA_SECRET_ACCESS_KEY" >"$secret_key_file"
    chmod 600 "$access_key_file" "$secret_key_file"
    return
  fi

  MEDIA_ACCESS_KEY_ID="$(jq -r '.AccessKeyMetadata[0].AccessKeyId' <<<"$existing_keys")"
  read -rsp "Existing media IAM access key found. Enter its SecretAccessKey: " MEDIA_SECRET_ACCESS_KEY
  echo

  if [[ -z "$MEDIA_SECRET_ACCESS_KEY" ]]; then
    echo "Cannot recover an existing IAM SecretAccessKey. Provide WP_MEDIA_SECRET_ACCESS_KEY or rotate the key manually." >&2
    exit 1
  fi

  printf '%s' "$MEDIA_ACCESS_KEY_ID" >"$access_key_file"
  printf '%s' "$MEDIA_SECRET_ACCESS_KEY" >"$secret_key_file"
  chmod 600 "$access_key_file" "$secret_key_file"
}

php_define() {
  local name="$1"
  local value="$2"
  printf "define('%s', '%s');\n" "$name" "$value"
}

require_command aws
require_command jq
require_command openssl
require_command scp
require_command ssh
require_command tofu

cms_build_token="$(ensure_file_token "$SECRET_DIR/cms-build-token")"
github_token="$(ensure_github_token)"
media_bucket="$(cd "$STACK_DIR" && tofu output -raw media_bucket)"
media_user="$(cd "$STACK_DIR" && tofu output -raw wordpress_media_iam_user)"
ensure_media_key "$media_user"
get_lightsail_access

secrets_file="$SECRET_DIR/wp-config-portfolio-secrets.php"
{
  echo "<?php"
  php_define "PORTFOLIO_BUILD_TOKEN" "$cms_build_token"
  php_define "PORTFOLIO_GITHUB_TOKEN" "$github_token"
  php_define "PORTFOLIO_GITHUB_REPO" "$GITHUB_REPO"
  php_define "PORTFOLIO_GITHUB_WORKFLOW" "$GITHUB_WORKFLOW"
  php_define "PORTFOLIO_GITHUB_REF" "$GITHUB_REF"
  cat <<PHP
define('AS3CF_SETTINGS', serialize([
    'provider' => 'aws',
    'access-key-id' => '${MEDIA_ACCESS_KEY_ID}',
    'secret-access-key' => '${MEDIA_SECRET_ACCESS_KEY}',
    'bucket' => '${media_bucket}',
    'region' => '${REGION}',
    'copy-to-s3' => true,
    'serve-from-s3' => true,
    'remove-local-file' => true,
    'object-prefix' => 'wp-content/uploads/',
    'enable-delivery-domain' => true,
    'delivery-domain' => '${MEDIA_DOMAIN}',
    'force-https' => true,
]));
PHP
} >"$secrets_file"
chmod 600 "$secrets_file"

scp -i "$CMS_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new "$secrets_file" "${CMS_USER}@${CMS_HOST}:/tmp/wp-config-portfolio-secrets.php" >/dev/null
ssh -i "$CMS_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new "${CMS_USER}@${CMS_HOST}" <<'REMOTE'
set -euo pipefail

WP_ROOT="/opt/bitnami/wordpress"
SECRET_FILE="${WP_ROOT}/wp-config-portfolio-secrets.php"
INCLUDE_LINE="require_once __DIR__ . '/wp-config-portfolio-secrets.php';"

sudo install -o root -g daemon -m 0640 /tmp/wp-config-portfolio-secrets.php "$SECRET_FILE"
sudo rm -f /tmp/wp-config-portfolio-secrets.php

if ! sudo grep -q "wp-config-portfolio-secrets.php" "${WP_ROOT}/wp-config.php"; then
  sudo sed -i "/^<?php/a ${INCLUDE_LINE}" "${WP_ROOT}/wp-config.php"
fi
REMOTE

echo "Installed WordPress secret constants on ${INSTANCE_NAME} without printing secret values."
echo "CMS build token is stored locally at ${SECRET_DIR}/cms-build-token for GitHub secret configuration."
