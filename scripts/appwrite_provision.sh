#!/usr/bin/env bash
# Provisions the RentWise Appwrite Cloud project:
#   database + collections + attributes + indexes + permissions + platforms
# Requires: AW_KEY (API key with databases/users scopes), already-created
# project "rentwise" (region fra) on https://cloud.appwrite.io/v1.
#
# Idempotent: 409 "already exists" responses are treated as success.
set -euo pipefail

ENDPOINT="${AW_ENDPOINT:-https://cloud.appwrite.io/v1}"
PROJECT="${AW_PROJECT:-rentwise}"
KEY="${AW_KEY:?set AW_KEY}"
KEY_ID="${AW_KEY_ID:-rentwise-prov-key}"

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

# mkcoll id name perms
mkcoll() {
  api POST /databases/rentwise-db/collections \
    "{\"collectionId\":\"$1\",\"name\":\"$2\",\"permissions\":[\"read(\\\"users\\\")\",\"create(\\\"users\\\")\",\"update(\\\"users\\\")\",\"delete(\\\"users\\\")\"],\"documentSecurity\":false}" >/dev/null || true
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

echo '== collections + attributes =='
# ---- profiles
mkcoll profiles 'Profiles'
mkattr profiles '{"key":"userId","type":"string","size":64,"required":true}' string
mkattr profiles '{"key":"name","type":"string","size":128,"required":true}' string
mkattr profiles '{"key":"email","type":"string","size":256,"required":true}' string
mkattr profiles '{"key":"role","type":"enum","elements":["owner","employee"],"required":true}' enum
mkattr profiles '{"key":"title","type":"string","size":64,"required":false,"default":""}' string
mkattr profiles '{"key":"activeWorkspace","type":"string","size":128,"required":false,"default":"Riverside Events"}' string

# ---- inventory_items
mkcoll inventory_items 'Inventory items'
mkattr inventory_items '{"key":"name","type":"string","size":128,"required":true}' string
mkattr inventory_items '{"key":"note","type":"string","size":256,"required":false,"default":""}' string
mkattr inventory_items '{"key":"category","type":"string","size":64,"required":true}' string
mkattr inventory_items '{"key":"totalStock","type":"integer","required":true,"min":0,"max":100000}' integer
mkattr inventory_items '{"key":"available","type":"integer","required":true,"min":0,"max":100000}' integer
mkattr inventory_items '{"key":"ratePerDay","type":"float","required":true,"min":0,"max":1000000}' float
mkattr inventory_items '{"key":"iconKey","type":"string","size":64,"required":false,"default":"inventory_2"}' string
mkattr inventory_items '{"key":"sortIndex","type":"integer","required":false,"default":0,"min":0,"max":100000}' integer

# ---- customers
mkcoll customers 'Customers'
mkattr customers '{"key":"name","type":"string","size":128,"required":true}' string
mkattr customers '{"key":"company","type":"string","size":128,"required":false,"default":""}' string
mkattr customers '{"key":"email","type":"string","size":256,"required":false,"default":""}' string
mkattr customers '{"key":"phone","type":"string","size":64,"required":false,"default":""}' string
mkattr customers '{"key":"rentals","type":"integer","required":true,"min":0,"max":1000000}' integer
mkattr customers '{"key":"lifetimeSpend","type":"float","required":true,"min":0,"max":100000000}' float
mkattr customers '{"key":"lastBooking","type":"datetime","required":true}' datetime
mkattr customers '{"key":"avatarColorIndex","type":"integer","required":false,"default":0,"min":0,"max":99}' integer

# ---- orders
mkcoll orders 'Rental orders'
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
mkcoll activities 'Activity log'
mkattr activities '{"key":"actor","type":"string","size":128,"required":true}' string
mkattr activities '{"key":"actorInitials","type":"string","size":8,"required":false,"default":""}' string
mkattr activities '{"key":"actorColorIndex","type":"integer","required":false,"default":0,"min":0,"max":99}' integer
mkattr activities '{"key":"at","type":"datetime","required":true}' datetime
mkattr activities '{"key":"type","type":"enum","elements":["rental","payment","orderUpdate","returnItem","note","newBooking"],"required":true}' enum
mkattr activities '{"key":"body","type":"string","size":2000,"required":true}' string

# ---- pickups
mkcoll pickups 'Pickups'
mkattr pickups '{"key":"date","type":"datetime","required":true}' datetime
mkattr pickups '{"key":"title","type":"string","size":256,"required":true}' string
mkattr pickups '{"key":"venue","type":"string","size":256,"required":false,"default":""}' string
mkattr pickups '{"key":"itemCount","type":"integer","required":true,"min":0,"max":100000}' integer
mkattr pickups '{"key":"contactName","type":"string","size":128,"required":false,"default":""}' string

# ---- workspaces
mkcoll workspaces 'Workspaces'
mkattr workspaces '{"key":"name","type":"string","size":128,"required":true}' string
mkattr workspaces '{"key":"createdAt","type":"datetime","required":true}' datetime
mkattr workspaces '{"key":"createdBy","type":"string","size":128,"required":false,"default":""}' string

# ---- metrics
mkcoll metrics 'Metrics'
mkattr metrics '{"key":"grossMonth","type":"float","required":false,"default":0,"min":0,"max":100000000}' float
mkattr metrics '{"key":"utilization","type":"float","required":false,"default":0,"min":0,"max":100}' float
mkattr metrics '{"key":"earningsJson","type":"string","size":8000,"required":false,"default":"[]"}' string
mkattr metrics '{"key":"categoryJson","type":"string","size":4000,"required":false,"default":"[]"}' string

echo '== wait for attributes to become available =='
for c in profiles inventory_items customers orders activities pickups workspaces metrics; do
  for i in $(seq 1 40); do
    n=$(api GET "/databases/rentwise-db/collections/$c/attributes" | python3 -c 'import sys,json;print(json.load(sys.stdin)["total"])' 2>/dev/null || echo 0)
    avail=$(api GET "/databases/rentwise-db/collections/$c" | python3 -c 'import sys,json;print(len(json.load(sys.stdin).get("attributes",[])))' 2>/dev/null || echo -1)
    [ "$n" = "$avail" ] && break
    sleep 2
  done
  echo "  $c: $n attributes ready"
done

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

echo '== users (owner + employee) =='
mkuser() { api POST /users "$1" >/dev/null; }
mkuser '{"userId":"owner-tinsae","email":"selamvenda8@gmail.com","password":"selam@336","name":"Tinsae Abeba"}'
mkuser '{"userId":"employee-jordan","email":"jordan@riverside.events","password":"jordan@336","name":"Jordan Miller"}'

echo 'ALL DONE'
