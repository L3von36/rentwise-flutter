#!/usr/bin/env bash
# Provisions the RentWise Appwrite Cloud project:
#   database + collections + attributes + indexes + permissions + platforms
#   + owners team + collection-permission hardening.
#
# Required env:
#   AW_KEY   — API key with databases/users/teams scopes
# Optional env:
#   AW_ENDPOINT (default https://cloud.appwrite.io/v1)
#   AW_PROJECT  (default rentwise)
#
# SECURITY MODEL (v1.15):
#   • Profiles: users may READ and CREATE their own profile (bootstrap:
#     the first account on a fresh cloud becomes owner), but can NEVER
#     update or delete — a role is fixed at creation and can only be
#     changed with the API key (or the Appwrite console).
#   • `metrics` is readable only by the `owners` team — employees cannot
#     pull financial metrics through the API even with a session. The
#     script syncs every owner profile into the owners team, including
#     in-app bootstrapped owners.
#   • `user_prefs` holds each user's active-workspace pointer with
#     document-level security — the only profile-adjacent doc a client
#     may write after sign-up.
#   • Operational collections (workspaces, inventory, customers, orders,
#     activities, pickups) stay member-writable so bootstrap sign-up can
#     create the starter workspace and the shift can run; owner-only
#     actions are enforced in the app and activity-logged.
#
# Idempotent: 409 "already exists" responses are treated as success.
# Re-run after upgrading to apply attribute additions and permission
# hardening to an existing project.
set -euo pipefail

ENDPOINT="${AW_ENDPOINT:-https://cloud.appwrite.io/v1}"
PROJECT="${AW_PROJECT:-rentwise}"
KEY="${AW_KEY:?set AW_KEY}"

api() { # method path body -> body on stdout, code on stderr
  local method="$1" path="$2" body="${3:-}"
  local out code
  if [ -n "$body" ]; then
    out=$(curl -s -w '\n%{http_code}' -X "$method" "$ENDPOINT$path" \
      -H "X-Appwrite-Project: $PROJECT" -H "X-Appwrite-Key: $KEY" \
      -H 'Content-Type: application/json' -d "$body")
  else
    out=$(curl -s -w '\n%{http_code}' -X "$method" "$ENDPOINT$path" \
      -H "X-Appwrite-Project: $PROJECT" -H "X-Appwrite-Key: $KEY")
  fi
  code=$(echo "$out" | tail -1)
  echo "$out" | sed '$d'
  if [ "$code" = 409 ]; then
    echo "  ~= exists: $path" >&2
  elif [ "${code:0:1}" != 2 ]; then
    echo "!! $method $path -> $code" >&2
    return 1
  else
    echo "  ok: $method $path ($code)" >&2
  fi
}

jqget() { python3 -c "import sys,json;d=json.load(sys.stdin);print(d$1)" 2>/dev/null || echo ''; }

echo '== database =='
api POST /databases '{"databaseId":"rentwise-db","name":"RentWise"}' >/dev/null || true

# mkcoll id name perms docsec
mkcoll() {
  api POST /databases/rentwise-db/collections \
    "{\"collectionId\":\"$1\",\"name\":\"$2\",\"permissions\":$3,\"documentSecurity\":$4}" >/dev/null || true
}
mkattr() { # coll body type
  local key
  key=$(echo "$2" | python3 -c 'import sys,json;print(json.load(sys.stdin)["key"])')
  if curl -s "$ENDPOINT/databases/rentwise-db/collections/$1/attributes" \
      -H "X-Appwrite-Project: $PROJECT" -H "X-Appwrite-Key: $KEY" \
      | python3 -c "import sys,json;ks=[a['key'] for a in json.load(sys.stdin)['attributes']];print('yes' if '$key' in ks else 'no')" \
      | grep -q yes; then
    echo "  ~= exists: $1.$key" >&2
    return 0
  fi
  api POST "/databases/rentwise-db/collections/$1/attributes/$3" "$2" >/dev/null || true
}

# Permission constants (JSON arrays).
PERM_USERS_CRUD='["read(\"users\")","create(\"users\")","update(\"users\")","delete(\"users\")"]'
PERM_USERS_READ_CREATE='["read(\"users\")","create(\"users\")"]'  # profiles: role fixed at creation
PERM_PREFS_CREATE='["create(\"users\")"]'                        # reads gated per-document
PERM_OWNERS_READ='["read(\"team:owners\")"]'

echo '== collections + attributes =='
# ---- profiles (read + create-only for clients; roles immutable)
mkcoll profiles 'Profiles' "$PERM_USERS_READ_CREATE" false
mkattr profiles '{"key":"userId","type":"string","size":64,"required":true}' string
mkattr profiles '{"key":"name","type":"string","size":128,"required":true}' string
mkattr profiles '{"key":"email","type":"string","size":256,"required":true}' string
mkattr profiles '{"key":"role","type":"enum","elements":["owner","employee"],"required":true}' enum
mkattr profiles '{"key":"title","type":"string","size":64,"required":false,"default":""}' string
mkattr profiles '{"key":"activeWorkspace","type":"string","size":128,"required":false,"default":""}' string

