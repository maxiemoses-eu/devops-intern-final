#!/bin/sh
set -eu

TARGET_URL="${1:-http://localhost:8080}"

if ! command -v curl >/dev/null 2>&1; then
  echo "FAIL — curl command not found" >&2
  exit 1
fi

echo "Checking: $TARGET_URL"

CURL_EXIT=0
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 3 --max-time 5 "$TARGET_URL") || CURL_EXIT=$?

if [ "$CURL_EXIT" -ne 0 ]; then
  echo "FAIL — curl failed to connect to $TARGET_URL (exit code: $CURL_EXIT)" >&2
  exit 1
fi

if [ "$HTTP_CODE" = "200" ]; then
  echo "OK — received HTTP $HTTP_CODE from $TARGET_URL"
  exit 0
else
  echo "FAIL — received HTTP $HTTP_CODE from $TARGET_URL (expected 200)" >&2
  exit 1
fi
