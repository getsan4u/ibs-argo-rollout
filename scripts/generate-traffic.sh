#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
url="$("$SCRIPT_DIR/get-alb-url.sh")"
interval_seconds="${TRAFFIC_INTERVAL_SECONDS:-1}"

echo "Sending requests to ${url}"
echo "Press Ctrl+C to stop."

while true; do
  timestamp="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  status_code="$(curl --silent --show-error --output /dev/null --write-out '%{http_code}' "$url")"
  echo "${timestamp} HTTP ${status_code}"
  sleep "$interval_seconds"
done