# ---- user_prefs (per-user document security; client writes own doc only)
mkcoll user_prefs 'User prefs' "$PERM_PREFS_CREATE" true
mkattr user_prefs '{"key":"activeWorkspace","type":"string","size":128,"required":false,"default":""}' string

# ---- inventory_items
mkcoll inventory_items 'Inventory items' "$PERM_USERS_CRUD" false
mkattr inventory_items '{"key":"name","type":"string","size":128,"required":true}' string
mkattr inventory_items '{"key":"note","type":"string","size":256,"required":false,"default":""}' string
mkattr inventory_items '{"key":"category","type":"string","size":64,"required":true}' string
mkattr inventory_items '{"key":"totalStock","type":"integer","required":true,"min":0,"max":100000}' integer
mkattr inventory_items '{"key":"available","type":"integer","required":true,"min":0,"max":100000}' integer
mkattr inventory_items '{"key":"ratePerDay","type":"float","required":true,"min":0,"max":1000000}' float
mkattr inventory_items '{"key":"iconKey","type":"string","size":64,"required":false,"default":"inventory_2"}' string
mkattr inventory_items '{"key":"sortIndex","type":"integer","required":false,"default":0,"min":0,"max":100000}' integer
mkattr inventory_items '{"key":"maintenance","type":"boolean","required":false,"default":false}' boolean

# ---- customers
mkcoll customers 'Customers' "$PERM_USERS_CRUD" false
mkattr customers '{"key":"name","type":"string","size":128,"required":true}' string
mkattr customers '{"key":"company","type":"string","size":128,"required":false,"default":""}' string
mkattr customers '{"key":"email","type":"string","size":256,"required":false,"default":""}' string
mkattr customers '{"key":"phone","type":"string","size":64,"required":false,"default":""}' string
mkattr customers '{"key":"rentals","type":"integer","required":true,"min":0,"max":1000000}' integer
mkattr customers '{"key":"lifetimeSpend","type":"float","required":true,"min":0,"max":100000000}' float
mkattr customers '{"key":"lastBooking","type":"datetime","required":true}' datetime
mkattr customers '{"key":"avatarColorIndex","type":"integer","required":false,"default":0,"min":0,"max":99}' integer

# ---- orders
mkcoll orders 'Rental orders' "$PERM_USERS_CRUD" false
mkattr orders '{"key":"eventName","type":"string","size":256,"required":true}' string
mkattr orders '{"key":"customerName","type":"string","size":128,"required":true}' string
mkattr orders '{"key":"contactName","type":"string","size":128,"required":false,"default":""}' string
mkattr orders '{"key":"createdAt","type":"datetime","required":true}' datetime
mkattr orders '{"key":"eventDate","type":"datetime","required":true}' datetime
mkattr orders '{"key":"itemCount","type":"integer","required":true,"min":0,"max":100000}' integer
mkattr orders '{"key":"total","type":"float","required":true,"min":0,"max":100000000}' float
mkattr orders '{"key":"status","type":"enum","elements":["preparing","confirmed","needsPayment","outForDelivery","returned"],"required":true}' enum
mkattr orders '{"key":"notes","type":"string","size":4000,"required":false,"default":""}' string
mkattr orders '{"key":"linesJson","type":"string","size":8000,"required":false,"default":"[]"}' string

# ---- activities
mkcoll activities 'Activity log' "$PERM_USERS_CRUD" false
mkattr activities '{"key":"actor","type":"string","size":128,"required":true}' string
mkattr activities '{"key":"actorInitials","type":"string","size":8,"required":false,"default":""}' string
mkattr activities '{"key":"actorColorIndex","type":"integer","required":false,"default":0,"min":0,"max":99}' integer
mkattr activities '{"key":"at","type":"datetime","required":true}' datetime
mkattr activities '{"key":"type","type":"enum","elements":["rental","payment","orderUpdate","returnItem","note","newBooking"],"required":true}' enum
mkattr activities '{"key":"body","type":"string","size":2000,"required":true}' string

# ---- pickups
mkcoll pickups 'Pickups' "$PERM_USERS_CRUD" false
mkattr pickups '{"key":"date","type":"datetime","required":true}' datetime
mkattr pickups '{"key":"title","type":"string","size":256,"required":true}' string
mkattr pickups '{"key":"venue","type":"string","size":256,"required":false,"default":""}' string
mkattr pickups '{"key":"itemCount","type":"integer","required":true,"min":0,"max":100000}' integer
mkattr pickups '{"key":"contactName","type":"string","size":128,"required":false,"default":""}' string

# ---- workspaces
mkcoll workspaces 'Workspaces' "$PERM_USERS_CRUD" false
mkattr workspaces '{"key":"name","type":"string","size":128,"required":true}' string
mkattr workspaces '{"key":"createdAt","type":"datetime","required":true}' datetime
mkattr workspaces '{"key":"createdBy","type":"string","size":128,"required":false,"default":""}' string

