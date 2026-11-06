#!/bin/sh
set -euo pipefail

TARGET_URL="${1:-http://localhost:8080}"

echo "Checking: $TARGET_URL"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$TARGET_URL")

if [ "$HTTP_CODE" = "200" ]; then
  echo "OK — received HTTP $HTTP_CODE from $TARGET_URL"
  exit 0
else
  echo "FAIL — received HTTP $HTTP_CODE from $TARGET_URL (expected 200)"
  exit 1
fi
