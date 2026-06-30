#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STACK_DIR="$ROOT_DIR/infra/stacks/main"
DIST_DIR="$ROOT_DIR/dist"

if [[ ! -d "$DIST_DIR" ]]; then
  echo "Missing dist/. Run npm run build first." >&2
  exit 1
fi

bucket="${SITE_BUCKET:-}"
distribution_id="${SITE_CLOUDFRONT_DISTRIBUTION_ID:-}"

if [[ -z "$bucket" || -z "$distribution_id" ]]; then
  bucket="$(cd "$STACK_DIR" && tofu output -raw site_bucket)"
  distribution_id="$(cd "$STACK_DIR" && tofu output -raw site_cloudfront_distribution_id)"
fi

aws s3 sync "$DIST_DIR/" "s3://${bucket}/" \
  --delete \
  --exclude "_astro/*" \
  --cache-control "public, max-age=0, must-revalidate"

if [[ -d "$DIST_DIR/_astro" ]]; then
  aws s3 sync "$DIST_DIR/_astro/" "s3://${bucket}/_astro/" \
    --delete \
    --cache-control "public, max-age=31536000, immutable"
fi

aws cloudfront create-invalidation --distribution-id "$distribution_id" --paths "/*" >/dev/null

echo "Deployed dist/ to s3://${bucket}/ and invalidated ${distribution_id}."
