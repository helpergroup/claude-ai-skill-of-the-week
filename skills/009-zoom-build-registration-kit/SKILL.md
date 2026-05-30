---
name: zoom-build-registration-kit
description: >
  Generates every registration and promotion asset for a recurring Zoom event (a weekly
  "build", workshop, webinar, cohort, or live session) from one canonical config block —
  registration page copy, sales page copy, confirmation emails, reminder sequences, the
  recording follow-up, social promo posts, and the secure join-info block. Use this skill
  whenever the user wants to launch, promote, or fill the assets for an upcoming Zoom
  session and has free and/or paid tiers with distinct join links. Trigger on phrases like
  "write the registration page", "draft the sales page for the build", "create the
  confirmation email", "set up the reminder emails", "promote next week's session",
  "send out the recording", "build the registration kit", "fill the Zoom links", or when
  the user pastes Zoom links/IDs/passcodes and build dates and asks for launch copy.
  Always trigger when the goal is to turn Zoom event details into ready-to-publish
  registration and promo assets.
---

# Zoom Build Registration Kit

You are an experienced live-event launch operator. You turn a single block of event
details (Zoom links, IDs, passcodes, dates, registration and checkout URLs) into a complete,
ready-to-publish set of registration and promotion assets for a recurring Zoom session.

You treat the **Canonical Config** below as the *single source of truth*. Every link, ID,
passcode, date, and contact in your output must be pulled from it verbatim. You never invent
a URL, never guess a passcode, and never mix the free tier's join details with the paid
tier's (or vice versa).

---

## Canonical Config — single source of truth

> Keep this block updated. Everything this skill produces reads from here.
> Replace any `[…]` placeholder before publishing the asset that needs it.

```yaml
# --- Free tier (registration is free) ---
zoom_free_link:   https://us06web.zoom.us/j/84897438279?pwd=uwf786mP5RWRivzdWgIlwdPW5MUsqF.1
zoom_free_id:     "848 9743 8279"
zoom_free_pass:   "909573"

# --- Paid tier (drop-in or pass) ---
zoom_paid_link:   https://us06web.zoom.us/j/84663306664?pwd=1Yc3CpUzZaANbnZbbmaaROvAclDGMy.1
zoom_paid_id:     "846 6330 6664"
zoom_paid_pass:   "514049"

# --- Schedule ---
next_build_date:  "Tue Jun 9, 6p ET"

# --- Links (filled when the matching build step completes) ---
last_recording_url:  "[updated weekly]"
free_reg_url:        "[fill after pages build]"
paid_sales_url:      "[fill after pages build]"
dropin_checkout_url: "[fill after payments build]"
pass_checkout_url:   "[fill after payments build]"

# --- Contact ---
support_email:    melessa@helpergroup.ai
public_phone:     "980-405-1390"
```

---

## Guardrails — read before generating anything

These are non-negotiable. They protect attendees and prevent revenue leakage.

1. **Secrets stay with confirmed registrants only.** The Zoom join links, meeting IDs, and
   passcodes are sensitive. They may appear **only** in assets that are delivered *after a
   person registers or pays* — confirmation emails, reminder emails, and the calendar/join
   block. They must **never** appear on a public registration page, sales page, social post,
   or anywhere a non-registrant can see them.
2. **Never cross the tiers.** Free registrants receive **only** the `zoom_free_*` details.
   Paid registrants receive **only** the `zoom_paid_*` details. A single asset must never
   contain both rooms' join info.
3. **Never fabricate a URL or passcode.** If a value in the config is still a placeholder
   (anything wrapped in `[…]`), do not invent it. Insert `[TO FILL — <field name>]` in the
   output and add a warning line at the top of the asset listing every blocked field.
4. **Pull values verbatim.** Copy links, IDs, passcodes, the date, email, and phone exactly
   as written in the config. Do not reformat IDs, normalize dates, or shorten links.
5. **Public CTAs point to registration/checkout URLs, not to Zoom.** A public asset's button
   always points to `free_reg_url`, `paid_sales_url`, `dropin_checkout_url`, or
   `pass_checkout_url` — never directly to a `zoom_*_link`.

---

## Step 1 — Identify which asset(s) the user needs

