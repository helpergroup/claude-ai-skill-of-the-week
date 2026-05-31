#!/usr/bin/env bash
#
# MLH GHL Build — Bite 2: Custom Fields, Custom Values + Tags
# Client: My Little Helper & Co LLC   |   Platform: GoHighLevel (v2 API)
#
# Creates, idempotently:
#   Task 1 — 12 contact custom fields
#   Task 2 — 12 custom values (11 live, 1 placeholder left blank)
#   Task 3 — 23 tags (all MLH- prefixed)
#
# It checks what already exists first and SKIPS duplicates, so it is safe to
# re-run. Every API response is logged; a summary is printed at the end.
#
# ---------------------------------------------------------------------------
# REQUIREMENTS
#   - bash, curl, jq
#   - Outbound network access to https://services.leadconnectorhq.com
#   - A GHL Private Integration Token (pit-...) with these scopes:
#       locations/customFields.write, locations/customFields.readonly
#       locations/customValues.write, locations/customValues.readonly
#       locations/tags.write,         locations/tags.readonly
#
# USAGE
#   export GHL_LOCATION_ID="nh4p0OCR9P8CYbnf71oH"
#   export GHL_API_TOKEN="pit-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#   ./ghl_bite2_build.sh
#
#   Add DRY_RUN=1 to preview without creating anything:
#   DRY_RUN=1 ./ghl_bite2_build.sh
# ---------------------------------------------------------------------------

set -uo pipefail

BASE="https://services.leadconnectorhq.com"
VERSION="2021-07-28"
DRY_RUN="${DRY_RUN:-0}"

: "${GHL_LOCATION_ID:?Set GHL_LOCATION_ID (your MLH sub-account location id)}"
: "${GHL_API_TOKEN:?Set GHL_API_TOKEN (your pit-... private integration token)}"

command -v jq   >/dev/null || { echo "ERROR: jq is required"; exit 1; }
command -v curl >/dev/null || { echo "ERROR: curl is required"; exit 1; }

LOC="$GHL_LOCATION_ID"
created=0; skipped=0; failed=0

hdr=(-H "Authorization: Bearer $GHL_API_TOKEN"
     -H "Version: $VERSION"
     -H "Accept: application/json"
     -H "Content-Type: application/json")

api() { # method path [json-body]  -> echoes "HTTPCODE<TAB>body"
  local method="$1" path="$2" body="${3:-}"
  if [[ -n "$body" ]]; then
    curl -sS -w $'\n%{http_code}' -X "$method" "${hdr[@]}" -d "$body" "$BASE$path"
  else
    curl -sS -w $'\n%{http_code}' -X "$method" "${hdr[@]}" "$BASE$path"
  fi
}

split_code() { CODE="${1##*$'\n'}"; BODY="${1%$'\n'*}"; }

echo "============================================================"
echo " MLH GHL Bite 2 build  (location: $LOC)"
[[ "$DRY_RUN" == "1" ]] && echo " *** DRY RUN — no writes will be performed ***"
echo "============================================================"

# ----------------------------------------------------------------------------
# TASK 1 — CUSTOM FIELDS (model=contact)
# Format: Name|DATATYPE|opt1;opt2;...   (options only for *_OPTIONS types)
# ----------------------------------------------------------------------------
FIELDS=(
"MLH Transport Type|SINGLE_OPTIONS|NEMT;Private Pay;Pet NEMT;Helper Network"
"MLH Insurance Provider|TEXT|"
"MLH Member ID|TEXT|"
"MLH Trip Frequency|SINGLE_OPTIONS|Daily;Weekly;Monthly;One-Time"
"MLH Service Area|TEXT|"
"MLH Driver Status|SINGLE_OPTIONS|Applicant;In Training;Active;Inactive;Terminated"
"MLH Driver License Expiry|DATE|"
"MLH Background Check Status|SINGLE_OPTIONS|Pending;Cleared;Failed"
"MLH Invoice Amount|NUMERICAL|"
"MLH Payment Status|SINGLE_OPTIONS|Current;Past Due;Pending;Written Off"
"MLH Partner Network Status|SINGLE_OPTIONS|Prospect;Application Sent;Active Partner;Inactive"
"MLH Lead Source|SINGLE_OPTIONS|Google;Referral;Medicaid Broker;Facility;Helper Network;Social Media;Other"
)

echo; echo "TASK 1 — CUSTOM FIELDS"
echo "------------------------------------------------------------"
split_code "$(api GET "/locations/$LOC/customFields?model=contact")"
if [[ "$CODE" != 2* ]]; then
  echo "  ! Could not list existing fields (HTTP $CODE): $BODY"
  EXISTING_FIELDS=""
else
  EXISTING_FIELDS="$(echo "$BODY" | jq -r '.customFields[]?.name // empty')"
fi

for row in "${FIELDS[@]}"; do
  IFS='|' read -r name dtype opts <<<"$row"
  if grep -Fxq "$name" <<<"$EXISTING_FIELDS"; then
    echo "  = skip (exists): $name"; ((skipped++)); continue
  fi
  if [[ -n "$opts" ]]; then
    optsjson="$(jq -cn --arg s "$opts" '$s | split(";")')"
    payload="$(jq -cn --arg n "$name" --arg d "$dtype" --argjson o "$optsjson" \
      '{name:$n, dataType:$d, model:"contact", options:$o}')"
  else
    payload="$(jq -cn --arg n "$name" --arg d "$dtype" \
      '{name:$n, dataType:$d, model:"contact"}')"
  fi
  if [[ "$DRY_RUN" == "1" ]]; then echo "  ~ would create: $name ($dtype)"; continue; fi
  split_code "$(api POST "/locations/$LOC/customFields" "$payload")"
  if [[ "$CODE" == 2* ]]; then echo "  + created: $name ($dtype)"; ((created++))
  else echo "  ! FAILED: $name (HTTP $CODE): $BODY"; ((failed++)); fi
