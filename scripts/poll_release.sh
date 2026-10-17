#!/usr/bin/env bash
# Polls the latest v* release on L3von36/rentwise-flutter until it is
# published and all 4 platform assets are attached. Token via GT env.
set -euo pipefail
REPO="L3von36/rentwise-flutter"
TOKEN="${GT:?set GT}"
API="https://api.github.com/repos/${REPO}/releases"
TAG="$(git -C "$(dirname "$0")/.." describe --tags --match 'v*' --abbrev=0 2>/dev/null || true)"
TAG="${TAG:-$(git -C "$(dirname "$0")/.." tag --sort=-creatordate | head -1)}"
echo "waiting for release ${TAG}..."
for i in $(seq 1 60); do
  JSON="$(curl -sf -H "Authorization: Bearer ${TOKEN}" "${API}/tags/${TAG}" || true)"
  DRAFT="$(echo "$JSON" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("draft"))' 2>/dev/null || echo 'None')"
  if [ "$DRAFT" = "False" ]; then
    URL="$(echo "$JSON" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["html_url"])')"
    echo "$JSON" | python3 -c 'import sys,json;d=json.load(sys.stdin);[print("asset:",a["name"],a["size"]) for a in d["assets"]]'
    echo "PUBLISHED: ${URL}"
    exit 0
  fi
  echo "  attempt ${i}/60: not published yet"; sleep 15
done
echo "TIMEOUT waiting for ${TAG}"; exit 1
