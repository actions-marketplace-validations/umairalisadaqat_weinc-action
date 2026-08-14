#!/usr/bin/env bash
# WeInc Website Builder action - thin wrapper over the WeInc Agency API.
# Only calls endpoints documented at https://my.we.inc/api/v1/docs
set -euo pipefail

API="${WEINC_API_URL:-https://my.we.inc/api/v1}"
KEY="${WEINC_API_KEY:-}"
CMD="${WEINC_COMMAND:-}"

fail() { echo "::error::$1" >&2; exit 1; }

[ -n "$KEY" ] || fail "api_key is required (a wk_ key from your WeInc agency dashboard)"
[ -n "$CMD" ] || fail "command is required"

need() {
  local var="$1" label="$2"
  [ -n "${!var:-}" ] || fail "'$CMD' requires the '$label' input"
}

json_body() { # build JSON from key=value pairs, skipping empty values
  python3 - "$@" <<'PY'
import json, sys
out = {}
for arg in sys.argv[1:]:
    k, _, v = arg.partition("=")
    if v:
        out[k] = v
print(json.dumps(out))
PY
}

METHOD="GET"
PATH_PART=""
QUERY=""
BODY=""

case "$CMD" in
  list-projects)
    PATH_PART="/projects"
    [ -n "${WEINC_CLIENT_ID:-}" ] && QUERY="client_id=${WEINC_CLIENT_ID}"
    ;;
  get-project)
    need WEINC_PROJECT_ID project_id
    PATH_PART="/projects/${WEINC_PROJECT_ID}"
    ;;
  create-project)
    need WEINC_CLIENT_EMAIL client_email
    need WEINC_NAME name
    METHOD="POST"; PATH_PART="/projects"
    BODY=$(json_body "client_email=${WEINC_CLIENT_EMAIL}" "name=${WEINC_NAME}" \
                     "description=${WEINC_DESCRIPTION:-}" "template_id=${WEINC_TEMPLATE_ID:-}")
    ;;
  update-project)
    need WEINC_PROJECT_ID project_id
    METHOD="PATCH"; PATH_PART="/projects/${WEINC_PROJECT_ID}"
    BODY=$(json_body "name=${WEINC_NAME:-}" "description=${WEINC_DESCRIPTION:-}")
    ;;
  delete-project)
    need WEINC_PROJECT_ID project_id
    METHOD="DELETE"; PATH_PART="/projects/${WEINC_PROJECT_ID}"
    ;;
  list-clients)
    PATH_PART="/clients"
    ;;
  get-client)
    need WEINC_CLIENT_ID client_id
    PATH_PART="/clients/${WEINC_CLIENT_ID}"
    ;;
  create-client)
    need WEINC_CLIENT_EMAIL client_email
    METHOD="POST"; PATH_PART="/clients"
    BODY=$(json_body "email=${WEINC_CLIENT_EMAIL}" "name=${WEINC_NAME:-}")
    ;;
  list-templates)
    PATH_PART="/templates"
    ;;
  list-plans)
    PATH_PART="/plans"
    ;;
  get-analytics)
    PATH_PART="/analytics"
    QS=()
    [ -n "${WEINC_DAYS:-}" ] && QS+=("days=${WEINC_DAYS}")
    [ -n "${WEINC_PROJECT_ID:-}" ] && QS+=("project_id=${WEINC_PROJECT_ID}")
    QUERY=$(IFS='&'; echo "${QS[*]:-}")
    ;;
  list-webhooks)
    PATH_PART="/webhooks"
    ;;
  *)
    fail "Unknown command '$CMD'. See action.yml for supported commands."
    ;;
esac

URL="${API}${PATH_PART}"
[ -n "$QUERY" ] && URL="${URL}?${QUERY}"

CURL_ARGS=(-sS -X "$METHOD" "$URL"
  -H "Authorization: Bearer ${KEY}"
  -H "Accept: application/json"
  -H "User-Agent: weinc-action/1.0.0"
  -w $'\n%{http_code}')
if [ -n "$BODY" ]; then
  CURL_ARGS+=(-H "Content-Type: application/json" -d "$BODY")
fi

RAW=$(curl "${CURL_ARGS[@]}") || fail "Could not reach the WeInc API"
STATUS=$(printf '%s' "$RAW" | tail -n1)
RESPONSE=$(printf '%s' "$RAW" | sed '$d')

echo "HTTP ${STATUS}"
echo "$RESPONSE"

case "$STATUS" in
  2*) ;;
  401|403) fail "The WeInc API rejected the key (HTTP ${STATUS}). Check the api_key secret." ;;
  429) fail "Rate limited by the WeInc API (100 req/min per key)." ;;
  *)  fail "WeInc API returned HTTP ${STATUS}: ${RESPONSE}" ;;
esac

# Outputs
{
  echo "json<<WEINC_EOF"
  echo "$RESPONSE"
  echo "WEINC_EOF"
} >> "$GITHUB_OUTPUT"

ID=$(printf '%s' "$RESPONSE" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit()
for k in ('project', 'client', 'template', 'plan', 'webhook'):
    if isinstance(d.get(k), dict) and d[k].get('id'):
        print(d[k]['id']); break
else:
    if isinstance(d, dict) and d.get('id'):
        print(d['id'])
" || true)
[ -n "$ID" ] && echo "id=${ID}" >> "$GITHUB_OUTPUT" || true