done

# ----------------------------------------------------------------------------
# TASK 2 — CUSTOM VALUES   Format: Name|Value   (blank value = placeholder)
# ----------------------------------------------------------------------------
VALUES=(
"MLH Business Phone Display|704-266-0484"
"MLH GHL Phone|704-686-8692"
"MLH Business Email|info@mylittlehelper.us"
"MLH Website|https://www.mylittlehelper.us"
"MLH Booking Link|https://links.helpersaas.com/widget/booking/SyLKN4RCDJRZP1oMpeOU"
"MLH Service Area|Charlotte, NC and surrounding Mecklenburg County"
"MLH Hours of Operation|Monday through Friday 7am to 6pm Eastern"
"MLH Request a Ride Form|https://forms.mylittlehelper.us/ride"
"MLH New Hire Upload Form|https://forms.mylittlehelper.us/newhire"
"MLH Employee Info Form|https://forms.mylittlehelper.us/employee"
"MLH Partner Application Form|https://forms.mylittlehelper.us/partner"
"MLH Private Pay Payment Link|"
)

echo; echo "TASK 2 — CUSTOM VALUES"
echo "------------------------------------------------------------"
split_code "$(api GET "/locations/$LOC/customValues")"
if [[ "$CODE" != 2* ]]; then
  echo "  ! Could not list existing values (HTTP $CODE): $BODY"
  EXISTING_VALUES=""
else
  EXISTING_VALUES="$(echo "$BODY" | jq -r '.customValues[]?.name // empty')"
fi

for row in "${VALUES[@]}"; do
  IFS='|' read -r name val <<<"$row"
  if grep -Fxq "$name" <<<"$EXISTING_VALUES"; then
    echo "  = skip (exists): $name"; ((skipped++)); continue
  fi
  [[ -z "$val" ]] && echo "  * PLACEHOLDER (blank, flag to Melessa): $name"
  payload="$(jq -cn --arg n "$name" --arg v "$val" '{name:$n, value:$v}')"
  if [[ "$DRY_RUN" == "1" ]]; then echo "  ~ would create: $name"; continue; fi
  split_code "$(api POST "/locations/$LOC/customValues" "$payload")"
  if [[ "$CODE" == 2* ]]; then echo "  + created: $name"; ((created++))
  else echo "  ! FAILED: $name (HTTP $CODE): $BODY"; ((failed++)); fi
done

# ----------------------------------------------------------------------------
# TASK 3 — TAGS  (all MLH- prefixed).  GHL stores tag names lowercased.
# ----------------------------------------------------------------------------
TAGS=(
"MLH-New Inquiry" "MLH-Client Active" "MLH-Client NEMT" "MLH-Client Private Pay"
"MLH-Client Pet NEMT" "MLH-Trip Reminder Sent" "MLH-Trip Confirmed" "MLH-No Show"
"MLH-Missed Trip Follow-Up" "MLH-Nurture Complete"
"MLH-Driver Applicant" "MLH-Driver In Training" "MLH-Driver Active"
"MLH-Driver License Expiring" "MLH-Background Check Pending" "MLH-Background Check Cleared"
"MLH-Invoice Sent" "MLH-Payment Past Due" "MLH-Payment Received" "MLH-AR Follow-Up"
"MLH-Network Prospect" "MLH-Network Active Partner" "MLH-Network Application Sent"
)

echo; echo "TASK 3 — TAGS (${#TAGS[@]} total)"
echo "------------------------------------------------------------"
split_code "$(api GET "/locations/$LOC/tags")"
if [[ "$CODE" != 2* ]]; then
  echo "  ! Could not list existing tags (HTTP $CODE): $BODY"
  EXISTING_TAGS=""
else
  EXISTING_TAGS="$(echo "$BODY" | jq -r '.tags[]?.name // empty' | tr '[:upper:]' '[:lower:]')"
fi

for name in "${TAGS[@]}"; do
  lc="$(tr '[:upper:]' '[:lower:]' <<<"$name")"
  if grep -Fxq "$lc" <<<"$EXISTING_TAGS"; then
    echo "  = skip (exists): $name"; ((skipped++)); continue
  fi
  payload="$(jq -cn --arg n "$name" '{name:$n}')"
  if [[ "$DRY_RUN" == "1" ]]; then echo "  ~ would create: $name"; continue; fi
  split_code "$(api POST "/locations/$LOC/tags" "$payload")"
  if [[ "$CODE" == 2* ]]; then echo "  + created: $name"; ((created++))
  else echo "  ! FAILED: $name (HTTP $CODE): $BODY"; ((failed++)); fi
done

echo; echo "============================================================"
echo " SUMMARY:  created=$created  skipped=$skipped  failed=$failed"
echo "------------------------------------------------------------"
echo " FLAG TO MELESSA: 'MLH Private Pay Payment Link' is intentionally"
echo " blank — needs the Stripe or GHL payment link to be populated."
echo "============================================================"
[[ "$failed" -gt 0 ]] && exit 1 || exit 0