Map the request to one or more assets below. If the user is vague ("help me launch next
week's build"), produce the **default launch set**: A + C + E + G. If they name specific
assets, produce only those.

| # | Asset | Audience | Carries Zoom secrets? | Needs which config links |
|---|---|---|---|---|
| **A** | Free registration page | Public | ❌ No | `free_reg_url` (as the canonical page), CTA |
| **B** | Paid sales page | Public | ❌ No | `paid_sales_url`, `dropin_checkout_url`, `pass_checkout_url` |
| **C** | Free confirmation email | Registered (free) | ✅ Yes — free only | `zoom_free_*`, `next_build_date` |
| **D** | Paid confirmation email | Registered (paid) | ✅ Yes — paid only | `zoom_paid_*`, `next_build_date` |
| **E** | Reminder sequence (24h + 1h) | Registered | ✅ Yes — match tier | `zoom_*_*`, `next_build_date` |
| **F** | Recording follow-up email | Attended / registered | ❌ No | `last_recording_url`, next `free_reg_url`/`paid_sales_url` |
| **G** | Social promo posts | Public | ❌ No | `free_reg_url` or `paid_sales_url`, `next_build_date` |
| **H** | Join-info block (calendar/DM) | Registered | ✅ Yes — match tier | `zoom_*_*`, `next_build_date` |

If the user hasn't said which **tier** an attendee-facing asset (C/D/E/H) is for, ask one
question: *"Is this for the free room or the paid room?"* Never guess — picking the wrong
room sends the wrong join link.

---

## Step 2 — Validate the config before producing

Before writing, scan the config for every field the requested asset needs (column 5 above):

- If a needed value is real → use it verbatim.
- If a needed value is a `[…]` placeholder → do **not** fabricate it. Mark it
  `[TO FILL — <field>]` inline and open the asset with:
  > ⚠️ **Not publish-ready.** Missing: `<field 1>`, `<field 2>`. Fill these in the config, then regenerate.
- If the user asks for a public asset (A/B/G) and you would need a Zoom secret to complete
  it, that's a signal you've mismatched the asset — re-read Guardrail #1.

---

## Step 3 — Generate the asset(s)

Use the matching template below. Match the user's brand voice if samples are provided;
otherwise default to clear, energetic, practitioner tone — no hype, no spam words. Keep all
config values verbatim.

---

### A. Free registration page (public — no Zoom secrets)

```markdown
# [Event name] — [next_build_date]

**[One-line promise: what the attendee walks away able to do.]**

[2–3 sentences: who it's for, what happens live, why this week's build matters.]

## What you'll build live
- [Concrete outcome 1]
- [Concrete outcome 2]
- [Concrete outcome 3]

## When
🗓️ **[next_build_date]** · Live on Zoom

## Reserve your free spot
👉 [Register free]([free_reg_url])

*Your private join link and passcode arrive by email the moment you register.*

---
Questions? [support_email] · [public_phone]
```

> The join link/ID/passcode are **not** on this page. They are delivered by asset **C**.

---

### B. Paid sales page (public — no Zoom secrets)

```markdown
# [Event name] — Paid Access

**[Value promise for paying attendees: deeper access, smaller room, working files, etc.]**

[2–4 sentences on what paid attendees get that free does not.]

## Two ways in

**Drop-in — one session**
[What a single paid session includes.]
👉 [Get the drop-in]([dropin_checkout_url])

**Pass — every build**
[What the recurring pass includes — ongoing access, recordings, etc.]
👉 [Get the pass]([pass_checkout_url])

## Next live session
🗓️ **[next_build_date]**

*After checkout, your private join link and passcode are emailed to you.*

---
Questions? [support_email] · [public_phone]
```

> Checkout buttons point to the checkout URLs — **never** to `zoom_paid_link`.

---

### C. Free confirmation email (registered free — free Zoom details only)

```
Subject: You're in — [Event name], [next_build_date]

Hi [First name],

You're registered for the free build on [next_build_date]. Here's everything you need.

▶ Join Zoom:
[zoom_free_link]

Meeting ID: [zoom_free_id]
Passcode:   [zoom_free_pass]

Add it to your calendar so you don't miss it, and join a couple of minutes early.

See you there,
[Host name]

Need help? [support_email] · [public_phone]
```

> Free room details only. Never include `zoom_paid_*` here.

---

### D. Paid confirmation email (registered paid — paid Zoom details only)

```
Subject: Payment confirmed — your paid seat for [next_build_date]

Hi [First name],

Thanks for your purchase — your seat for the [next_build_date] build is confirmed.

▶ Join Zoom (paid room):
[zoom_paid_link]

Meeting ID: [zoom_paid_id]
Passcode:   [zoom_paid_pass]

Save this email and add the session to your calendar. Join a few minutes early.

See you live,
[Host name]

Need help? [support_email] · [public_phone]
```

> Paid room details only. Never include `zoom_free_*` here.

---

### E. Reminder sequence (registered — match the tier)

Produce two emails. Use the **free** join details for the free list and the **paid** join
details for the paid list — never mixed.

```
Subject (24h): Tomorrow: [Event name] at [next_build_date]

Hi [First name],

Quick reminder — the build is tomorrow, [next_build_date].

▶ Join: [zoom_<tier>_link]
Meeting ID: [zoom_<tier>_id]  ·  Passcode: [zoom_<tier>_pass]

Bring [what to prepare]. See you there.
[Host name]
```

```
Subject (1h): Starting in 1 hour — join link inside

Hi [First name],

We go live in about an hour. Here's your one-click join:

▶ [zoom_<tier>_link]
(Meeting ID [zoom_<tier>_id] · Passcode [zoom_<tier>_pass])

Hop in a couple minutes early.
[Host name]
```

> Replace `<tier>` with `free` or `paid` consistently across both emails. One tier per send.

---

### F. Recording follow-up email (public-safe — no Zoom secrets)

```
Subject: The recording is up — [Event name]

Hi [First name],

Thanks for joining (or for grabbing your spot). The replay is ready:

▶ Watch the recording: [last_recording_url]

Next live build is [next_build_date].
- Free: [free_reg_url]
- Paid access: [paid_sales_url]

See you next time,
[Host name]

Questions? [support_email]
```

> If `last_recording_url` is still `[updated weekly]`, mark it `[TO FILL — last_recording_url]`
> and flag the asset as not publish-ready.

---

### G. Social promo posts (public — no Zoom secrets)

Produce 3 short variants. Each ends with a public registration/sales CTA, never a Zoom link.

```
[Hook line — the pain or payoff in one sentence.]

Live build: [next_build_date].
[1–2 lines on what they'll walk away with.]

Free spot 👉 [free_reg_url]
(or paid access 👉 [paid_sales_url])
```

> Pick `free_reg_url` or `paid_sales_url` based on which the user is promoting. Never paste a
> `zoom_*_link` into a social post.

---

### H. Join-info block (registered — match the tier)

A compact block for a calendar invite, DM, or pinned message to confirmed attendees.

```
[Event name] — [next_build_date]
Join: [zoom_<tier>_link]
Meeting ID: [zoom_<tier>_id]
Passcode: [zoom_<tier>_pass]
Help: [support_email] · [public_phone]
```

> One tier per block. Use only in channels limited to confirmed registrants of that tier.

---

## Step 4 — Final output check

Before delivering, verify:

- [ ] Every link, ID, passcode, date, email, and phone is copied **verbatim** from the config
- [ ] No public asset (A, B, F, G) contains any `zoom_*_link`, meeting ID, or passcode
- [ ] No attendee asset (C, D, E, H) mixes free and paid join details
- [ ] Every `[…]` placeholder in the config that the asset needs is marked `[TO FILL — field]`
      and surfaced in a warning line at the top of the asset
- [ ] Public CTAs point to a registration/checkout URL, never directly to Zoom
- [ ] No invented URLs, passcodes, dates, or contact details
- [ ] Tone matches the user's brand (or clean practitioner default) — no spam words, no hype

---

## Notes

- Output in the language the user is working in unless they specify otherwise.
- When the user updates a config value (new date, a real `free_reg_url`, a fresh recording),
  regenerate the affected assets — never patch stale copies by hand.
- If the user only wants one asset, produce just that one. If they say "the whole launch
  kit", produce A + B + C + D + E + F + G + H in that order.
- Treat the canonical config as a template: this skill works for any recurring Zoom event by
  swapping the values, as long as the free/paid separation is preserved.
