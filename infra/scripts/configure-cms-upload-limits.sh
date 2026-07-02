#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp"
SSH_DIR="$TMP_DIR/lightsail"
REGION="${AWS_REGION:-us-east-1}"
INSTANCE_NAME="${CMS_INSTANCE_NAME:-portfolio-cms}"
UPLOAD_MAX_FILESIZE="${CMS_UPLOAD_MAX_FILESIZE:-1024M}"
POST_MAX_SIZE="${CMS_POST_MAX_SIZE:-1100M}"

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
require_command ssh

get_lightsail_access

ssh -i "$CMS_KEY" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new "${CMS_USER}@${CMS_HOST}" \
  "UPLOAD_MAX_FILESIZE='${UPLOAD_MAX_FILESIZE}' POST_MAX_SIZE='${POST_MAX_SIZE}' bash -s" <<'REMOTE'
set -euo pipefail

PHP_BIN="/opt/bitnami/php/bin/php"
CTL_SCRIPT="/opt/bitnami/ctlscript.sh"

if [[ ! -x "$PHP_BIN" ]]; then
  PHP_BIN="$(command -v php)"
fi

if [[ ! -x "$CTL_SCRIPT" ]]; then
  echo "Missing Bitnami control script: ${CTL_SCRIPT}" >&2
  exit 1
fi

php_ini="$(sudo "$PHP_BIN" --ini | awk -F':[[:space:]]*' '/Loaded Configuration File/{print $2}')"
if [[ -z "$php_ini" || "$php_ini" == "(none)" || ! -f "$php_ini" ]]; then
  echo "Could not locate loaded php.ini." >&2
  exit 1
fi

php_ini_files=("$php_ini")
for candidate in /opt/bitnami/php/etc/php.ini /opt/bitnami/php/lib/php.ini; do
  if [[ -f "$candidate" ]]; then
    already_listed=false
    for listed in "${php_ini_files[@]}"; do
      if [[ "$listed" == "$candidate" ]]; then
        already_listed=true
        break
      fi
    done

    if [[ "$already_listed" == false ]]; then
      php_ini_files+=("$candidate")
    fi
  fi
done

set_ini_value() {
  local key="$1"
  local value="$2"
  local file="$3"

  if sudo grep -Eq "^[[:space:];]*${key}[[:space:]]*=" "$file"; then
    sudo sed -i -E "s|^[[:space:];]*${key}[[:space:]]*=.*|${key} = ${value}|" "$file"
  else
    printf '\n%s = %s\n' "$key" "$value" | sudo tee -a "$file" >/dev/null
  fi
}

for ini_file in "${php_ini_files[@]}"; do
  backup="${ini_file}.bak-before-upload-limits"
  if [[ ! -f "$backup" ]]; then
    sudo cp "$ini_file" "$backup"
  fi

  set_ini_value "upload_max_filesize" "$UPLOAD_MAX_FILESIZE" "$ini_file"
  set_ini_value "post_max_size" "$POST_MAX_SIZE" "$ini_file"
done

sudo "$CTL_SCRIPT" restart php-fpm apache >/dev/null

echo "Updated PHP ini files:"
printf '  %s\n' "${php_ini_files[@]}"

sudo "$PHP_BIN" -i | awk -F'=> ' '
  /upload_max_filesize|post_max_size/ {
    gsub(/[[:space:]]+/, "", $2);
    gsub(/[[:space:]]+/, "", $3);
    printf "%s => %s\n", $1, $2;
  }
'
REMOTE

echo "Configured CMS upload limits on ${INSTANCE_NAME}: upload_max_filesize=${UPLOAD_MAX_FILESIZE}, post_max_size=${POST_MAX_SIZE}."
