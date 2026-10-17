#!/usr/bin/env bash
# Poll GitHub Actions until the release run for the latest v* tag finishes.
# Token comes from the GT environment variable — never hardcode it.
set -u
TOKEN="${GT:?set GT}"
REPO="L3von36/rentwise-flutter"
MAX_WAIT="${MAX_WAIT:-560}"
INTERVAL=45

api() { curl -s -H "Authorization: Bearer $TOKEN" "https://api.github.com$1"; }

# latest v* tag
TAG=$(git -C "$(dirname "$0")/.." tag --list 'v*' --sort=-v:refname | head -1)
echo "Waiting for release run of tag: $TAG"

START=$(date +%s)
while true; do
  NOW=$(date +%s); ELAPSED=$((NOW - START))
  if [ "$ELAPSED" -gt "$MAX_WAIT" ]; then echo "TIMEOUT after ${MAX_WAIT}s"; break; fi

  RUN_JSON=$(api "/repos/$REPO/actions/runs?per_page=6")
  RUN=$(echo "$RUN_JSON" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for r in d.get('workflow_runs',[]):
    if r.get('head_branch','').startswith('v') and r.get('name','').lower().find('release')!=-1:
        print(r['id'], r['status'], r['conclusion'], r['head_branch']); break
")
  RID=$(echo "$RUN" | cut -d' ' -f1)
  STATUS=$(echo "$RUN" | cut -d' ' -f2)
  CONCL=$(echo "$RUN" | cut -d' ' -f3)
  echo "[${ELAPSED}s] run $RID status=$STATUS conclusion=$CONCL"

  if [ "$STATUS" = "completed" ]; then
    echo "---- jobs ----"
    api "/repos/$REPO/actions/runs/$RID/jobs?per_page=10" | python3 -c "
import json,sys
d=json.load(sys.stdin)
for j in d.get('jobs',[]):
    print(f\"{j['name']:<28} {j['status']:<12} {j['conclusion']}\")"
    if [ "$CONCL" = "success" ]; then
      echo "RELEASE OK"
      api "/repos/$REPO/releases/tags/$TAG" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print('Release:', d.get('name'), '| assets:', len(d.get('assets',[])))
for a in d.get('assets',[]):
    print(f\"  {a['name']:<28} {a['size']/1048576:.1f} MB\")"
    fi
    break
  fi
  sleep "$INTERVAL"
done
