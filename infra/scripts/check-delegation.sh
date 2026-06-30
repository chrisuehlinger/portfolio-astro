#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DNS_STACK="$ROOT_DIR/infra/stacks/dns"
DOMAIN="${1:-chrisuehlinger.com}"

cd "$DNS_STACK"
expected="$(tofu output -json name_servers | jq -r '.[]' | sed 's/\.$//' | sort)"

actual="$(curl -sS --max-time 15 -H 'accept: application/dns-json' "https://cloudflare-dns.com/dns-query?name=${DOMAIN}&type=NS" \
  | jq -r '.Answer[]?.data' \
  | sed 's/\.$//' \
  | sort)"

echo "Expected Route53 nameservers:"
echo "$expected"
echo
echo "Current public nameservers:"
echo "${actual:-<none>}"
echo

if [[ "$actual" == "$expected" ]]; then
  echo "Delegation is pointing at Route53."
else
  echo "Delegation is not pointing at Route53 yet."
  exit 1
fi
