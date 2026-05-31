# MLH GHL Build — Bite 2 (Custom Fields, Custom Values + Tags)

Idempotent script that builds the Bite 2 data foundation in the **My Little Helper**
GoHighLevel sub-account via the **v2 API** (`services.leadconnectorhq.com`).

## Why this is a script and not "already done"

This was prepared by Claude Code inside a cloud container whose **network policy
does not allowlist GoHighLevel**. Every GHL host (`services.leadconnectorhq.com`,
`rest.gohighlevel.com`, `api.gohighlevel.com`) returns `403 Host not in allowlist`,
so the API could not be reached from that session — regardless of credentials.

Run this from anywhere with normal internet access (your laptop), **or** re-launch
the Claude Code environment with a network policy that allows
`services.leadconnectorhq.com`, then run it there.

> Note: the original Bite 2 brief referenced the **v1** endpoint
> (`rest.gohighlevel.com/v1/`), but the supplied `pit-…` token is a **v2 Private
> Integration Token**, so this script targets the v2 API.

## What it creates

| Task | Count | Notes |
|------|-------|-------|
| 1. Custom fields (contact) | 12 | dropdowns → `SINGLE_OPTIONS`, date → `DATE`, number → `NUMERICAL`, text → `TEXT` |
| 2. Custom values | 12 | 11 live; `MLH Private Pay Payment Link` left **blank** (placeholder) |
| 3. Tags | 23 | all `MLH-` prefixed |

The script **lists existing items first and skips duplicates**, so re-running is safe.

## Requirements

- `bash`, `curl`, `jq`
- A GHL Private Integration Token (`pit-…`) with read+write scopes for
  `customFields`, `customValues`, and `tags`.

## Run

```bash
export GHL_LOCATION_ID="nh4p0OCR9P8CYbnf71oH"
export GHL_API_TOKEN="pit-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# preview without writing:
DRY_RUN=1 ./ghl_bite2_build.sh

# execute:
./ghl_bite2_build.sh
```

The token is **never** hardcoded or committed — it is read from the environment.

## After running — flag to Melessa

`MLH Private Pay Payment Link` is created intentionally **blank**. Provide the
Stripe or GHL payment link and update that one custom value.

## Verify (optional)

```bash
H=(-H "Authorization: Bearer $GHL_API_TOKEN" -H "Version: 2021-07-28")
B="https://services.leadconnectorhq.com/locations/$GHL_LOCATION_ID"
curl -s "${H[@]}" "$B/customFields?model=contact" | jq '.customFields | length'
curl -s "${H[@]}" "$B/customValues"               | jq '.customValues | length'
curl -s "${H[@]}" "$B/tags"                        | jq '.tags | length'
```