# ---- metrics (owners-team read ONLY — financial data)
mkcoll metrics 'Metrics' "$PERM_OWNERS_READ" false
mkattr metrics '{"key":"grossMonth","type":"float","required":false,"default":0,"min":0,"max":100000000}' float
mkattr metrics '{"key":"utilization","type":"float","required":false,"default":0,"min":0,"max":100}' float
mkattr metrics '{"key":"earningsJson","type":"string","size":8000,"required":false,"default":"[]"}' string
mkattr metrics '{"key":"categoryJson","type":"string","size":4000,"required":false,"default":"[]"}' string

echo '== wait for attributes to become available =='
for c in profiles user_prefs inventory_items customers orders activities pickups workspaces metrics; do
  for i in $(seq 1 40); do
    n=$(api GET "/databases/rentwise-db/collections/$c/attributes" | python3 -c 'import sys,json;print(json.load(sys.stdin)["total"])' 2>/dev/null || echo 0)
    avail=$(api GET "/databases/rentwise-db/collections/$c" | python3 -c 'import sys,json;print(len(json.load(sys.stdin).get("attributes",[])))' 2>/dev/null || echo -1)
    [ "$n" = "$avail" ] && break
    sleep 2
  done
  echo "  $c: $n attributes ready"
done

echo '== harden permissions on EXISTING collections (re-run safe) =='
setperm() { # coll perms docsec
  api PUT "/databases/rentwise-db/collections/$1" \
    "{\"permissions\":$2,\"documentSecurity\":$3}" >/dev/null \
    && echo "  locked: $1" >&2
}
setperm profiles        "$PERM_USERS_READ_CREATE" false
setperm user_prefs      "$PERM_PREFS_CREATE" true
setperm metrics         "$PERM_OWNERS_READ" false
setperm inventory_items "$PERM_USERS_CRUD" false
setperm customers       "$PERM_USERS_CRUD" false
setperm orders          "$PERM_USERS_CRUD" false
setperm activities      "$PERM_USERS_CRUD" false
setperm pickups         "$PERM_USERS_CRUD" false
setperm workspaces      "$PERM_USERS_CRUD" false

echo '== indexes =='
mkidx() { api POST "/databases/rentwise-db/collections/$1/indexes" "{\"key\":\"$2\",\"type\":\"$3\",\"attributes\":$4}" >/dev/null; }
mkidx profiles idx_userId unique '["userId"]'
mkidx inventory_items idx_category key '["category"]'
mkidx customers idx_name key '["name"]'
mkidx orders idx_status key '["status"]'
mkidx orders idx_customer key '["customerName"]'
mkidx activities idx_at key '["at"]'

echo '== platforms =='
mkplat() { api POST /projects/$PROJECT/platforms "$1" >/dev/null; }
mkplat '{"type":"web","name":"RentWise Web","hostname":"localhost"}'
mkplat '{"type":"android","name":"RentWise Android","package":"com.rentwise.rentwise","key":""}'
mkplat '{"type":"ios","name":"RentWise iOS","bundle":"com.rentwise.rentwise"}'
mkplat '{"type":"macos","name":"RentWise macOS","bundle":"com.rentwise.rentwise"}'
mkplat '{"type":"windows","name":"RentWise Windows","package":"com.rentwise.rentwise"}'
mkplat '{"type":"linux","name":"RentWise Linux","package":"com.rentwise.rentwise"}'

echo '== owners team + membership sync =='
api POST /teams '{"teamId":"owners","name":"Owners"}' >/dev/null || true
# Sync EVERY owner profile into the owners team — covers owners created
# in-app via sign-up bootstrap as well as script/console-provisioned ones.
OWNERS=$(api GET "/databases/rentwise-db/collections/profiles/documents?queries%5B%5D=equal%28%22role%22%2C%22owner%22%29&limit=100" | python3 -c 'import sys,json;print(" ".join(d["userId"] for d in json.load(sys.stdin).get("documents",[])))' 2>/dev/null || echo '')
for uid in $OWNERS; do
  api POST /teams/owners/memberships \
    "{\"userId\":\"$uid\",\"roles\":[\"owner\"],\"confirm\":true}" >/dev/null \
    && echo "  owner $uid joined owners team" >&2 \
    || echo "  WARN: could not auto-add $uid — Auth → Teams → Owners → Members in the console (metrics stay hidden until then)." >&2
done
[ -z "$OWNERS" ] && echo '  (no owner profiles yet — the first sign-up becomes the owner; re-run to team them)' >&2

echo 'ALL DONE'
echo 'Next steps:'
echo '  • Seed a demo dataset (optional): AW_KEY=<key> AW_SEED=1 flutter test test/seed_appwrite_test.dart'
echo '  • Promote/demote a profile role: Appwrite console → Databases → profiles, or the API key (role is fixed at creation for clients).'
