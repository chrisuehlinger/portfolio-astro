#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STACK_DIR="$ROOT_DIR/infra/stacks/main"

cd "$STACK_DIR"
tofu init
tofu apply -auto-approve -var='enable_custom_domains=false'
