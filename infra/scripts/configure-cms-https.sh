#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp"
SSH_DIR="$TMP_DIR/lightsail"
REGION="${AWS_REGION:-us-east-1}"
INSTANCE_NAME="${CMS_INSTANCE_NAME:-portfolio-cms}"
CMS_DOMAIN="${CMS_DOMAIN:-cms.chrisuehlinger.com}"
LETSENCRYPT_EMAIL="${LETSENCRYPT_EMAIL:-$(git config --global user.email || true)}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

require_command aws
require_command git
require_command jq
require_command ssh

if [[ -z "$LETSENCRYPT_EMAIL" ]]; then
  LETSENCRYPT_EMAIL="you@example.com"
fi

details_file="$SSH_DIR/${INSTANCE_NAME}-access.json"
key_file="$SSH_DIR/${INSTANCE_NAME}.pem"
cert_file="${key_file}-cert.pub"

aws lightsail get-instance-access-details \
  --instance-name "$INSTANCE_NAME" \
  --protocol ssh \
  --region "$REGION" >"$details_file"

jq -r '.accessDetails.privateKey' "$details_file" >"$key_file"
jq -r '.accessDetails.certKey' "$details_file" >"$cert_file"
chmod 600 "$key_file" "$cert_file"

cms_host="$(jq -r '.accessDetails.ipAddress' "$details_file")"
cms_user="$(jq -r '.accessDetails.username' "$details_file")"

cat <<MSG
The Bitnami HTTPS tool on this image does not support unattended mode.
Use these values in the prompt:

- Domain list: ${CMS_DOMAIN}
- Add www domain: n
- Enable HTTP to HTTPS redirection: Y
- E-mail address: ${LETSENCRYPT_EMAIL}
- Accept Let's Encrypt Subscriber Agreement: Y
MSG

ssh -tt -i "$key_file" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new "$cms_user@$cms_host" \
  "sudo /opt/bitnami/bncert-tool --installdir /opt/bitnami"
