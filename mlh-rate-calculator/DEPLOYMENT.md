# MLH Rate Calculator — Endpoint Deployment

A single read-only JSON endpoint over the existing **New Rate Calculator**
Google Sheet. One URL serves both the **GHL agent quoting** flow and the
**Dispatch Helper bridge** (Netlify).

- **Sheet:** New Rate Calculator
  (`1LqxRrzz6Qa3CUSwXtdYuNdQu_pFGFyZHN-BpKVwknMM`), owner `shopmylittlehelper@gmail.com`
- **Files here:** `Code.gs` (the endpoint), `appsscript.json` (web-app manifest)

---

## Step 1 — What already exists in the sheet (read before writing)

- **No quoting script was detectable.** Only rate tabs + formulas are present.
  > ⚠️ Confirm this yourself: open **Extensions → Apps Script**. If a `doGet`
  > already exists, deploy *that* instead of pasting this one. If the editor is
  > empty, proceed below.
- **Every account tab shares one layout:**
  - A **rate-constants** block: `Per Mile`, `Base`, `Additional Passenger`,
    `Other`, `Wait Time (per hour)`, `Deadhead Miles`.
  - An **origin-locked mileage** block: `Office to pickup` = **Charlotte, NC
    28273**, feeding `GOOGLEMAPS` distance for Office→Pickup (**deadhead** miles)
    and Pickup→Dropoff (**billable** miles).
  - A **fee** block ending in `TOTAL TRIP`.
- **Master** tab is the template (Per Mile $3.00, Base $0, Addl Pax $10,
  Wait $25, Deadhead $0.08). Account/broker tabs run Per Mile $3.50 / Base $30 /
  Addl Pax $5 / Wait $20 / Deadhead $0.75. Verified against a worked row:
  32.2 billable mi × $3.50 = **$112.70**, 2 addl pax × $5 = **$10.00**.

The endpoint does **not** rebuild rates — it reads each tab's constants live and
recreates the sheet's GOOGLEMAPS mileage with the Apps Script Maps service.
Change a rate in the sheet and the endpoint follows on the next call.

---

## The fare math (as confirmed)

```
billableMiles = miles(Pickup → Dropoff)        # ×2 if roundTrip
deadheadMiles = miles(Charlotte, NC 28273 → Pickup)   # ×2 if roundTrip

milesFee     = billableMiles × PerMile
deadheadFee  = deadheadMiles × DeadheadMiles
addlPaxFee   = max(0, passengers − 1) × AdditionalPassenger
waitFee      = waitTimeHours × WaitTime
baseFee      = Base   (ONLY on Private Pay + out-of-area broker tabs; else 0)

totalFare    = milesFee + deadheadFee + addlPaxFee + waitFee + baseFee
```

Confirmed choices baked in:
- **Base** applies only on **Private Pay** and **broker** accounts → edit
  `BASE_FARE_ACCOUNTS` in `Code.gs` to list each broker accountType.
- **Passengers:** surcharge on every passenger **beyond the first**.
- **Round trip:** doubles **billable + deadhead** miles; flat fees charged once.

---

## ✅ Confirm before you publish

In `Code.gs`, check the **CONFIG** block at the top:

1. **`ACCOUNT_TABS`** — the tab name on the right of each entry must match the
   workbook's tab names **exactly** (spelling, spacing, capitalization). Add a
   line for every broker tab.
2. **`BASE_FARE_ACCOUNTS`** — add each broker `accountType` so its Base fare is
   included (Private Pay is already there).
3. **`SPREADSHEET_ID`** and **`OFFICE_ORIGIN`** are pre-filled — leave as is.

---

## Step 2 — Publish the Web App (you deploy — this can't be done for you)

1. Open the sheet → **Extensions → Apps Script**.
2. In the editor, paste the contents of **`Code.gs`** into the `Code.gs` file
   (replace anything there only after confirming Step 1).
3. (Optional but recommended) Click the gear **Project Settings →** check
   *"Show appsscript.json manifest in editor"*, then paste **`appsscript.json`**
   over the manifest. This locks web-app access to anonymous + execute-as-you.
4. Click **Save** (💾).
5. Top-right **Deploy → New deployment**.
6. **Select type** (gear icon) → **Web app**.
7. Set:
   - **Description:** `MLH Rate Calculator endpoint`
   - **Execute as:** **Me** (`shopmylittlehelper@gmail.com`)
   - **Who has access:** **Anyone**
8. Click **Deploy**.
9. **Authorize access** when prompted (review → Allow). The Maps + Sheets scopes
   are required for mileage and reading rates.
10. Copy the **Web app URL** — it ends in `/exec`. That is your live endpoint.

> When you change `Code.gs` later: **Deploy → Manage deployments → ✏️ Edit →
> Version: New version → Deploy.** The `/exec` URL stays the same.

---

## Step 3 — Test it

Paste in a browser (URL-encode addresses, or let the browser do it):

```
<YOUR_/exec_URL>?accountType=Private%20Pay&pickup=3540%20Mt%20Holly-Huntersville%20Rd,%20Charlotte%20NC&dropoff=4741%20Randolph%20Rd,%20Charlotte%20NC&passengers=3&waitTimeHours=0&roundTrip=false&jobId=TEST-001
```

Expected shape (values depend on live rates/mileage):

```json
{ "jobId": "TEST-001", "accountType": "Private Pay", "miles": 32.2, "timeEstimate": "47 min", "totalFare": 162.70 }
```

Errors come back as JSON too, e.g.
`{ "jobId": "TEST-001", "error": "Unknown accountType ..." }`.

---

## Wiring it up

### GHL (agent quoting)
- **Location ID:** `nh4p0OCR9P8CYbnf71oH`
- Add a **Custom Webhook / external request** action that calls the `/exec` URL
  with the caller's `pickup`, `dropoff`, `accountType`, `passengers`,
  `waitTimeHours`, `roundTrip`, and the opportunity/job id as `jobId`.
- Map the JSON response fields (`totalFare`, `miles`, `timeEstimate`) back into
  the conversation / custom values.

> 🔐 **Secret handling:** your GHL Private Integration **token (`pit-…`) is NOT
> stored in this repo and must not be.** Keep it in GHL's stored values / the
> Netlify environment only. The endpoint itself needs **no** token — it's
> deployed as "Anyone", so GHL and Netlify call the `/exec` URL directly.

### Dispatch Helper bridge (Netlify)
- Call the same `/exec` URL server-side and parse the JSON. No HTML is ever
  returned, so `JSON.parse(response)` is safe.

---

## Hard-rules compliance

| Rule | How it's met |
|---|---|
| Sheet formulas untouched | Endpoint only calls `getDataRange().getValues()` — no writes. |
| Reads, never overwrites | No `setValue`/`setFormula` anywhere in `Code.gs`. |
| JSON only | Responses use `ContentService` `MimeType.JSON` — no HTML. |
| Office origin locked | `OFFICE_ORIGIN = 'Charlotte, NC 28273'`, never read from a param. |
| One endpoint, two consumers | Same `/exec` URL for GHL and the Netlify bridge. |
| Don't invent rates | All rate constants are read live from the selected tab. |
