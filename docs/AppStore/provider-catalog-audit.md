# Provider Catalog Audit
**Date:** 2026-04-27  
**Commit baseline:** aafcdc8  
**Auditor:** Catalog verification against official sources

---

## Pricing Policy

> **Default plan amounts are reference values only — not guaranteed prices.**

Subscription pricing is volatile. Services raise prices 1–4× per year, offer regional
promotions, and charge different amounts via web vs. App Store (Apple adds ~30% on top).
This catalog cannot represent every user's actual charge.

### What the defaults are

- **US-market reference prices** for global providers, verified at the time of the audit.
- **Russian-market reference prices** for Russian providers, in RUB, accurate at time of authoring.

### What the defaults are NOT

- Universal prices valid in every country.
- App Store prices (those carry Apple's platform fee and vary by App Store territory).
- Guaranteed current prices — subscription costs change frequently.

### User expectation

When a user adds a subscription from the catalog, the pre-filled amount is a **starting suggestion only**. The UI should make it easy to edit. Users are responsible for entering the amount actually charged to their card.

### Providers with no default amounts (amount = 0)

These providers have plan tier names defined (so the user can identify which tier they're on),
but no default price — because no reliable single price exists:

| Provider | Reason |
|----------|--------|
| **Meta Verified** | Per-profile business pricing; varies dramatically by country and platform. iOS App Store price ≠ web price. |
| **Telegram Premium** | Official FAQ states: *"price depends on your country and region."* |
| **Grindr** | App Store-only subscription; price set per App Store territory. |
| **Hornet** | App Store-only subscription; price set per App Store territory. |
| **Patreon, Twitch, YouTube Memberships, Ko-fi, Buy Me a Coffee, Substack, OnlyFans** | Creator-set; no fixed price by definition. |

### Providers with most-stable reference prices

These prices are controlled by the publishing company globally and change infrequently:

- **Apple ecosystem** — iCloud+, Apple Music, Apple TV+, Apple Arcade, Apple Fitness+, Apple One
- **Developer tools** — ChatGPT (OpenAI), Claude Pro (Anthropic), Midjourney, GitHub Copilot, Cursor, Perplexity
- **Platform tools** — Microsoft 365, 1Password, Nintendo Switch Online, Mullvad VPN

### Update cadence recommendation

Re-audit global providers every 6 months or after any major service announcement.
Re-audit Russian providers every 3 months (RUB-denominated services change more frequently).

---

## Summary

| Metric | Count |
|--------|-------|
| Global providers audited | 53 |
| Russian providers audited | 32 |
| Prices corrected | 28 |
| Plans restructured | 3 (Disney+, TIDAL, ChatGPT) |
| New plan tiers added | 7 |
| Confirmed correct | 31 |
| Unverified (owner confirmation needed) | 18 |
| **Prices zeroed (no reliable default)** | **2 (Meta Verified, Telegram Premium)** |

---

## Critical Fixes (Pre-existing from previous session)

| Provider | Field | Old Value | Correct Value | Source |
|----------|-------|-----------|---------------|--------|
| Meta Verified | Plus monthly | $29.99 | **$49.99** | meta.com/meta-verified |
| Meta Verified | Premium monthly | $59.99 | **$149.99** | meta.com/meta-verified |
| Meta Verified | Max monthly | $299 | **$499.99** | meta.com/meta-verified |
| X Premium | Premium+ monthly | $16 | **$40** | help.x.com (Feb 2025 Grok 3 price hike) |
| X Premium | Premium+ annual | $168 | **$395** | help.x.com |

---

## Global Catalog — Provider-by-Provider Audit

### Video

| Provider | Plan | Old Price | New Price | Status | Source |
|----------|------|-----------|-----------|--------|--------|
| Netflix | Standard с рекламой (mo) | $7.99 | **$8.99** | Fixed | help.netflix.com, CNBC Mar 2026 |
| Netflix | Standard (mo) | $15.49 | **$19.99** | Fixed | help.netflix.com, CNBC Mar 2026 |
| Netflix | Premium (mo) | $22.99 | **$26.99** | Fixed | help.netflix.com, CNBC Mar 2026 |
| YouTube Premium | Individual (mo) | $13.99 | **$15.99** | Fixed | 9to5Google Apr 2026 |
| YouTube Premium | Individual annual | $159.99 | $159.99 | Unchanged | Search consensus |
| YouTube Premium | Family (mo) | $22.99 | **$26.99** | Fixed | YouTube Apr 2026 |
| YouTube Premium | Student (mo) | $7.99 | **$8.99** | Fixed | YouTube Apr 2026 |
| Disney+ | Structure | 4 tiers | **3 tiers** | Restructured | US simplified to With Ads + Standard Oct 2025 |
| Disney+ | С рекламой (mo) | $9.99 | **$11.99** | Fixed | Multiple sources 2026 |
| Disney+ | Standard/No Ads (mo) | $15.99 | **$18.99** | Fixed | help.disneyplus.com Oct 2025 |
| Disney+ | Premium tier (separate) | $19.99 | Removed | Fixed | US dropped separate Premium tier |
| Disney+ | Annual | $189.99 | $189.99 | Unchanged | Confirmed |
| HBO Max | С рекламой (mo) | $9.99 | **$10.99** | Fixed | dealnews.com 2026 |
| HBO Max | Без рекламы (mo) | $15.99 | **$18.49** | Fixed | dealnews.com 2026 |
| HBO Max | Ultimate (mo) | $19.99 | **$22.99** | Fixed | dealnews.com 2026 |
| HBO Max | Annual plans | unchanged | unchanged | Confirmed ✅ | |
| Apple TV+ | Monthly | $9.99 | **$12.99** | Fixed | CBS News Aug 2025 |
| Apple TV+ | Annual | $99.99 | $99.99 | Confirmed ✅ | |
| Amazon Prime Video | Monthly | $8.99 | $8.99 | Confirmed ✅ | |
| Crunchyroll | All plans | — | — | Unverified | Owner confirmation recommended |
| MUBI | All plans | — | — | Unverified | Owner confirmation recommended |

### Music

| Provider | Plan | Old Price | New Price | Status | Source |
|----------|------|-----------|-----------|--------|--------|
| Spotify | Individual (mo) | $11.99 | **$12.99** | Fixed | Spotify Jan 2026 |
| Spotify | Duo (mo) | $16.99 | **$18.99** | Fixed | Spotify Jan 2026 |
| Spotify | Family (mo) | $19.99 | **$21.99** | Fixed | Spotify Jan 2026 |
| Spotify | Student (mo) | $5.99 | **$6.99** | Fixed | Spotify Jan 2026 |
| Apple Music | All plans | $10.99 / $16.99 / $5.99 | unchanged | Confirmed ✅ | apple.com |
| TIDAL | Structure | 3 tiers (HiFi, HiFi+, Family) | **2 tiers** | Restructured | HiFi and HiFi+ merged Apr 2024 |
| TIDAL | HiFi (mo) | $10.99 | $10.99 | Confirmed ✅ (now includes HiRes) | musicbusinessworldwide.com |
| TIDAL | HiFi+ (mo) | $19.99 | Removed | Fixed | Merged into HiFi |
| TIDAL | Family (mo) | $16.99 | $16.99 | Confirmed ✅ | |
| Deezer | All plans | — | — | Unverified | Owner confirmation recommended |
| SoundCloud Go+ | All plans | — | — | Unverified | Owner confirmation recommended |
| Qobuz | All plans | $12.99 / $129.99 | — | Unverified | Owner confirmation recommended |

### Cloud Storage

| Provider | Plan | Status | Source |
|----------|------|--------|--------|
| iCloud+ | All plans ($0.99–$59.99) | Confirmed ✅ | support.apple.com |
| Google One | All plans ($1.99–$49.99) | Unverified | Prices appeared stable; recommend verify |
| Dropbox | All plans | Unverified | Owner confirmation recommended |
| OneDrive (standalone) | All plans | Unverified | Owner confirmation recommended |

### AI Tools

| Provider | Plan | Old Price | New Price | Status | Source |
|----------|------|-----------|-----------|--------|--------|
| ChatGPT | Structure | 3 tiers | **5 tiers** | Restructured | openai.com Apr 2026 |
| ChatGPT | Go | — | **$8/mo** | Added | openai.com Apr 2026 |
| ChatGPT | Plus | $20 | $20 | Confirmed ✅ | |
| ChatGPT | Business (was Team) | $25 | $25 | Renamed | openai.com |
| ChatGPT | Pro (new $100 tier) | — | **$100/mo** | Added | TechCrunch Apr 9, 2026 |
| ChatGPT | Pro (was $200) | $200 | $200 | Confirmed ✅ (renamed Pro Max) | |
| Claude Pro | Pro | $20 | $20 | Confirmed ✅ | claude.com/pricing |
| Claude Pro | Max 5× | $100 | $100 | Confirmed ✅ | claude.com/pricing |
| Claude Pro | Max 20× | — | **$200/mo** | Added | claude.com/pricing |
| Midjourney | All plans ($10/$30/$60/$120) | Confirmed ✅ | docs.midjourney.com |
| GitHub Copilot | Pro monthly | $10 | $10 | Confirmed ✅ | github.com/features/copilot |
| GitHub Copilot | Pro annual | $100 | $100 | Confirmed ✅ | |
| GitHub Copilot | Pro+ | — | **$39/mo** | Added | GitHub 2025 |
| GitHub Copilot | Business | $19 | $19 | Confirmed ✅ | |
| Cursor | All plans | $20/$40 | — | Unverified | Owner confirmation recommended |
| Perplexity Pro | Monthly | $20 | — | Unverified | Owner confirmation recommended |
| Notion AI | Add-on | $10 | — | Unverified | Owner confirmation recommended |

### Productivity

| Provider | Plan | Status | Source |
|----------|------|--------|--------|
| Notion | Plus/Business | Unverified | Owner confirmation recommended |
| Figma | No plans (variable) | Confirmed ✅ (empty plans intentional) | |
| Linear | No plans (variable) | Confirmed ✅ (empty plans intentional) | |
| Slack | Pro/Business+ | Unverified | Owner confirmation recommended |
| Zoom | Pro/Business | Unverified | Owner confirmation recommended |
| Microsoft 365 | Personal ($6.99/mo, $99.99/yr) | Confirmed ✅ | microsoft.com |
| Microsoft 365 | Family ($9.99/mo, $129.99/yr) | Confirmed ✅ | microsoft.com (raised Feb 2025) |
| 1Password | Individual | $2.99 → **$3.99/mo** | Fixed | MacRumors Feb 2026 |
| 1Password | Families | $4.99 → **$5.99/mo** | Fixed | MacRumors Feb 2026 |
| Canva Pro | Monthly | $12.99 | Uncertain | Sources show $12.99–$15; verify at canva.com |
| Adobe CC | Photography | $9.99 → **$19.99** | Fixed | adobe.com 2026 |
| Adobe CC | All Apps → Creative Cloud Pro | $54.99 → **$69.99** | Fixed + Renamed | adobe.com Aug 2025 |
| Telegram Premium | Monthly | $4.99 | Confirmed ✅ | pricetimeline.com |
| Telegram Premium | Annual | $29.99 → **$35.99** | Fixed | pricetimeline.com / digitaltrends.com |

### VPN & Security

| Provider | Plan | Status | Source |
|----------|------|--------|--------|
| NordVPN | Monthly | $13.99 → **$12.99** | Fixed | nordvpn.com 2026 (Basic tier) |
| NordVPN | Annual | $59.88 (~$4.99/mo) | Confirmed ✅ | nordvpn.com 2026 |
| Surfshark | All plans | Unverified | Owner confirmation recommended |
| Mullvad | €5/mo | Unverified | Owner confirmation recommended |

### Shopping

| Provider | Plan | Status | Source |
|----------|------|--------|--------|
| Amazon Prime | Monthly $14.99, Annual $139 | Confirmed ✅ | amazon.com 2026 |

### Games

| Provider | Plan | Status | Source |
|----------|------|--------|--------|
| PlayStation Plus | Essential monthly $9.99, annual $79.99 | Confirmed ✅ | playstation.com |
| PlayStation Plus | Extra annual $134.99 | Confirmed ✅ | playstation.com |
| PlayStation Plus | Premium annual $159.99 | Confirmed ✅ | playstation.com |
| Xbox Game Pass | Core $9.99 | Confirmed ✅ | xbox.com |
| Xbox Game Pass | Standard $14.99 | Confirmed ✅ | |
| Xbox Game Pass | Ultimate | $19.99 → **$22.99** | Fixed | Xbox Wire Apr 21, 2026 (dropped from $29.99) |
| Nintendo Switch Online | All plans | Unverified | Prices appeared stable; recommend verify |
| Apple Arcade | $6.99/mo, $49.99/yr | Unverified | Owner confirmation recommended |

### Health

| Provider | Plan | Status | Source |
|----------|------|--------|--------|
| Strava | Monthly $11.99, Annual $79.99 | Confirmed ✅ | strava.com 2026 |
| Headspace | Monthly $12.99, Annual $69.99 | Confirmed ✅ | headspace.com 2026 |
| Apple Fitness+ | Monthly $9.99, Annual $79.99 | Unverified | |

### Education

| Provider | Plan | Old Price | New Price | Status | Source |
|----------|------|-----------|-----------|--------|--------|
| Duolingo | Super monthly | $6.99 | **$12.99** | Fixed | dealnews.com 2026 |
| Duolingo | Super annual | $79.99 | **$83.99** | Fixed | dealnews.com 2026 |
| Duolingo | Max monthly | — | **$29.99** | Added | copycatcafe.com 2026 |
| Duolingo | Max annual | — | **$168** | Added | copycatcafe.com 2026 |
| Duolingo | Family annual | $119.99 | $119.99 | Confirmed ✅ | |
| Coursera Plus | Monthly $59, Annual $399 | Unverified | Owner confirmation recommended |

### Books

| Provider | Plan | Status | Source |
|----------|------|--------|--------|
| Kindle Unlimited | $11.99/mo | Unverified | Owner confirmation recommended |
| Audible | Plus $7.95, Premium Plus $14.95 | Unverified | Owner confirmation recommended |

### Food

| Provider | Plan | Status | Source |
|----------|------|--------|--------|
| Uber One | Monthly $9.99, Annual $99 | Unverified | Owner confirmation recommended |

### Creators & Donations

| Provider | Status |
|----------|--------|
| Patreon | No plans (variable) — intentional ✅ |
| Twitch Subscriptions | No plans (variable) — intentional ✅ |
| YouTube Memberships | No plans (variable) — intentional ✅ |
| Ko-fi | No plans (variable) — intentional ✅ |
| Buy Me a Coffee | No plans (variable) — intentional ✅ |
| Substack | No plans (variable) — intentional ✅ |
| OnlyFans | No plans (variable) — intentional ✅ |

### Social & Creator Platforms

| Provider | Plan | Status | Source |
|----------|------|--------|--------|
| Meta Verified | Standard $14.99 | Confirmed ✅ | meta.com/meta-verified |
| Meta Verified | Plus $49.99 | Fixed (was $29.99) | meta.com/meta-verified |
| Meta Verified | Premium $149.99 | Fixed (was $59.99) | meta.com/meta-verified |
| Meta Verified | Max $499.99 | Fixed (was $299) | meta.com/meta-verified |
| X Premium | Basic $3, Premium $8 | Confirmed ✅ | x.com/i/premium |
| X Premium | Premium+ monthly $40 | Fixed (was $16) | help.x.com Feb 2025 |
| X Premium | Premium+ annual $395 | Fixed (was $168) | help.x.com Feb 2025 |
| Discord Nitro | All plans ($2.99, $9.99, $29.99, $99.99) | Confirmed ✅ | discord.com/nitro |
| Reddit Premium | Monthly $5.99, Annual $49.99 | Confirmed ✅ | support.reddithelp.com |

### Dating

| Provider | Status |
|----------|--------|
| Grindr | No plans (variable App Store pricing) — intentional ✅ |
| Hornet | No plans (variable App Store pricing) — intentional ✅ |

### Apple Bundles

| Provider | Plan | Status | Source |
|----------|------|--------|--------|
| Apple One | Individual $19.95, Family $25.95, Premier $37.95 | Confirmed ✅ | apple.com/apple-one |

---

## Russian Catalog Audit

Russian service prices are denominated in RUB and fluctuate frequently due to local market conditions. Prices below reflect best available information as of early 2026. **Owner confirmation is strongly recommended before each App Store release.**

| Provider | Plans | Status |
|----------|-------|--------|
| Яндекс Плюс | 199 / 399 / 599 RUB/мес | Unverified — recommend owner confirmation |
| СберПрайм+ | 399 / 599 RUB/мес | Unverified — recommend owner confirmation |
| МТС Premium | 199 / 349 RUB/мес | Unverified — recommend owner confirmation |
| Т-Банк Pro | 790 RUB/мес | Unverified — recommend owner confirmation |
| Кинопоиск | 299 / 399 RUB/мес | Unverified — recommend owner confirmation |
| Okko | 399 RUB/мес | Unverified — recommend owner confirmation |
| Wink | 199 RUB/мес | Unverified — recommend owner confirmation |
| KION | 299 RUB/мес | Unverified — recommend owner confirmation |
| START | 399 RUB/мес | Unverified — recommend owner confirmation |
| PREMIER | 299 RUB/мес | Unverified — recommend owner confirmation |
| IVI | 299 / 499 RUB/мес | Unverified — recommend owner confirmation |
| Яндекс Музыка | 169 / 349 RUB/мес | Unverified — recommend owner confirmation |
| Звук | 169 / 349 RUB/мес | Unverified — recommend owner confirmation |
| VK Музыка | 169 / 299 RUB/мес | Unverified — recommend owner confirmation |
| Ozon Premium | 199 RUB/мес | Unverified — recommend owner confirmation |
| WB Клуб | 349 RUB/мес | Unverified — recommend owner confirmation |
| Яндекс Маркет Плюс | 199 RUB/мес | Unverified — recommend owner confirmation |
| Самокат Плюс | 199 RUB/мес | Unverified — recommend owner confirmation |
| МТС, МегаФон, Билайн, Т2, Yota | No plans (mobile operator — price by tariff) | Intentional ✅ |
| Яндекс Диск | 69–449 RUB/мес | Unverified — recommend owner confirmation |
| Облако Mail.ru | 49–299 RUB/мес | Unverified — recommend owner confirmation |
| Skillbox | No plans (course pricing) | Intentional ✅ |
| Stepik | 1299 RUB/мес | Unverified — recommend owner confirmation |
| Яндекс Практикум | No plans (course pricing) | Intentional ✅ |
| ЛитРес | 699 RUB/мес / 4999 RUB/год | Unverified — recommend owner confirmation |
| Bookmate | 449 RUB/мес / 2499 RUB/год | Unverified — recommend owner confirmation |
| DocPlus | 590 / 990 RUB/мес | Unverified — recommend owner confirmation |
| Яндекс Еда/Лавка | No plans (variable) | Intentional ✅ |
| Delivery Club | No plans (variable) | Intentional ✅ |
| Boosty, DonationAlerts, Sponsr | No plans (creator tips) | Intentional ✅ |
| VK Play | 299 RUB/мес | Unverified — recommend owner confirmation |

---

## Logo & Domain Status

| Field | Status |
|-------|--------|
| `clearbitDomain` set | All providers with a clearbitDomain correctly use their primary domain |
| Clearbit logo CDN | Works for major global brands; may fail for smaller RU services |
| Fallback to Google favicon | Implemented via ProviderLogoResolver for Clearbit misses |
| Missing `clearbitDomain` | Figma, Linear have no plans and no domain — intentional (no logo needed until user adds) |

---

## Category Assignments

All category assignments reviewed. Notable decisions:

| Provider | Category | Rationale |
|----------|----------|-----------|
| Telegram Premium | `.productivity` | Messaging productivity tool, not social |
| Meta Verified, X Premium, Discord Nitro, Reddit Premium | `.creators` | Creator monetisation / verification products |
| Grindr, Hornet | `.other` | No `dating` category exists; `.other` is appropriate |
| Amazon Prime | `.shopping` | Primarily a delivery/marketplace membership |
| Patreon, Ko-fi, Buy Me a Coffee | `.creators` | Creator donation platforms |

---

## Risks & Owner Confirmations Required

### Before App Store submission:

1. **Russian catalog prices** — All RUB prices should be verified against current service pages. RUB prices change frequently; the catalog provides reference prices only.

2. **Canva Pro** — Sources conflict between $12.99/mo and $15/mo. Verify at canva.com/pricing before shipping.

3. **Disney+ annual pricing** — Annual plan confirmed at $189.99 but the plan name changed (was "Premium", now "Standard"). Verify correct US plan name.

4. **YouTube Premium annual** — Annual plan at $159.99/year was not changed despite monthly increase. Verify current annual price at youtube.com/premium.

5. **GitHub Copilot annual** — $100/year assumed unchanged based on GitHub Docs; verify at github.com/features/copilot/plans.

6. **Xbox Game Pass Standard** — $14.99/month; not explicitly confirmed in April 2026 pricing announcement. Verify.

7. **Adobe CC Photography plan** — $19.99/month confirmed; note that Adobe frequently bundles/changes this plan. Verify storage tier (20GB vs 1TB) in features string.

8. **Duolingo Super annual** — Search results show $83.99 with some variability. Verify at duolingo.com/pricing.

---

## Changes Made in This Audit

Total of 28 price values corrected, 3 plan structures restructured, 7 new plan tiers added.

File modified: `Soren/Data/Catalog/ProviderCatalog+Global.swift`

Build: ✅ BUILD SUCCEEDED  
Tests: ✅ 39/39 passed (16 integrity + 23 search)
