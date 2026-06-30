#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STACK_DIR="$ROOT_DIR/infra/stacks/main"
REPO="${GITHUB_REPO:-chrisuehlinger/portfolio-astro}"
CMS_ENDPOINT="${CMS_BUILD_ENDPOINT:-https://cms.chrisuehlinger.com/wp-json/portfolio/v1/build}"
CMS_TOKEN="${CMS_BUILD_TOKEN:-}"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required command: $1" >&2
    exit 1
  fi
}

set_secret() {
  local name="$1"
  local value="$2"

  if [[ -z "$value" ]]; then
    echo "Skipping ${name}; no value provided."
    return
  fi

  gh secret set "$name" --repo "$REPO" --body "$value" >/dev/null
  echo "Set ${name} for ${REPO}."
}

require_command gh
require_command tofu

aws_role_arn="$(cd "$STACK_DIR" && tofu output -raw github_actions_role_arn)"
site_bucket="$(cd "$STACK_DIR" && tofu output -raw site_bucket)"
site_distribution_id="$(cd "$STACK_DIR" && tofu output -raw site_cloudfront_distribution_id)"

if [[ -z "$CMS_TOKEN" && -f "$ROOT_DIR/.tmp/secrets/cms-build-token" ]]; then
  CMS_TOKEN="$(<"$ROOT_DIR/.tmp/secrets/cms-build-token")"
fi

if [[ -z "$CMS_TOKEN" ]]; then
  read -rsp "CMS build token (leave empty to skip CMS_BUILD_TOKEN): " CMS_TOKEN
  echo
fi

set_secret AWS_ROLE_ARN "$aws_role_arn"
set_secret SITE_BUCKET "$site_bucket"
set_secret SITE_CLOUDFRONT_DISTRIBUTION_ID "$site_distribution_id"
set_secret CMS_BUILD_ENDPOINT "$CMS_ENDPOINT"
set_secret CMS_BUILD_TOKEN "$CMS_TOKEN"
