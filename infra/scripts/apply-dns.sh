#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STACK_DIR="$ROOT_DIR/infra/stacks/dns"

cd "$STACK_DIR"
tofu init
tofu apply -auto-approve

echo
echo "Route53 nameservers:"
tofu output -json name_servers | jq -r '.[]'
