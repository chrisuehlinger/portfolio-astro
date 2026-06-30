#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORK_DIR="$ROOT_DIR/.tmp/old-site"
STACK_DIR="$ROOT_DIR/infra/stacks/main"

bucket="$(cd "$STACK_DIR" && tofu output -raw old_archive_bucket)"

rm -rf "$WORK_DIR"
mkdir -p "$(dirname "$WORK_DIR")"
git clone --depth 1 https://github.com/chrisuehlinger/chrisuehlinger.github.io.git "$WORK_DIR"

aws s3 sync "$WORK_DIR/" "s3://${bucket}/" \
  --delete \
  --exclude ".git/*" \
  --cache-control "public, max-age=600"

distribution_id="$(cd "$STACK_DIR" && tofu output -raw old_cloudfront_distribution_id)"
aws cloudfront create-invalidation --distribution-id "$distribution_id" --paths "/*" >/dev/null

echo "Old site snapshot synced to s3://${bucket}/ and invalidation created."
