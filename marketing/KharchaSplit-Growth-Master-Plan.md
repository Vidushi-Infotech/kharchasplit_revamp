# KharchaSplit — Mobile App Growth Strategy & Marketing Execution Plan

**Document owner:** CMO / Head of Growth
**Version:** 1.0
**Status:** Ready for execution
**Horizon:** 365 days (detailed to Day 90)
**Product:** KharchaSplit — group expense splitting & personal expense management app (Android + iOS, live)

---

## 0. How to Read & Use This Document

### 0.1 Task ID Convention

`P<phase>-<sequence>` — e.g. `P1-04` = Phase 1 (ASO), task 4. Use this ID as the Jira/ClickUp/Notion external key so this doc and the tracker stay in sync.

### 0.2 Owner Role Codes

| Code | Role |
|---|---|
| CMO | Chief Marketing Officer / Founder-Marketing |
| GM | Growth Manager |
| MM | Marketing Manager |
| ASO | ASO Specialist |
| SEO | SEO Specialist |
| PMK | Performance Marketer |
| SMM | Social Media Manager |
| CW | Content Writer |
| GD | Graphic Designer |
| VE | Video Editor |
| MD | Motion Designer |
| IM | Influencer Manager |
| PR | PR Executive |
| CM | Community Manager |
| CRM | CRM / Lifecycle Executive |
| DA | Data Analyst |
| CS | Customer Support |
| PM | Product Manager |
| MOB | Mobile Developer (Flutter) |
| BE | Backend Developer |

### 0.3 Cost Assumptions (India market, 2026)

- Costs are **monthly or one-time in INR (₹)**, stated per task.
- In-house salary cost is loaded at an hourly rate: Junior ₹300/hr, Mid ₹600/hr, Senior ₹1,200/hr.
- Where a task is done by existing salaried staff, cost is shown as **Internal (₹X effort value)**.
- Ad spend is excluded from task cost and budgeted separately in Phase 18.

### 0.4 Baseline Assumptions (replace with your real numbers before Day 1)

| Metric | Assumed Baseline | Source to Verify |
|---|---|---|
| Total installs to date | 5,000 | Play Console / App Store Connect |
| MAU | 1,200 | Firebase |
| D1 / D7 / D30 retention | 32% / 14% / 6% | Firebase Retention |
| Store listing conversion rate | 22% (Play), 28% (iOS) | Console Acquisition report |
| Organic : Paid install mix | 90:10 | AppsFlyer / Console |
| Avg rating | 4.2 (Play), 4.4 (iOS) | Store |
| Website sessions/mo | <500 | GA4 |
| Referral-driven installs | <2% | Not yet instrumented |

> **Day-0 action:** `P13-01` must be completed before any spend. Do not run paid campaigns without attribution live.

### 0.5 North Star Metric

**Weekly Active Expense-Splitting Groups (WAG)** — a group with ≥1 expense added in the last 7 days.
Chosen because it captures activation, retention and virality in one number (splitting is inherently multiplayer — every active group = 2–8 engaged users).

Supporting metrics: Installs, Registration Rate, D7 Retention, K-factor, CAC:LTV.

### 0.6 Target Outcomes (365 days)

| Metric | Baseline | Day 90 | Day 180 | Day 365 |
|---|---|---|---|---|
| Cumulative installs | 5K | 60K | 200K | 1,000K |
| MAU | 1.2K | 18K | 60K | 300K |
| Registration rate (install → signup) | 45% | 62% | 68% | 72% |
| D7 retention | 14% | 22% | 28% | 33% |
| D30 retention | 6% | 12% | 16% | 20% |
| Store conversion rate (Play) | 22% | 32% | 36% | 40% |
| K-factor (viral) | 0.1 | 0.35 | 0.55 | 0.8 |
| Blended CPI | — | ₹28 | ₹22 | ₹16 |
| Organic share of installs | 90% | 55% | 62% | 70% |
| Avg rating | 4.2 | 4.5 | 4.6 | 4.7 |
| Website organic sessions/mo | 500 | 15K | 60K | 250K |

---

# PHASE 1 — App Store Optimization (ASO)

**Objective:** Raise store conversion rate from 22% → 32% and win top-10 ranking for 40+ mid-tail keywords in IN, within 90 days. ASO is the single highest-ROI lever: it compounds, costs almost nothing in media, and lowers paid CPI by improving conversion on every ad click.

**Phase budget:** ₹1,45,000 one-time + ₹22,000/month
**Phase owner:** ASO Specialist, reporting to Growth Manager

### 1.1 Keyword Strategy Foundation

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P1-01 | ASO Audit — Current State | ASO | Full audit of both listings: metadata, keyword coverage, screenshots, reviews, ratings, conversion funnel, install-to-registration drop-off. Score each element 1–10 against a rubric. | Establishes the baseline every later ASO claim is measured against; without it you cannot prove ASO lift vs. seasonality. | High | ASO | ASO, Play Console, ASC analytics | 3 days | ₹15,000 (or Internal) | Play Console, App Store Connect, AppTweak/Sensor Tower | Console access | ASO Audit Deck (25 slides) + scored rubric sheet | Audit delivered; 20+ prioritised issues logged | Day 1–3 | Not Started |
| P1-02 | Seed Keyword Brainstorm | ASO | Build a 300+ raw keyword list from: product features, user language in reviews, support tickets, competitor metadata, Google autosuggest, Quora/Reddit phrasing. | Keyword tools only rank what you feed them; the seed list determines ceiling of the whole ASO program. | High | ASO + CW | Keyword research, user empathy | 2 days | Internal (₹6,000) | Google Sheets, AnswerThePublic, Play autosuggest | P1-01 | Seed keyword sheet (300+ terms) | 300+ seeds, 5 categories covered | Day 2–4 | Not Started |
| P1-03 | Keyword Research & Scoring (IN) | ASO | Pull volume, difficulty, chance-to-rank for every seed in India for both stores. Score = (Volume × Relevance) / Difficulty. Bucket into Head / Mid-tail / Long-tail. | Ranking for 5 hard head terms is worth less than ranking #1 for 60 mid-tail terms; scoring prevents vanity keyword chasing. | High | ASO | ASO tooling, spreadsheet modelling | 3 days | ₹8,000/mo tool | AppTweak / Sensor Tower / MobileAction | P1-02 | Master Keyword Sheet with scores & buckets | 150 scored keywords; 60 target set locked | Day 4–7 | Not Started |
| P1-04 | Keyword Research — Tier-2 Markets | ASO | Repeat P1-03 for UAE, Singapore, Malaysia, UK (large Indian diaspora, high-value users, low competition). | Diaspora markets convert on the same value prop with 4–8× higher LTV and far less ASO competition. | Medium | ASO | Multi-market ASO | 2 days | Internal | AppTweak | P1-03 | Per-market keyword sheets (4 markets) | 4 market sheets; 25 keywords each | Day 8–10 | Not Started |
| P1-05 | Keyword Gap Analysis vs Competitors | ASO | Map keywords where Splitwise/Tricount/Settle Up rank top-10 and KharchaSplit does not rank at all. Flag "winnable gaps" (difficulty <35). | Gaps are the fastest ranking wins — demand already proven, competitor already validated the term. | High | ASO | Competitive ASO | 2 days | Internal | AppTweak Keyword Gap | P1-03, P15-01 | Gap report with 40 winnable keywords | 40 gaps identified, 15 targeted in metadata | Day 8–10 | Not Started |
| P1-06 | Keyword Ranking Tracker Setup | ASO | Configure daily rank tracking for 150 keywords × 2 stores × 5 markets, with weekly automated email report. | ASO is iterative; without daily rank data you cannot attribute a metadata change to a ranking move. | High | ASO | Tool config | 4 hrs | Included in tool | AppTweak, Google Sheets | P1-03 | Live rank dashboard + weekly report | Tracker live; report auto-sends Mondays | Day 7 | Not Started |

### 1.2 Competitor Analysis (ASO Layer)

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P1-07 | Competitor Metadata Teardown | ASO | Line-by-line teardown of title, subtitle, description, keyword field, and update cadence for 8 competitors. Log every metadata change they make weekly. | Competitor metadata is a free, continuously-updated research feed on what converts in your category. | High | ASO | Competitive analysis | 2 days | Internal | AppTweak, Sensor Tower | — | Competitor Metadata Matrix (living sheet) | 8 competitors tracked; weekly diff logged | Day 3–5 | Not Started |
| P1-08 | Competitor Creative Teardown | ASO | Analyse competitor screenshots, captions, video, icon. Identify visual patterns, messaging hierarchy, and what they A/B test. | Prevents designing screenshots in a vacuum; reveals category conversion conventions and where to deliberately break them. | High | ASO + GD | Visual analysis | 2 days | Internal | Figma, AppTweak Creative Gallery | — | Creative teardown board (Figma) | 8 teardowns; 10 pattern insights | Day 3–5 | Not Started |
| P1-09 | Competitor Review Mining | ASO + Product | Scrape 3,000+ competitor reviews; NLP-cluster complaints and praise. Produce "hate list" (their weaknesses = our positioning) and "love list" (table stakes). | Competitor 1-star reviews are the highest-signal source of positioning copy your audience already wrote for you. | High | ASO + DA | Data analysis, sentiment analysis | 3 days | ₹5,000 | Appbot / Python + Play scraper, ChatGPT | — | Review Insight Report + copy angle list | 3,000 reviews analysed; 12 positioning angles | Day 5–8 | Not Started |

### 1.3 Metadata Optimization

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P1-10 | App Title Optimization (Play, 30 chars) | ASO | Rewrite title to `KharchaSplit: Split Expenses` style — brand + highest-value keyword. Test 3 variants. | Title carries the heaviest keyword weight in Play's algorithm and is the first thing 100% of impressions see. | High | ASO + CW | Copywriting, ASO | 1 day | Internal | Play Console | P1-03 | 3 title variants + rationale doc | Chosen title live; keyword rank +10 positions in 21 days | Day 8 | Not Started |
| P1-11 | App Title Optimization (iOS, 30 chars) | ASO | Same for App Store, respecting iOS's separate title+subtitle+keyword-field indexing model. | iOS indexes title, subtitle and keyword field independently — duplicating words across them wastes character budget. | High | ASO + CW | iOS ASO | 1 day | Internal | App Store Connect | P1-03 | iOS title variants | Title live; iOS rank lift measured | Day 8 | Not Started |
| P1-12 | iOS Subtitle Optimization (30 chars) | ASO | Craft subtitle covering secondary keyword cluster ("Bill Split & Money Manager") without repeating title words. | Subtitle is a full second keyword field on iOS and appears in search results — doubles indexed surface. | High | ASO + CW | iOS ASO, copywriting | 4 hrs | Internal | ASC | P1-11 | 3 subtitle variants | Live; +8 keywords entering top-50 | Day 9 | Not Started |
| P1-13 | iOS Keyword Field Optimization (100 chars) | ASO | Pack 100 chars with comma-separated, non-duplicated, no-space keywords. Include misspellings and Hinglish terms. | The single densest ranking lever on iOS; wasted characters here are pure lost visibility. | High | ASO | iOS ASO | 4 hrs | Internal | ASC, AppTweak | P1-03 | Keyword string v1 | 100/100 chars used; +15 keywords ranked | Day 9 | Not Started |
| P1-14 | Play Short Description (80 chars) | ASO | Benefit-led hook that doubles as a keyword carrier — shown above the fold on Play listing. | It's the highest-read text on the Play listing and a confirmed ranking factor; small change, big CVR delta. | High | ASO + CW | Conversion copywriting | 4 hrs | Internal | Play Console | P1-03 | 3 short description variants | +3–5% listing CVR in A/B test | Day 9 | Not Started |
| P1-15 | Play Long Description (4000 chars) | ASO | Rewrite with keyword density 2–3%, scannable structure, emoji bullets, social proof, feature list, FAQ block, CTA. | Play indexes the full description; also the main persuasion surface for the ~15% who expand it. | High | CW + ASO | SEO copywriting | 2 days | ₹6,000 | Play Console, Grammarly | P1-03, P1-09 | Final long description + 2 variants | Keyword coverage 60/60 targets; CVR +2% | Day 10–11 | Not Started |
| P1-16 | iOS Description & Promo Text | ASO | Write iOS description (not indexed — pure persuasion) + 170-char Promotional Text updated monthly for campaigns/seasonality. | Promo text is the only iOS field editable without app review — your monthly campaign megaphone. | High | CW | Copywriting | 1 day | Internal | ASC | P1-11 | iOS description + 12-month promo text calendar | Promo text updated monthly without fail | Day 10–11 | Not Started |
| P1-17 | Metadata Localization — 6 Languages | ASO | Localize title, subtitle, description, keywords into Hindi, Marathi, Tamil, Telugu, Bengali, Gujarati. Transcreate, do not translate. | 70%+ of India's next 300M internet users are vernacular-first; localized listings routinely lift CVR 15–25% in-market. | High | ASO + Vendor | Native language copywriting | 5 days | ₹36,000 (₹6k/lang) | Play Console, ASC, native translators | P1-15, P1-16 | 6 localized metadata sets | 6 locales live; regional CVR +15% | Day 25–32 | Not Started |
| P1-18 | Metadata Localization — 4 Intl Markets | ASO | Localize/adapt for UAE (AR), Singapore, Malaysia, UK (EN variants, local currency/idiom). | Currency and idiom mismatch is the #1 CVR killer in diaspora markets; "₹" in a UAE screenshot kills trust. | Medium | ASO | Multi-market ASO | 2 days | ₹12,000 | ASC, Play Console | P1-04 | 4 international metadata sets | 4 markets live; CVR ≥25% each | Day 45–48 | Not Started |

### 1.4 Creative Assets

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P1-19 | Screenshot Strategy & Storyboard | ASO | Define the 8-screenshot narrative arc: Hook → Core value → Differentiator → Social proof → Trust → CTA. Write caption copy first, design second. | Screenshots drive 60%+ of store conversion decisions; the first 2 (visible without scroll) decide most installs. | High | ASO + GD | Conversion design, storytelling | 2 days | Internal | Figma, Miro | P1-08, P1-09 | Screenshot storyboard + caption copy deck | Storyboard approved; captions <7 words each | Day 11–13 | Not Started |
| P1-20 | Screenshot Design — Play (8 sets) | ASO | Design 8 screenshots in device frames with bold captions, brand colours, real UI. Portrait + tablet variants. | Play's first 3 screenshots appear directly in search results — they are effectively ad creative. | High | GD | Mobile UI design, Figma | 4 days | ₹25,000 | Figma, Previewed/AppLaunchpad | P1-19, P2-05 | 8 Play screenshots (all densities) | Live; Play CVR 22%→28% | Day 13–17 | Not Started |
| P1-21 | Screenshot Design — iOS (6.7", 6.5", 5.5", iPad) | ASO | Same narrative adapted to all required Apple device sizes. | Apple rejects incomplete size sets; wrong-size screenshots render letterboxed and look untrustworthy. | High | GD | iOS design specs | 3 days | ₹18,000 | Figma, ASC | P1-19 | Full iOS screenshot set | Live; iOS CVR 28%→34% | Day 13–17 | Not Started |
| P1-22 | Feature Graphic (Play, 1024×500) | ASO | Design feature graphic used in Play collections, search, and as video poster frame. | Required for featuring consideration by Play editorial; also the thumbnail for your preview video. | High | GD | Graphic design | 1 day | ₹5,000 | Figma | P2-05 | Feature graphic + 2 variants | Live; used in 1 A/B test | Day 14 | Not Started |
| P1-23 | App Icon Redesign & Testing | ASO | Design 4 icon candidates (current + 3). Test via Play Store Listing Experiments and a Poll-the-People style panel. | Icon is the only asset visible in every single impression surface — search, charts, ads, home screen. 5–10% CVR swings are common. | High | GD + ASO | Icon design, brand | 3 days | ₹12,000 | Figma, Play Experiments, PickFu | P2-02 | 4 icon candidates + test results | Winning icon +5% CVR (statistically significant) | Day 15–18 | Not Started |
| P1-24 | App Preview Video — Play (30s) | ASO | Produce a 30-second, sound-off-first preview: problem → app solves it in 3 taps → settle up → CTA. | Listings with video convert 20–35% better; sound-off design is mandatory as most store views are muted. | High | VE + MD | Video editing, motion graphics | 5 days | ₹30,000 | After Effects, Premiere, Rive | P1-19, P2-05 | 30s Play preview video + YouTube upload | Live; CVR +4% vs no-video control | Day 18–23 | Not Started |
| P1-25 | App Preview Videos — iOS (3 × 30s) | ASO | Three iOS previews: Groups, Smart Settle-up, Insights. Must be captured device footage per Apple rules. | Apple allows 3 previews and auto-plays the first — 3× the storytelling real estate competitors usually waste. | High | VE | iOS preview specs | 4 days | ₹22,000 | Final Cut/Premiere, QuickTime device capture | P1-24 | 3 iOS preview videos | Live; iOS CVR +5% | Day 20–25 | Not Started |
| P1-26 | Localized Creative Sets (Hindi + 2) | ASO | Produce screenshot caption + video subtitle variants in Hindi, Marathi, Tamil. | Localized creative outperforms localized text alone by a wide margin — visuals carry the value prop. | Medium | GD + VE | Localization design | 3 days | ₹18,000 | Figma, Premiere | P1-17, P1-20 | 3 localized creative sets | Regional CVR +10% | Day 33–36 | Not Started |

### 1.5 A/B Testing & Ongoing ASO

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P1-27 | A/B Test Roadmap (12 tests) | ASO | Prioritised backlog of 12 store experiments with hypothesis, variant, metric, minimum sample, and expected lift for each. | Random testing wastes traffic; a hypothesis-ranked roadmap ensures each test window (you only get ~2/month) is spent on the biggest lever. | High | ASO + DA | Experiment design, statistics | 1 day | Internal | Notion, Play Experiments | P1-20, P1-23 | A/B Test Roadmap sheet | 12 tests queued; 2 running concurrently | Day 19 | Not Started |
| P1-28 | Run Play Store Listing Experiments (continuous) | ASO | Execute 2 experiments/month on icon, screenshots, short description, feature graphic. Only ship statistically significant winners. | Compounding: 8 winning tests at +3% each ≈ +27% cumulative CVR, which multiplies every acquisition channel. | High | ASO | Experimentation, stats | Ongoing 4 hrs/wk | Internal | Play Console Experiments | P1-27 | Monthly experiment results log | ≥2 tests/month; ≥1 winner/month | Day 20 → ongoing | Not Started |
| P1-29 | Run Apple Product Page Optimization Tests | ASO | Use Apple PPO to test up to 3 treatments of icon/screenshots/preview. | Apple PPO is free traffic-split testing with native statistical significance — no reason not to run it permanently. | High | ASO | iOS PPO | 4 hrs setup | Internal | App Store Connect PPO | P1-21 | PPO test live + results | 1 PPO test always running | Day 22 → ongoing | Not Started |
| P1-30 | Custom Product Pages (iOS) — 5 variants | ASO | Build CPPs for: Students, Trips/Travel, Roommates, Couples, Office teams. Each with tailored screenshots + copy, linked from matching ad campaigns. | Matching ad message to a bespoke store page typically lifts paid conversion 20–40% and is the cheapest paid-efficiency win available. | High | ASO + GD | iOS CPP, segmentation | 4 days | ₹25,000 | ASC, Figma | P1-21, P6-14 | 5 live CPPs + campaign mapping | Paid CVR +20% on CPP-linked traffic | Day 40–44 | Not Started |
| P1-31 | Custom Store Listings (Play) — 5 variants | ASO | Play equivalent of CPPs, segmented by keyword group, country, and install-state audience. | Lets one app serve five different "positioning promises" without diluting the main listing. | Medium | ASO | Play custom listings | 3 days | ₹15,000 | Play Console | P1-30 | 5 custom Play listings | Paid CVR +15% | Day 45–48 | Not Started |

### 1.6 Ratings & Reviews Strategy

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P1-32 | In-App Rating Prompt — Smart Trigger | ASO + Product | Implement in-app review API triggered at "happiness moments": after 3rd expense added, after successful settle-up, after receiving money. Never on first launch. | Moving from random prompts to moment-based prompts routinely takes rating from 4.2 → 4.6 and prompt acceptance from 5% → 20%. | High | MOB + PM | Flutter, in_app_review API | 3 days | Internal (₹15,000) | in_app_review pkg, Firebase Remote Config | Firebase events live | Shipped release with smart prompts | Prompt→rating rate ≥15%; avg rating ≥4.5 in 60 days | Day 12–15 | Not Started |
| P1-33 | Negative Feedback Interception | ASO + Product | Pre-prompt: "Enjoying KharchaSplit?" → Yes routes to store, No routes to an in-app feedback form + support. | Diverts unhappy users into a support channel where they can be recovered, instead of into a public 1-star review. | High | MOB + CS | Flutter, UX | 2 days | Internal | Flutter, Freshdesk | P1-32 | Feedback interception flow live | 1-star share drops below 6% | Day 15–17 | Not Started |
| P1-34 | Review Response SLA & Playbook | ASO + Support | Respond to 100% of reviews: <24h for 1–3 star, <72h for 4–5 star. 20 templated-but-personalised response patterns. | Play weighs developer responsiveness; users who get a reply upgrade their rating ~30% of the time when the issue is fixed. | High | CS + ASO | Support writing, empathy | 1 day setup, 1 hr/day | Internal | Play Console, ASC, Appbot | — | Response playbook + SLA dashboard | 100% response rate; ≥25 rating upgrades/mo | Day 10 → ongoing | Not Started |
| P1-35 | Review Sentiment Dashboard | ASO + Data | Auto-tag every review by theme (bugs, feature request, UX, praise) and pipe weekly digest to Product. | Turns the review stream into a free, continuous product research panel and an early bug-detection system. | Medium | DA | Data pipeline, NLP | 2 days | ₹4,000/mo | Appbot / Metabase | P1-34 | Live sentiment dashboard | Weekly digest delivered; <48h bug detection | Day 20–22 | Not Started |
| P1-36 | Rating Recovery Campaign | ASO | Identify users who rated 1–3 star, fix their issue, then personally invite them to re-rate. | A recovered 1-star → 5-star is a 2-point swing; 200 of these visibly move a 4.2 to 4.5. | Medium | CS + CRM | CRM, support | 2 hrs/wk | Internal | Freshdesk, CleverTap | P1-33, P11-01 | Recovery campaign + tracked outcomes | 30% of contacted users re-rate; +0.2 avg rating | Day 30 → ongoing | Not Started |
| P1-37 | Monthly ASO Report & Iteration | ASO | Monthly report: rank movement, CVR, impressions, keyword wins/losses, next month's metadata changes. | ASO decays — competitors move, algorithms shift. A fixed monthly cadence keeps it a program, not a project. | High | ASO | Reporting, analysis | 1 day/mo | Internal | Looker Studio, AppTweak | P1-06 | Monthly ASO report | Report on 1st of month; ≥5 keyword rank gains/mo | Monthly → ongoing | Not Started |

**Phase 1 Exit Criteria:** Play CVR ≥30%, iOS CVR ≥34%, 40 keywords in top-10 (IN), avg rating ≥4.5, 6 locales live, 4 A/B tests completed with ≥2 winners shipped.

---

# PHASE 2 — Branding

**Objective:** Convert KharchaSplit from "an app" into a recognisable, trusted money brand for young India. Brand is what makes CAC fall over time — recognised brands convert 2–3× better on identical ad creative.

**Phase budget:** ₹1,85,000 one-time
**Phase owner:** CMO with Graphic Designer

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P2-01 | Brand Positioning Workshop | Branding | Half-day workshop to lock: category, target segment, enemy, unique mechanism, reason to believe. Output a single positioning statement. | Every downstream asset (ads, ASO, PR, content) inherits this. Ambiguity here multiplies into inconsistency everywhere. | High | CMO + PM | Brand strategy, facilitation | 1 day | ₹25,000 (facilitator) | Miro, Figma | — | Positioning Statement + Brand Strategy doc | Signed off by founders; used in all briefs | Day 1 | Not Started |
| P2-02 | Brand Identity Refresh / Audit | Branding | Audit existing logo, mark, colours, type for distinctiveness, scalability, and fintech-trust signalling. Refresh where needed. | Money apps live or die on perceived trust; an amateur identity suppresses install intent regardless of product quality. | High | GD + CMO | Brand identity design | 5 days | ₹60,000 | Figma, Illustrator | P2-01 | Identity system (logo, mark, lockups) | Identity approved; applied to store + site | Day 2–8 | Not Started |
| P2-03 | Logo Usage Rules | Branding | Define clear-space, min sizes, do/don't, mono & inverse versions, co-branding lockups, app icon safe area. | Prevents the slow visual erosion that happens once 10 people start making assets. | High | GD | Brand systems | 1 day | Internal | Figma | P2-02 | Logo usage spec + asset pack | Zero off-spec logo uses in QA | Day 9 | Not Started |
| P2-04 | Colour Palette System | Branding | Primary, secondary, accent, semantic (positive/owed/settled), neutrals, gradients. Dark-mode pairs. WCAG AA verified. | Money UI encodes meaning in colour (you owe / you're owed). Ad-hoc colour choices create real usability failures. | High | GD | Colour theory, accessibility | 1 day | Internal | Figma, Stark | P2-02 | Colour token sheet (hex/RGB/Flutter constants) | All tokens AA-compliant; adopted in Flutter theme | Day 9 | Not Started |
| P2-05 | Typography System | Branding | Choose display + body type (Indic script support mandatory), define scale, weights, line-heights for app, web, social, print. | Devanagari/Tamil support is non-negotiable for a vernacular India play; retrofitting fonts later breaks every asset. | High | GD | Typography | 1 day | ₹8,000 (licences) | Google Fonts, Fontshare | P2-02 | Type system spec + licensed font files | Type scale live in app + web | Day 9–10 | Not Started |
| P2-06 | Brand Guidelines Document | Branding | Compile a 30–40 page brand book: strategy, identity, colour, type, imagery, iconography, motion, tone, social templates, misuse. | The single artefact that lets you hire freelancers and agencies without quality collapse. | High | GD + CW | Brand systems, writing | 4 days | ₹35,000 | Figma, Notion | P2-02..P2-05 | Brand Guidelines PDF + Figma library | Distributed to 100% of vendors; referenced in every brief | Day 10–14 | Not Started |
| P2-07 | Value Proposition & Messaging House | Branding | Build a messaging house: one core promise, 3 pillars (Effortless splitting / Zero awkwardness / Money clarity), proof points, and 15 approved headlines. | Gives ads, ASO and PR a shared vocabulary so 500 assets sound like one company. | High | CMO + CW | Messaging strategy | 2 days | ₹15,000 | Google Docs | P2-01 | Messaging House doc + headline bank | Used in ≥90% of live creative | Day 5–7 | Not Started |
| P2-08 | Brand Voice & Tone Guide | Branding | Define voice (warm, witty, never preachy about money), tone modulation by context (error vs celebration vs reminder), banned words, Hinglish rules. | Money is emotionally charged; wrong tone in a "you owe ₹450" notification reads as harassment and drives uninstalls. | High | CW + CMO | Copy strategy | 2 days | ₹12,000 | Notion | P2-07 | Voice & Tone guide with 40 before/after examples | Applied to all push/email copy | Day 7–9 | Not Started |
| P2-09 | Brand Asset Library (Figma + Drive) | Branding | Central, permissioned library: logos, templates, screenshots, icons, video stings, fonts, presets. | Removes the daily "can you send me the logo" tax and guarantees everyone uses current assets. | Medium | GD | Asset management | 2 days | Internal | Figma, Google Drive | P2-06 | Live asset library with access matrix | 100% of team using library; <5min asset retrieval | Day 15–16 | Not Started |
| P2-10 | Social Media Template Kit | Branding | 25 editable templates: carousel, quote, tip, meme, reel cover, story, announcement, testimonial, comparison. | Lets the SMM ship 30 posts/month without a designer in the loop for every asset. | High | GD | Template design | 3 days | ₹20,000 | Figma, Canva Pro | P2-06 | 25 templates in Figma + Canva | Template reuse ≥80% of posts | Day 16–18 | Not Started |
| P2-11 | Motion & Sound Identity | Branding | Logo animation, transition style, in-app micro-interaction language, and one 2-second audio sting for videos/reels. | Sonic + motion branding makes short-form video instantly recognisable in a scrolling feed. | Medium | MD | Motion design, sound | 4 days | ₹30,000 | After Effects, Rive, Audition | P2-02 | Motion kit + audio sting files | Used in 100% of videos from Day 30 | Day 18–22 | Not Started |
| P2-12 | Brand Awareness Baseline Survey | Branding | Survey 500 target users (colleges, IG, panels) on aided/unaided awareness of KharchaSplit vs Splitwise. | You cannot claim brand growth without a baseline; also reveals what people already think you do. | Medium | GM + DA | Survey design, analysis | 3 days | ₹15,000 | Google Forms, Typeform, panel | P2-01 | Baseline awareness report | 500 responses; baseline % recorded | Day 20–23 | Not Started |
| P2-13 | Trademark & Brand Protection | Branding + Legal | File trademark for name + logo (Class 9, 36, 42). Secure handles on all platforms + defensive domains. | An unprotected brand in fintech is a lawsuit and a rebrand waiting to happen; handle-squatting is common. | High | CMO + Legal | IP basics | 3 days | ₹35,000 | IP attorney, Namecheap | P2-02 | TM applications + handle inventory | TM filed; all key handles secured | Day 10–13 | Not Started |

**Phase 2 Exit Criteria:** Brand book published, all store + web + social surfaces consistent, TM filed, awareness baseline captured.

---

# PHASE 3 — Website & SEO

**Objective:** Build kharchasplit.com into a 250K-sessions/month organic acquisition engine and the highest-converting install surface outside the stores. SEO compounds: a calculator page ranking #1 delivers installs for years at zero marginal CAC.

**Phase budget:** ₹2,60,000 one-time + ₹45,000/month
**Phase owner:** SEO Specialist + Growth Manager

### 3.1 Site Build & Conversion

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P3-01 | Website Strategy & Sitemap | Website | Define site architecture: home, features (6), use-cases (6), blog, tools/calculators, compare pages, pricing, about, help, legal. | Architecture decides crawl equity distribution and which pages can ever rank; retrofitting IA later costs rankings. | High | SEO + GM | IA, SEO strategy | 2 days | Internal | Miro, Screaming Frog | — | Sitemap + URL structure doc | Approved sitemap; ≤3 clicks to any page | Day 1–2 | Not Started |
| P3-02 | Landing Page Design | Website | Design high-converting home page: hero with app mockup, social proof bar, 3 benefits, how-it-works, comparison, testimonials, FAQ, dual store CTA, sticky mobile CTA. | The home page is where every PR mention, influencer link and Google Ad lands — its CVR multiplies every other channel. | High | GD | Web design, CRO | 4 days | ₹40,000 | Figma | P2-06, P3-01 | Home page design (desktop + mobile) | Design approved; ≥3 CTA placements | Day 3–7 | Not Started |
| P3-03 | Landing Page Development | Website | Build in Next.js (or Webflow if no dev bandwidth). Static-generated, image-optimised, <100KB critical CSS. | Speed is both a ranking factor and a CVR factor; a 1s delay costs ~7% conversions. | High | BE/Web Dev | Next.js/Webflow, Tailwind | 5 days | ₹50,000 | Next.js, Vercel/Webflow | P3-02 | Live home page | Live; LCP <2.0s; CVR ≥12% visit→store-click | Day 8–14 | Not Started |
| P3-04 | Smart App Banner + Deferred Deep Linking | Website | Implement iOS Smart App Banner, Android intent links, and Branch/Firebase Dynamic Links so a web visitor lands in the right in-app screen post-install. | Deferred deep linking is the difference between a web visitor becoming an activated user vs. dropping at a generic home screen. | High | BE + MOB | Deep linking, Branch SDK | 3 days | ₹8,000/mo (Branch) | Branch.io / AppsFlyer OneLink | P3-03, P13-03 | Working deep links (web→app, all states) | 100% of web CTAs deep-link; +15% install→registration | Day 15–17 | Not Started |
| P3-05 | Use-Case Landing Pages (6) | Website + SEO | Build pages for: Roommates, Trips, Couples, Office lunch, Weddings, Hostel/College. Each keyword-targeted with unique copy, screenshots and testimonials. | Captures high-intent long-tail search ("how to split rent with roommates") that the home page can never rank for. | High | CW + SEO + GD | SEO copywriting | 6 days | ₹36,000 | Next.js, Figma | P3-03 | 6 live use-case pages | 6 pages live; 3 ranking top-20 in 90 days | Day 18–25 | Not Started |
| P3-06 | Comparison Pages (5) | Website + SEO | "KharchaSplit vs Splitwise / Tricount / Settle Up / Splid / Google Sheets" — honest feature tables, migration guide, pricing. | Comparison queries are bottom-funnel with the highest install intent of any organic traffic. | High | CW + SEO | Competitive copywriting | 4 days | ₹25,000 | Next.js | P15-02 | 5 comparison pages | Rank top-10 for 3 "vs" queries; CVR ≥18% | Day 26–30 | Not Started |
| P3-07 | Free Tools / Calculators (5) | Website + SEO | Build indexable web tools: Split Bill Calculator, Trip Budget Calculator, Rent Split Calculator, Tip Calculator, Group Settle-Up Calculator. Each ends in an app CTA. | Tools are link magnets and rank forever; they also demonstrate the product's value pre-install. | High | Web Dev + SEO | JS, SEO | 8 days | ₹60,000 | Next.js | P3-03 | 5 live calculators | 20K organic sessions/mo by Day 180; 200+ backlinks | Day 30–40 | Not Started |
| P3-08 | Conversion Rate Optimization Program | Website | Continuous CRO: heatmaps, session recordings, funnel analysis, then A/B tests on hero copy, CTA, social proof placement, form length. | Doubling site CVR doubles the return on every SEO, PR and ad rupee already spent. | High | GM + Web Dev | CRO, experimentation | Ongoing 6 hrs/wk | ₹6,000/mo | Microsoft Clarity, PostHog, VWO | P3-03, P3-11 | Monthly CRO report + test log | 2 tests/mo; CVR 12%→20% by Day 180 | Day 20 → ongoing | Not Started |

### 3.2 Technical SEO

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P3-09 | Technical SEO Foundation | SEO | robots.txt, XML sitemaps (pages + blog + tools), canonical tags, hreflang for locales, 301 map, pagination, crawl-budget hygiene. | Technical errors silently cap the ceiling of all content investment — deindexed pages earn nothing regardless of quality. | High | SEO + Web Dev | Technical SEO | 3 days | Internal | Screaming Frog, GSC | P3-03 | Tech SEO checklist signed off | 0 critical crawl errors; 100% pages indexed | Day 14–16 | Not Started |
| P3-10 | Schema Markup Implementation | SEO | Implement JSON-LD: SoftwareApplication (with aggregateRating), Organization, WebSite+SearchAction, FAQPage, BreadcrumbList, Article, HowTo, Product for tools. | Rich results measurably raise CTR from the same ranking position — free traffic without new rankings. | High | SEO + Web Dev | Schema.org, JSON-LD | 2 days | Internal | Schema validator, GSC | P3-09 | Validated schema on all templates | 0 schema errors; rich results on 5 page types | Day 16–18 | Not Started |
| P3-11 | Google Analytics 4 Setup | SEO + Analytics | GA4 property, enhanced measurement, custom events (store_click, tool_used, blog_read_complete), conversions, audiences, BigQuery export. | Without event-level GA4 you cannot tell which content actually drives installs vs. just traffic. | High | DA + SEO | GA4, GTM | 2 days | Free | GA4, GTM, BigQuery | P3-03 | Live GA4 with 12 events + 4 conversions | All events firing; BigQuery export daily | Day 14–15 | Not Started |
| P3-12 | Google Search Console Setup | SEO | Verify both www/non-www + all locale properties, submit sitemaps, configure alerts, connect to Looker Studio. | GSC is the only source of truth for query-level organic data and indexation health. | High | SEO | GSC | 3 hrs | Free | GSC | P3-09 | Verified GSC + connected reporting | Sitemaps submitted; weekly index check | Day 14 | Not Started |
| P3-13 | Core Web Vitals Optimization | SEO | Optimise LCP <2.0s, INP <200ms, CLS <0.1: image formats (AVIF/WebP), font-display, code-splitting, CDN, lazy-loading. | Mobile-first Indian traffic on 4G punishes heavy sites with both bounce and ranking loss. | High | Web Dev | Performance engineering | 4 days | Internal | PageSpeed Insights, Lighthouse CI, Cloudflare | P3-03 | CWV passing on 100% of URLs | All green in CrUX; mobile score ≥90 | Day 19–23 | Not Started |
| P3-14 | Mobile UX & Accessibility Audit | SEO + Website | Audit tap targets, contrast, font sizes, screen-reader labels, form usability on real low-end Android devices. | ~85% of your traffic is mobile on mid-range Android; desktop-tested sites routinely break there. | Medium | Web Dev + GD | Accessibility, mobile UX | 2 days | Internal | Lighthouse, axe, BrowserStack | P3-03 | Audit + fix list, all P0 fixed | Accessibility score ≥95; 0 P0 issues | Day 24–25 | Not Started |
| P3-15 | Internal Linking Architecture | SEO | Define hub-and-spoke: use-case pages as hubs, blog posts as spokes, tools cross-linked. Build automated related-posts logic. | Internal links distribute authority to money pages and are the cheapest ranking lever you fully control. | Medium | SEO | SEO architecture | 2 days | Internal | Screaming Frog, Ahrefs | P3-05, P3-16 | Internal linking map + implementation | Every page ≥3 internal inbound links | Day 35–36 | Not Started |

### 3.3 Content SEO / Blog

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P3-16 | SEO Keyword Research (Web) | SEO | 500-keyword map across 5 clusters: expense splitting, budgeting for students, trip planning money, roommate finance, money habits. Map each to a URL and funnel stage. | Prevents cannibalisation and ensures every article has a defined ranking job before a word is written. | High | SEO | Keyword research | 3 days | ₹15,000/mo tool | Ahrefs / Semrush | P3-01 | Keyword map (500 terms → URLs) | 500 keywords mapped; 60 briefs queued | Day 5–8 | Not Started |
| P3-17 | Content Pillar & Cluster Plan | SEO + Content | Design 5 pillar pages with 8–12 supporting cluster posts each (~60 articles). | Topical authority — Google rewards depth on a subject far more than scattered one-off posts. | High | SEO + CW | Content strategy | 2 days | Internal | Notion, Ahrefs | P3-16 | Pillar-cluster map | 5 pillars, 60 clusters defined | Day 9–10 | Not Started |
| P3-18 | Blog Setup & Templates | Website | Build blog with SEO-optimised article template: TOC, schema, author box, related posts, in-article app CTA, newsletter capture. | The template's CTA and capture points determine whether traffic ever becomes users. | High | Web Dev + GD | Web dev | 3 days | ₹18,000 | Next.js / Ghost | P3-03 | Live blog with template | Blog live; CTA CTR ≥5% | Day 15–18 | Not Started |
| P3-19 | Publish 24 SEO Articles (Q1) | SEO + Content | 2 articles/week for 12 weeks, 1,500–2,500 words, original data/screenshots, expert quotes, internal links. | Volume + consistency is how new domains earn crawl frequency and topical trust in the first 90 days. | High | CW + SEO | SEO writing | Ongoing | ₹2,500/article = ₹60,000 | Surfer SEO, Grammarly, GSC | P3-17, P3-18 | 24 published articles | 24 published; 10K organic sessions/mo by Day 90 | Day 20–90 | Not Started |
| P3-20 | Programmatic SEO Pages | SEO | Generate templated pages at scale: "Split expenses in <city>", "<N>-way bill split calculator", "Trip budget for <destination>". Quality-gated, unique data per page. | Captures thousands of long-tail queries at near-zero marginal cost per page. | Medium | Web Dev + SEO | Programmatic SEO | 5 days | ₹35,000 | Next.js, Airtable/CMS | P3-07, P3-09 | 200+ programmatic pages live | 200 pages indexed; 15K sessions/mo by Day 180 | Day 60–70 | Not Started |
| P3-21 | Backlink Acquisition Campaign | SEO | Digital PR + outreach: HARO/Qwoted, guest posts on finance/student blogs, tool link-building, broken-link building, startup directories. | Domain authority is the gating factor on ranking for competitive money keywords. | High | SEO + PR | Link building, outreach | Ongoing 8 hrs/wk | ₹25,000/mo | Ahrefs, Hunter.io, BuzzStream | P3-07 | Monthly backlink report | 25 referring domains/mo; DR 0→35 by Day 180 | Day 30 → ongoing | Not Started |
| P3-22 | Looker Studio SEO Dashboard | SEO + Analytics | Blend GSC + GA4 + rank tracker into one dashboard: rankings, clicks, impressions, sessions, store clicks, assisted installs. | Makes SEO's contribution to installs visible to leadership, which protects the budget. | Medium | DA + SEO | Looker Studio | 2 days | Free | Looker Studio, GSC, GA4 | P3-11, P3-12 | Live SEO dashboard | Dashboard live; weekly review meeting | Day 25–26 | Not Started |

**Phase 3 Exit Criteria:** Site live with 20+ indexed pages, CWV green, GA4+GSC+schema live, 24 articles published, 15K organic sessions/mo, DR ≥20.

---
# PHASE 4 — Content & Social Media Marketing

**Objective:** Build an owned audience of 250K across platforms and make organic social a top-3 install source. Content is the only channel where the cost per impression falls as you scale — paid does the opposite.

**Phase budget:** ₹1,20,000/month (team + tools + production)
**Phase owner:** Social Media Manager + Content Writer + Video Editor

### 4.1 Foundation

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P4-01 | Social Audit & Channel Prioritisation | Content | Audit existing profiles; score each platform on audience fit × content cost × install intent. Tier: Instagram + YouTube Shorts (Tier 1), LinkedIn + X (Tier 2), Pinterest + Threads + FB (Tier 3). | Spreading thin across 8 platforms equally is the most common growth mistake; tiering concentrates effort where CAC is lowest. | High | SMM + GM | Social strategy | 2 days | Internal | Native analytics, Notion | P2-07 | Channel strategy doc with tiering | Tiering approved; effort split 60/25/15 | Day 1–2 | Not Started |
| P4-02 | Profile Optimization — All 8 Platforms | Content | Optimise handle, name field (keyword), bio, link-in-bio, highlights, banner, pinned post on IG, FB, LinkedIn, X, Threads, Pinterest, YouTube, Snapchat. | Profiles are your social landing pages; an unoptimised bio wastes every viral post's traffic. | High | SMM + GD | Social copywriting, design | 2 days | ₹8,000 | Canva, Linktree/custom | P2-06 | 8 optimised profiles + link-in-bio page | All live; bio→install CVR ≥8% | Day 3–4 | Not Started |
| P4-03 | Content Pillars Definition | Content | Lock 5 pillars: (1) Expense/split education, (2) Personal finance tips for 20s, (3) Product/feature, (4) Relatable money humour/memes, (5) Community & user stories. 40/25/15/15/5 mix. | A fixed pillar ratio prevents the drift into all-product-promo content that kills engagement. | High | CW + SMM | Content strategy | 1 day | Internal | Notion | P2-07 | Content pillar doc + ratio | Pillars used in 100% of calendar entries | Day 3 | Not Started |
| P4-04 | Persona & Voice Adaptation per Platform | Content | Map how brand voice flexes: LinkedIn (founder-led, insight), IG (peer, funny), X (opinionated, fast), YouTube (helpful, calm). | Cross-posting identical copy is why most brand accounts flatline; native voice is the price of reach. | Medium | CW | Copy adaptation | 1 day | Internal | Notion | P2-08 | Platform voice matrix | Applied across calendar | Day 4 | Not Started |
| P4-05 | Content Production System | Content | Set up the assembly line: idea backlog → brief → script → design/shoot → edit → approve → schedule → publish → report. Define SLAs at each stage. | Content dies from process failure, not idea failure. A defined pipeline is what makes 30 posts/month repeatable. | High | SMM + MM | Ops, workflow design | 2 days | ₹3,000/mo | Notion/ClickUp, Buffer/Later | P4-03 | Documented workflow + Notion board | Pipeline live; ≥2 weeks of content always buffered | Day 5–6 | Not Started |
| P4-06 | UGC & Creator Sourcing Pipeline | Content | Recruit 10 student/young-professional UGC creators on retainer for authentic vertical video. | UGC-style creative outperforms polished brand video on both organic reach and paid CTR, at a fraction of the cost. | High | SMM + IM | Creator sourcing | 4 days | ₹40,000/mo (10 × ₹4k) | Instagram, Billo/Insense | P4-05 | 10 signed UGC creators + brief pack | 20 UGC videos/month delivered | Day 10–14 | Not Started |
| P4-07 | Social Listening & Community Monitoring | Content | Monitor mentions of "splitwise alternative", "split bill app", "who owes what" across X, Reddit, Threads, Quora. Respond within 2 hours. | Real-time interception of high-intent conversations converts far better than broadcast content. | High | SMM + CM | Social listening | 1 hr/day | ₹5,000/mo | Brand24 / TweetDeck / F5Bot | — | Daily listening log + response record | ≥20 high-intent replies/week | Day 7 → ongoing | Not Started |

### 4.2 Platform-Specific Execution

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P4-08 | Instagram Growth Engine | Content | 5 reels + 3 carousels + 10 stories weekly. Reels are the growth lever; carousels the save/share lever; stories the conversion lever (polls, link stickers, countdowns). | Instagram is where the 18–30 India segment lives; Reels remain the cheapest organic reach on the internet. | High | SMM + VE + GD | Reels editing, design | Ongoing 20 hrs/wk | Internal + ₹15,000/mo production | CapCut, Canva, Later | P4-05, P4-06 | Weekly IG content pack + monthly report | 0→50K followers in 180 days; 500K reach/mo by Day 90 | Day 8 → ongoing | Not Started |
| P4-09 | YouTube Shorts Engine | Content | Repurpose + native-produce 5 Shorts/week. Hook in first 1.5s, subtitle-first, loopable endings. | YouTube Shorts has the best long-tail (a Short can resurface for months) and feeds the long-form channel. | High | VE + SMM | Short-form editing | Ongoing 8 hrs/wk | Internal | CapCut, YouTube Studio | P5-06 | 60 Shorts in 90 days | 0→25K subs in 180 days; 2M views/quarter | Day 10 → ongoing | Not Started |
| P4-10 | YouTube Long-Form Channel | Content | 1 long-form video/week: tutorials, money guides, app deep-dives, comparisons. SEO-optimised titles/thumbnails/chapters. | YouTube is the world's #2 search engine; "how to split expenses" videos deliver installs for years. | High | VE + CW | YouTube SEO, scripting | Ongoing 12 hrs/wk | ₹20,000/mo | Premiere, TubeBuddy, Photoshop | P5-05 | 12 long-form videos/quarter | 12 videos/quarter; 4,000 watch hours by Day 180 | Day 15 → ongoing | Not Started |
| P4-11 | LinkedIn Founder-Led Growth | Content | Founder posts 4×/week: build-in-public metrics, product decisions, India fintech takes, hiring. Company page reposts. | Founder-led LinkedIn is the cheapest B2B/investor/press/talent channel and drives disproportionate PR pickup. | High | CMO + CW | LinkedIn writing | 4 hrs/wk | Internal | LinkedIn, Taplio | P2-08 | Weekly LinkedIn content pack | Founder 0→15K followers in 180 days; 5 inbound press/mo | Day 8 → ongoing | Not Started |
| P4-12 | X / Twitter Presence | Content | 3 posts/day: product updates, money threads, memes, replies to fintech conversations. Weekly long thread. | X drives PR, Product Hunt momentum and tech-community credibility; also fastest place to catch trends. | Medium | SMM | Short-form writing | 5 hrs/wk | Internal | X, Typefully | P4-04 | Daily X schedule | 0→10K followers in 180 days; 3 threads >50K views | Day 8 → ongoing | Not Started |
| P4-13 | Threads Presence | Content | 2 posts/day, conversational and reply-heavy; cross-pollinate with Instagram audience. | Threads still has outsized organic reach for early consistent accounts and shares IG's graph. | Low | SMM | Conversational writing | 3 hrs/wk | Internal | Threads | P4-02 | Daily Threads schedule | 0→8K followers in 180 days | Day 20 → ongoing | Not Started |
| P4-14 | Facebook Page + Groups Strategy | Content | Page posts 4×/week (older/tier-2 audience skew) + genuine participation in 20 relevant Groups. | Facebook still dominates tier-2/3 India and 30+ users who manage household and travel budgets. | Medium | SMM + CM | FB marketing | 5 hrs/wk | Internal | Meta Business Suite | P4-02 | FB content + group engagement log | 0→20K page followers; 200 group-driven installs/mo | Day 12 → ongoing | Not Started |
| P4-15 | Pinterest SEO Strategy | Content | 10 pins/week: budget templates, money infographics, trip-budget checklists, all linking to blog/tools. | Pinterest is a search engine with multi-year pin half-life and strong "budget/planner" intent. | Low | GD + SMM | Pinterest SEO, design | 4 hrs/wk | Internal | Pinterest, Canva, Tailwind | P3-19 | 120 pins in 90 days | 100K monthly pin impressions by Day 90 | Day 25 → ongoing | Not Started |
| P4-16 | WhatsApp Channel | Content | Launch a WhatsApp Channel for money tips + product updates — the highest-open-rate broadcast surface in India. | Meets Indian users where they already are; 70–90% open rates dwarf email. | High | SMM + CRM | WhatsApp marketing | 2 days setup | Internal | WhatsApp Channels | P4-02 | Live channel + weekly broadcast | 0→25K subscribers in 180 days | Day 20 → ongoing | Not Started |
| P4-17 | Quora & Reddit Answer Programme | Content | Answer 5 high-intent questions/week ("best Splitwise alternative in India", "app to split trip expenses") with genuine, non-spammy value. | These answers rank in Google and deliver compounding, extremely high-intent traffic for years. | High | CM + CW | Community writing | 4 hrs/wk | Internal | Quora, Reddit | P4-07 | 60 answers in 90 days | 60 answers; 3,000 referred sessions/mo by Day 90 | Day 15 → ongoing | Not Started |
| P4-18 | Meme & Trend Jacking Desk | Content | A standing 24-hour capability to turn trending audio/formats/news into on-brand money memes. | Trend participation is the single highest-reach-per-rupee content format; speed is the entire advantage. | Medium | SMM + GD | Meme literacy, fast design | 5 hrs/wk | Internal | CapCut, Canva | P2-10 | 3 trend posts/week | ≥1 post >100K reach per month | Day 15 → ongoing | Not Started |
| P4-19 | Monthly Content Performance Review | Content | Review reach, engagement, saves, shares, profile visits, link clicks, attributed installs by pillar and format. Kill bottom 20%, double the top 20%. | Content without a kill-and-double loop plateaus; this review is what compounds the strategy. | High | SMM + DA | Analytics | 1 day/mo | Internal | Looker Studio, native analytics | P13-07 | Monthly content report | Report by 3rd of month; ≥1 format doubled-down/mo | Monthly | Not Started |

### 4.3 90-Day Content Calendar

**Cadence baseline (weekly):** 5 IG Reels · 3 IG Carousels · 10 IG Stories · 5 YT Shorts · 1 YT Long-form · 4 LinkedIn · 21 X posts · 14 Threads · 4 Facebook · 10 Pins · 1 WhatsApp broadcast · 2 blog posts · 5 Quora/Reddit answers.
**Total per 90 days:** ~65 Reels · 39 Carousels · 130 Stories · 65 Shorts · 13 Long-form videos · 52 LinkedIn posts · 24 blog articles.

#### Month 1 — "Problem Awareness" (Days 1–30)
*Goal: establish the pain (money awkwardness between friends). Not selling yet.*

| Week | Theme | Reels (5/wk) | Carousels (3/wk) | Stories (10/wk) | Shorts (5/wk) | Long-form (1/wk) | LinkedIn (4/wk) | Blog (2/wk) |
|---|---|---|---|---|---|---|---|---|
| W1 | The Awkward Ask | "POV: chasing your friend for ₹500 since March" · "Types of friends on a trip" · "The group chat that never settles" · "3 taps to split a bill" · Trend audio + money caption | Why friends stop being friends over ₹200 · 5 money conversations you're avoiding · The real cost of that Goa trip | Poll: "Do you chase or let go?" · Behind the scenes · Q&A box · App tip · Reshare UGC | Repurpose top 5 reels | "How to split expenses without ruining friendships" | Founder: why we built KharchaSplit · The awkward-money problem in India · Build-in-public metrics · Hiring post | How to split expenses with friends (pillar) · Splitwise alternatives in India 2026 |
| W2 | Trip Money Chaos | Trip receipt chaos · "Who paid for what" skit · Packing-list-but-for-money · Currency/UPI confusion · Trend | Trip budget template · 7 hidden trip costs · How to be the group treasurer without hating it | Trip poll · Sticker Q · Feature tip · Countdown to feature drop · UGC | 5 Shorts | "Trip budget planning: complete guide" | 4 posts (product decision, India travel spend data, founder lesson, user story) | Trip budget calculator guide · Group travel expense checklist |
| W3 | Roommate & Rent | Rent split skit · "That one roommate" · Utility bill drama · Grocery split hack · Trend | Rent split fairness models · Roommate money agreement template · Bills every flatmate forgets | 10 stories | 5 Shorts | "How roommates should split rent & bills" | 4 posts | How to split rent fairly · Roommate expense agreement template |
| W4 | Money Habits in Your 20s | 50-30-20 for Indian salaries · "Where your salary actually goes" · Small leaks skit · Salary-day meme · Trend | Where ₹50K salary really goes · 10 money leaks · First-job money checklist | 10 stories | 5 Shorts | "Budgeting on a ₹30K salary in India" | 4 posts | Budgeting for freshers in India · Expense tracking habits that stick |

#### Month 2 — "Solution & Product" (Days 31–60)
*Goal: connect the pain to KharchaSplit; heavy feature storytelling and UGC.*

| Week | Theme | Reels | Carousels | Stories | Shorts | Long-form | LinkedIn | Blog |
|---|---|---|---|---|---|---|---|---|
| W5 | Feature Spotlight: Groups | Create a group in 15s · Group types demo · "Before vs after KharchaSplit" · UGC testimonial · Trend | How KharchaSplit groups work · 6 group types you should create · Group settings you're missing | Tutorial series · Poll · Feature drop · Q&A | 5 Shorts | "KharchaSplit full app walkthrough" | 4 posts | KharchaSplit vs Splitwise (comparison) · Best expense split app India |
| W6 | Feature Spotlight: Smart Settle-Up | Settle 6 people in 2 taps · UPI settle demo · Debt-simplification explainer · UGC · Trend | How debt simplification works · Settle-up etiquette · Why fewer transactions = fewer fights | 10 stories | 5 Shorts | "How to settle group expenses the smart way" | 4 posts | Debt simplification explained · UPI + expense apps guide |
| W7 | Feature Spotlight: Insights & Reports | Monthly report reveal · Category spending shock · Yearly wrap teaser · UGC · Trend | Read your spending report · 5 insights that change habits · Category benchmarks for Indian 20-somethings | 10 stories | 5 Shorts | "Understanding your spending report" | 4 posts | Expense categories that matter · Monthly money review ritual |
| W8 | Social Proof Month | 3 user story reels · Rating milestone reel · Reaction-to-reviews reel · Trend | User results carousel · 10 reviews we're proud of · Before/after user journeys | 10 stories | 5 Shorts | "Customer stories: 3 groups, 3 problems solved" | 4 posts | Case study: hostel group of 8 · Case study: 12-day Europe trip |

#### Month 3 — "Virality & Scale" (Days 61–90)
*Goal: referral push, seasonal moments, community and creator amplification.*

| Week | Theme | Reels | Carousels | Stories | Shorts | Long-form | LinkedIn | Blog |
|---|---|---|---|---|---|---|---|---|
| W9 | Referral Launch | Referral reward reveal · "Invite 3, get X" · Leaderboard reel · Creator collab · Trend | How the referral program works · Top referrers this week · Reward tiers explained | Referral countdown · Leaderboard · Reward proof · Poll | 5 Shorts | "How to earn rewards by inviting friends" | 4 posts | Referral program explained · Why splitting apps are better with friends |
| W10 | Festival / Seasonal Money | Festival spend skit · Gifting budget · Group gifting hack · Trend · UGC | Festival budget plan · Group gifting split guide · Post-festival money recovery | 10 stories | 5 Shorts | "Festival budgeting guide" | 4 posts | Festival budget planner · Group gifting etiquette |
| W11 | College & Campus Push | Hostel mess bill skit · Campus ambassador call · Student budget reel · Creator collab · Trend | Student budget template · Campus money hacks · Hostel expense splitting guide | 10 stories | 5 Shorts | "Money guide for Indian college students" | 4 posts | Student budgeting India · Hostel expense management |
| W12 | Community & Milestone | Milestone celebration reel · Team reel · User shout-outs · Best-of compilation · Trend | 90-day journey carousel · What we shipped · What's next roadmap | 10 stories | 5 Shorts | "What we built in 90 days + what's next" | 4 posts | Product roadmap post · 90-day growth transparency report |

**Evergreen content bank (build once, reuse):** 30 finance tips, 25 expense management tips, 20 meme templates, 15 explainer scripts, 10 testimonial formats — refreshed quarterly.

---

# PHASE 5 — Video Marketing

**Objective:** Build a video asset library that serves ASO, paid ads, organic social and the website from one production pipeline. Video is the highest-converting format across every one of those surfaces.

**Phase budget:** ₹3,20,000 one-time + ₹65,000/month
**Phase owner:** Video Editor + Motion Designer

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P5-01 | Video Strategy & Asset Map | Video | Map every video asset needed by surface (store, ads, YouTube, IG, website, sales) and design a shoot plan that produces all of them in minimum sessions. | Shooting per-request costs 3–4× more than a mapped production plan; most assets share footage. | High | VE + CMO | Video strategy, production planning | 2 days | Internal | Notion, Frame.io | P2-07 | Video asset map + production schedule | 40+ assets planned from 3 shoot days | Day 1–2 | Not Started |
| P5-02 | Brand Promo Video (60s) | Video | Hero brand film: the problem (money awkwardness), the shift, the product, the payoff. Cinematic, emotional, India-specific. | The anchor asset for website, PR, investor decks, YouTube pre-roll and launch moments. | High | VE + MD | Directing, editing | 10 days | ₹1,20,000 | Premiere, After Effects, crew | P5-01, P2-06 | 60s promo + 30s + 15s cutdowns | Delivered; ≥100K views in 60 days | Day 5–18 | Not Started |
| P5-03 | Feature Videos (6 × 45s) | Video | One per core feature: Groups, Split modes, Settle-up, Reminders, Insights, Multi-currency. Screen-recorded + motion overlays. | Feature videos are the reusable middle-funnel workhorse for ads, store, help centre and onboarding. | High | VE + MD | Screen capture, motion | 8 days | ₹60,000 | Rive, After Effects | P5-01 | 6 feature videos + vertical cuts | 6 delivered; used in ≥3 surfaces each | Day 12–22 | Not Started |
| P5-04 | Product Demo Video (90s) | Video | End-to-end demo: create group → add expenses → split unevenly → settle via UPI → view report. Real device footage, real speed. | The asset that answers "does it actually work?" — critical for high-consideration installs and press. | High | VE | Screen recording, editing | 4 days | ₹30,000 | QuickTime, Premiere | P5-03 | 90s demo + 30s cut | Delivered; on homepage + PH launch | Day 20–24 | Not Started |
| P5-05 | App Walkthrough / Tutorial Series (8 videos) | Video | Long-form how-to series for YouTube: onboarding, groups, split types, settling, reports, recurring expenses, multi-currency, troubleshooting. | Captures YouTube search demand, reduces support load, and improves activation for new users. | High | VE + CW | Tutorial scripting, editing | 10 days | ₹50,000 | Premiere, TubeBuddy | P5-04 | 8 tutorial videos + chapters | 8 published; 50K cumulative views in 90 days | Day 25–40 | Not Started |
| P5-06 | Short-Form Video Factory (30/month) | Video | Standing pipeline producing 30 vertical videos/month from hooks bank + UGC + repurposed long-form. 9:16, subtitle-burned, hook <1.5s. | Volume is the algorithm's price of entry; a factory (not one-off creativity) is how you sustain it. | High | VE + SMM | Fast vertical editing | Ongoing | ₹35,000/mo | CapCut, Descript, Submagic | P4-06 | 30 shorts/month | 30/mo shipped; ≥3 exceed 100K views/mo | Day 15 → ongoing | Not Started |
| P5-07 | Customer Story Videos (6) | Video | Film 6 real users: a hostel group, a Europe trip group, a couple, an office lunch crew, a startup team, a family. | Authentic proof outperforms every claim you can make about yourself; also the best paid-ad creative in the library. | High | VE + IM | Interviewing, documentary editing | 8 days | ₹45,000 | Premiere, crew | P5-01, P8-05 | 6 story videos + vertical cuts | 6 delivered; used in ads; CTR ≥1.8% | Day 40–55 | Not Started |
| P5-08 | Paid Ad Creative Batch (20/month) | Video | Produce 20 ad-specific video variants monthly: hook variations, UGC-style, problem-agitate-solve, testimonial, demo, meme-native. | Creative fatigue is the #1 cause of rising CPI; a 20/month refresh rate is the antidote. | High | VE + PMK | Direct-response video | Ongoing | ₹40,000/mo | CapCut, Meta Ads Library | P6-01 | 20 ad creatives/month | 20/mo; ≥3 winners scaled per month | Day 25 → ongoing | Not Started |
| P5-09 | Motion Graphics & Explainers | Video | Animated explainers for abstract concepts: debt simplification, split modes, privacy/security. | Some product ideas can't be screen-recorded; animation is the only way to make them intuitive. | Medium | MD | After Effects, Rive | 6 days | ₹40,000 | After Effects, Rive | P2-11 | 4 animated explainers | 4 delivered; used in onboarding | Day 45–52 | Not Started |
| P5-10 | Video Localization | Video | Subtitle + voiceover key videos in Hindi, Marathi, Tamil, Telugu. | Vernacular video is where the largest untapped India audience is, and competitors are absent there. | Medium | VE + Vendor | Localization, subtitling | 5 days | ₹35,000 | Submagic, ElevenLabs, VO artists | P5-02, P5-04 | 4 languages × 5 key videos | 20 localized videos; regional watch-time +40% | Day 55–62 | Not Started |
| P5-11 | Video Performance Review Loop | Video | Weekly review of hook retention (first 3s), average view duration, CTR, and install attribution per video. Feed learnings into next batch. | Video without retention analytics is guesswork; the 3-second hook rate is the highest-leverage number in the funnel. | High | VE + DA | Video analytics | 3 hrs/wk | Internal | YouTube Studio, Meta Ads, Looker | P13-07 | Weekly video insight sheet | 3s-retention ≥55%; improving month-on-month | Day 30 → ongoing | Not Started |
| P5-12 | Video Asset Library & Rights Management | Video | Central, tagged library of all footage, b-roll, music licences, model releases and final assets. | Prevents re-shooting what you already own and prevents copyright strikes from unlicensed music. | Medium | VE | Asset management | 2 days | ₹5,000/mo | Frame.io, Google Drive, Epidemic Sound | P5-01 | Tagged library + licence register | 100% assets tagged; 0 copyright claims | Day 30–31 | Not Started |

---
# PHASE 6 — Paid Marketing

**Objective:** Build a profitable, scalable paid acquisition engine at blended CPI ≤ ₹22 and CAC:LTV ≥ 1:3. Paid is the accelerator, not the engine — do not scale it until ASO (Phase 1), attribution (Phase 13) and activation (Phase 12) are fixed, or you will pay full price for users who churn.

**Phase budget:** Media spend per Phase 18 tiers + ₹35,000/month management
**Phase owner:** Performance Marketer, reporting to Growth Manager

### 6.1 Setup & Governance

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P6-01 | Paid Media Strategy & Channel Mix | Paid | Define channel mix, funnel stages, budget split, target CPI/CPR by channel, testing budget ring-fence (20%), and scale rules. | Without pre-agreed scale/kill rules, paid budgets get spent on whatever looked good last week. | High | PMK + GM | Media planning | 3 days | Internal | Google Sheets | P13-01 | Paid media plan + budget model | Plan approved; testing budget ring-fenced | Day 1–3 | Not Started |
| P6-02 | Tracking & Attribution Wiring | Paid | Connect MMP (AppsFlyer/Adjust) to Google Ads, Meta, Apple Search Ads. Configure SKAdNetwork/AdAttributionKit conversion values, Google Ads conversion import, Meta AEM/CAPI, in-app events. | Every rupee spent before attribution is live is unmeasurable and effectively wasted. | High | PMK + MOB | MMP, SKAN, CAPI | 5 days | Included in P13 | AppsFlyer, GA4, Meta Events Manager | P13-01, P13-03 | Attribution QA doc, all channels verified | 100% install + 6 post-install events attributed | Day 3–8 | Not Started |
| P6-03 | Audience & Segment Definition | Paid | Build audience library: interest (travel, students, personal finance), lookalikes (from registrants + active groups), retargeting (website, video viewers, installers-not-registered). | Poor audience hygiene is why most app campaigns overpay; seeded lookalikes from *active* users, not installers, is the key trick. | High | PMK + DA | Audience strategy | 2 days | Internal | Meta Ads Manager, Google Ads | P6-02 | Audience library doc + built audiences | 12 audiences live; LAL seeded on WAG users | Day 8–10 | Not Started |
| P6-04 | Creative Testing Framework | Paid | Standardised naming, 1-variable-at-a-time testing (hook / format / offer / audience), minimum spend per variant, decision thresholds. | Turns creative from opinion into a data pipeline; also makes results readable months later. | High | PMK | Experiment design | 2 days | Internal | Google Sheets, Meta Ads | P6-01 | Testing framework + naming convention | ≥10 creative tests/month; documented winners | Day 8–10 | Not Started |
| P6-05 | Landing / Store Page Matching | Paid | Map each campaign to a matching Custom Product Page (iOS) or Custom Store Listing (Play) or web landing page. | Message-match between ad and destination is typically worth 20–40% conversion lift for zero extra spend. | High | PMK + ASO | CRO | 2 days | Internal | ASC, Play Console | P1-30, P1-31 | Campaign→destination mapping sheet | 100% campaigns mapped; paid CVR +20% | Day 44–45 | Not Started |

### 6.2 Google Ads

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P6-06 | Google App Campaign — Install (tCPI) | Paid | Launch UAC targeting installs, IN, all networks. 5 headlines × 5 descriptions × 20 images × 8 videos per asset group. | UAC is the highest-volume app install source in India and needs asset variety, not bid tinkering, to perform. | High | PMK + VE | UAC, creative ops | 3 days setup | ₹40,000+/mo media | Google Ads | P6-02, P5-08 | Live UAC campaign + asset library | CPI ≤ ₹25; ≥1,500 installs/mo at base budget | Day 10–13 | Not Started |
| P6-07 | Google App Campaign — In-App Action (tCPA) | Paid | Second UAC optimising for `registration_complete` and `first_expense_added`, not raw installs. | Optimising for installs buys cheap junk; optimising for activation buys users who retain. | High | PMK | UAC, event optimisation | 2 days | ₹30,000+/mo media | Google Ads, AppsFlyer | P6-06, P13-04 | Live tCPA campaign | Cost per registration ≤ ₹45; D7 retention ≥ organic − 5pp | Day 20–22 | Not Started |
| P6-08 | Google App Campaign — Re-engagement | Paid | Deep-link campaigns targeting lapsed installers to bring them back to a specific in-app screen. | Reactivating a lapsed user costs a fraction of acquiring a new one and lifts MAU immediately. | Medium | PMK + MOB | Deep links, remarketing | 2 days | ₹15,000+/mo media | Google Ads, Firebase | P3-04, P13-03 | Live re-engagement campaign | Cost per reactivation ≤ ₹18 | Day 45–47 | Not Started |
| P6-09 | Google Search — Brand Defence | Paid | Bid on "KharchaSplit" and misspellings to defend against competitor conquesting. | Competitors bidding on your brand steal your hardest-earned demand at your expense. | High | PMK | Search ads | 1 day | ₹5,000/mo media | Google Ads | P3-03 | Brand campaign live | Brand impression share ≥95%; CPC ≤ ₹4 | Day 12 | Not Started |
| P6-10 | Google Search — Non-Brand & Competitor | Paid | Campaigns on "split expenses app", "splitwise alternative", "bill split app india" + competitor terms, driving to web landing pages. | Captures explicit, bottom-funnel demand — the highest-intent traffic money can buy. | Medium | PMK + SEO | Search ads | 2 days | ₹20,000/mo media | Google Ads | P3-05, P3-06 | Search campaigns live | CPA ≤ ₹60; CVR ≥15% | Day 30–32 | Not Started |
| P6-11 | Google Display & Discovery / Demand Gen | Paid | Demand Gen campaigns across Discover, Gmail, YouTube feeds with lifestyle creative for upper-funnel reach. | Cheap reach that warms audiences and improves the efficiency of all bottom-funnel campaigns. | Low | PMK + GD | Display advertising | 2 days | ₹15,000/mo media | Google Ads | P6-03 | Demand Gen campaign live | CPM ≤ ₹60; view-through installs tracked | Day 50–52 | Not Started |
| P6-12 | YouTube Video Action Campaigns | Paid | Skippable in-stream + in-feed video ads driving installs, using the promo, demo and UGC creative. | YouTube gives storytelling room that static formats can't, and India's YouTube CPMs remain among the world's cheapest. | Medium | PMK + VE | YouTube ads | 2 days | ₹25,000/mo media | Google Ads, YouTube | P5-02, P5-07 | YT campaigns live | CPI ≤ ₹30; view rate ≥25% | Day 40–42 | Not Started |

### 6.3 Meta Ads

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P6-13 | Meta Business Setup & SDK/CAPI | Paid | Business Manager, pixel, App Events via MMP, Aggregated Event Measurement priority order, domain verification. | AEM priority order determines which iOS events you can even see; getting it wrong blinds the account permanently. | High | PMK + MOB | Meta infrastructure | 2 days | Internal | Meta Business Suite | P6-02 | Verified Meta setup + event QA | Events verified; AEM configured | Day 5–7 | Not Started |
| P6-14 | Meta App Install Campaigns (Advantage+) | Paid | Advantage+ App Campaigns optimising for installs then app events. Broad targeting, creative-led. | Meta's algorithm now out-performs manual targeting; the lever is creative volume and event quality. | High | PMK | Meta ads | 3 days | ₹50,000+/mo media | Meta Ads Manager | P6-13, P5-08 | Live AAA campaigns | CPI ≤ ₹20; cost per registration ≤ ₹40 | Day 12–15 | Not Started |
| P6-15 | Instagram Reels-First Creative Campaigns | Paid | Dedicated 9:16 native-feeling ad sets (UGC, meme-native, creator content) placed on Reels + Stories. | Reels inventory is the cheapest quality inventory on Meta, but only native-feeling creative works there. | High | PMK + VE | Reels ads | 2 days | Shared budget | Meta Ads Manager | P4-06, P5-06 | Reels ad sets live | Reels CPI ≤ ₹18; ≥40% of Meta spend | Day 18–20 | Not Started |
| P6-16 | Meta Retargeting & App Event Campaigns | Paid | Retarget website visitors, video viewers, IG engagers, and installed-not-registered users. | The cheapest conversions in any account; a warm audience converts 3–5× better than cold. | High | PMK | Retargeting | 2 days | ₹15,000/mo media | Meta Ads Manager | P6-03 | Retargeting campaigns live | ROAS/CPA 3× better than cold; CPA ≤ ₹20 | Day 25–27 | Not Started |
| P6-17 | Meta Lookalike Scaling | Paid | Build 1%/3%/5% LALs from high-value seeds (users in ≥2 active groups, 30-day retained users). | Seed quality is everything — LALs from active users, not installers, is what separates ₹18 CPI from ₹40. | High | PMK + DA | Audience modelling | 2 days | Shared budget | Meta Ads Manager, MMP | P6-03, P13-05 | LAL audience set live | LAL campaigns beat broad CPI by ≥15% | Day 35–37 | Not Started |
| P6-18 | Meta Creative Refresh Cadence | Paid | Weekly injection of 5 new creatives; pause any ad with frequency >2.5 or 30% CTR decay. | Meta creative fatigue in India hits within 10–14 days; a fixed refresh cadence keeps CPI flat as spend scales. | High | PMK + VE | Creative ops | 3 hrs/wk | Included P5-08 | Meta Ads Manager | P5-08 | Weekly creative refresh log | ≥5 new creatives/week; CPI stable at 2× spend | Day 25 → ongoing | Not Started |

### 6.4 Apple Search Ads & Other Networks

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P6-19 | Apple Search Ads — Brand Campaign | Paid | Exact-match brand terms with high bid to own your own listing against competitor bids. | ASA brand traffic converts at 60%+ TTR and is the cheapest install in any iOS account. | High | PMK | ASA | 1 day | ₹8,000/mo media | Apple Search Ads Advanced | P6-02 | Brand campaign live | TTR ≥55%; CPA ≤ ₹35 | Day 14 | Not Started |
| P6-20 | Apple Search Ads — Generic & Discovery | Paid | Discovery campaign (broad + search match) to mine terms, then graduate winners into exact-match generic campaigns. | The discovery→exact graduation loop is the core ASA growth mechanic and also feeds ASO keyword research. | High | PMK + ASO | ASA structure | 2 days | ₹25,000/mo media | Apple Search Ads | P6-19, P1-03 | Generic + discovery campaigns live | CPA ≤ ₹70; 20 winning terms graduated/mo | Day 16–18 | Not Started |
| P6-21 | Apple Search Ads — Competitor Campaign | Paid | Bid on Splitwise, Tricount, Settle Up brand terms with a comparison-focused Custom Product Page. | Intercepts users at the exact moment they are looking for a competitor — highest-intent iOS traffic available. | Medium | PMK | ASA | 1 day | ₹15,000/mo media | Apple Search Ads | P1-30 | Competitor campaign live | CPA ≤ ₹100; CVR ≥25% | Day 46 | Not Started |
| P6-22 | Alternative Networks Test (Snap/Sharechat/Moj/Josh) | Paid | Ring-fenced tests on regional-first platforms for tier-2/3 India reach at low CPM. | Vernacular platforms deliver very low CPI in tier-2/3 — where competitor spend is near zero. | Low | PMK | Media buying | 3 days | ₹30,000 test | Snap Ads, ShareChat Ads | P6-04 | Test results memo | Test complete; scale if CPI ≤ ₹15 | Day 60–65 | Not Started |
| P6-23 | Weekly Paid Optimisation Ritual | Paid | Fixed Monday routine: budget reallocation, creative pause/scale, bid checks, negative keywords, anomaly review. | Discipline beats cleverness in paid; a weekly ritual prevents slow budget leakage. | High | PMK | Media buying | 4 hrs/wk | Internal | All ad platforms, Looker | P6-06..P6-21 | Weekly optimisation log | Ritual completed 100% of weeks | Day 15 → ongoing | Not Started |
| P6-24 | Incrementality & MMM Check | Paid | Quarterly geo-holdout test: pause paid in matched regions, measure true incremental installs vs attributed. | Attribution over-credits paid; incrementality testing is the only way to know your real CAC. | Medium | DA + PMK | Experiment design, stats | 5 days | ₹20,000 | Geo-holdout, Looker | P13-07 | Incrementality report | Test run quarterly; incrementality ratio published | Day 80–85 | Not Started |

### 6.5 Budget Allocation Model (illustrative at ₹2,50,000/month media)

| Channel | Funnel Stage | Share | Monthly Spend | Target CPI | Expected Installs | Primary KPI |
|---|---|---|---|---|---|---|
| Meta Advantage+ App (IN) | Acquisition | 32% | ₹80,000 | ₹20 | 4,000 | CPI, Cost/Registration |
| Google App Campaign (tCPI) | Acquisition | 24% | ₹60,000 | ₹25 | 2,400 | CPI |
| Google App Campaign (tCPA) | Activation | 12% | ₹30,000 | ₹38 | 790 | Cost per registration |
| Apple Search Ads | Acquisition (iOS) | 12% | ₹30,000 | ₹55 | 545 | CPA, TTR |
| Meta Retargeting | Conversion | 6% | ₹15,000 | ₹14 | 1,070 | CPA, ROAS |
| YouTube Video Action | Awareness→Install | 8% | ₹20,000 | ₹30 | 665 | CPI, View rate |
| Google Search (brand + non-brand) | Intent capture | 4% | ₹10,000 | ₹45 | 220 | CPA |
| Test budget (new networks/creative) | Learning | 2% | ₹5,000 | — | — | Learnings shipped |
| **Total** | | **100%** | **₹2,50,000** | **₹25 blended** | **~9,700** | Blended CPI, CAC:LTV |

### 6.6 Target Audience Definitions

| Segment | Age | Profile | Trigger Moment | Message Angle | Priority Channel |
|---|---|---|---|---|---|
| College students | 18–23 | Hostel, mess bills, group outings, low income | Trip planning, mess bill day | "Stop chasing your friends for ₹200" | IG Reels, Snap, campus |
| Young professionals | 23–30 | Metro, flatshare, office lunches, first salary | Rent day, salary day | "Rent, bills, lunch — split in 3 taps" | Meta, Google, LinkedIn |
| Couples / partners | 24–35 | Shared household expenses | Moving in together | "Shared money, zero arguments" | Meta, IG |
| Travel groups | 20–40 | Frequent group trips | Trip booking | "One trip, one tab, zero confusion" | IG, YouTube, travel creators |
| NRI / diaspora | 25–40 | Multi-currency group spend | Travel, group gifting | "Split across currencies automatically" | ASA, Meta (UAE/SG/UK) |
| Office / team leads | 28–45 | Team lunches, offsites | Team offsite | "Team expenses, settled cleanly" | LinkedIn, Google Search |

---

# PHASE 7 — Influencer Marketing

**Objective:** Generate 40,000+ installs at ≤ ₹18 effective CPI through creator partnerships, and build a permanent library of authentic creative for paid ads. Creator content also gives you social proof that no brand ad can buy.

**Phase budget:** ₹1,50,000–₹4,00,000/month depending on tier (see Phase 18)
**Phase owner:** Influencer Manager

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P7-01 | Influencer Strategy & Tier Model | Influencer | Define 4 tiers: Nano (1–10K), Micro (10–100K), Mid (100–500K), Macro (500K+). Set budget split 40/35/20/5 favouring micro. | Micro creators deliver 3–5× better engagement-to-cost than macro for app installs; a tier model prevents vanity signings. | High | IM + GM | Influencer strategy | 2 days | Internal | Notion, Google Sheets | P2-07 | Influencer strategy doc + tier budget model | Strategy approved; 40% budget on micro | Day 1–2 | Not Started |
| P7-02 | Creator Discovery & Database Build | Influencer | Build a 500-creator database across 5 verticals: personal finance, student life, travel, comedy/relatable, tech reviews. Capture reach, ER, audience geo/age, past brand work, rate estimate. | Discovery is the bottleneck; a pre-built, scored database turns campaign launch from weeks into days. | High | IM | Research, sourcing | 6 days | ₹12,000/mo tool | Modash / Phyllo / Collabstr, IG search, YouTube | P7-01 | Creator database (500 profiles, scored) | 500 creators; 150 shortlisted | Day 3–10 | Not Started |
| P7-03 | Creator Vetting & Fraud Screening | Influencer | Screen for fake followers, engagement pods, audience geography mismatch, brand-safety issues, and past controversy. | India's creator market has significant fraud; unvetted spend routinely delivers 0 installs at full price. | High | IM + DA | Audience auditing | 3 days | Included in tool | Modash, HypeAuditor | P7-02 | Vetted shortlist (150 creators) | ≥85% real-follower score on all signed creators | Day 10–13 | Not Started |
| P7-04 | Outreach Sequence & Templates | Influencer | Build a 4-touch outreach sequence (IG DM → email → follow-up → offer) with personalised templates per vertical. | Response rates in creator outreach are 5–15%; sequencing and personalisation multiply that 3×. | High | IM + CW | Outreach copywriting | 2 days | ₹4,000/mo | Instagram, Gmail, Lemlist, Notion CRM | P7-03 | Outreach sequences + creator CRM | 30% response rate; 60 conversations opened | Day 12–14 | Not Started |
| P7-05 | Rate Card & Negotiation Playbook | Influencer | Benchmark rates by tier and vertical; define what to negotiate (usage rights, exclusivity, deliverable count, performance bonus) and walk-away prices. | Paid-usage rights are worth more than the post itself — you can run winning creator videos as ads for months. | High | IM + CMO | Negotiation | 2 days | Internal | Google Sheets | P7-02 | Rate benchmark sheet + negotiation playbook | Avg rate ≤ benchmark; 100% deals include paid usage rights | Day 12–14 | Not Started |
| P7-06 | Micro-Influencer Campaign — Batch 1 (25 creators) | Influencer | Sign 25 micro creators (10–100K) in finance + student verticals for 1 Reel + 2 Stories each, with unique tracking link and promo code. | The core volume engine — 25 micro creators typically out-deliver 2 macro creators at half the cost. | High | IM | Campaign management | 3 wks | ₹1,25,000 (₹5k avg) | Creator CRM, Branch links | P7-04, P7-05, P8-02 | 25 creator campaigns live | 8,000+ installs; effective CPI ≤ ₹18 | Day 15–35 | Not Started |
| P7-07 | Finance Creator Partnerships (8) | Influencer | Longer-form partnerships with personal-finance creators (YouTube + IG) — integrated segments, not 15-second reads. | Finance creators bring trust transfer, which drives registration and retention rates far above average. | High | IM | Partnership management | 4 wks | ₹1,60,000 (₹20k avg) | YouTube, IG | P7-05 | 8 integrated finance collaborations | 6,000 installs; D7 retention ≥28% | Day 25–55 | Not Started |
| P7-08 | Student / Campus Creator Programme (40) | Influencer | Recruit 40 campus creators across 20 colleges on a performance model (₹40/verified registration + monthly bonus). | Students are your core segment and cheapest creator inventory; performance pricing removes downside risk. | High | IM + CM | Programme management | 4 wks | ₹80,000 | Google Forms, Branch, WhatsApp | P8-02, P9-09 | 40 campus creators onboarded | 10,000 registrations; CPA ≤ ₹40 | Day 20–50 | Not Started |
| P7-09 | Travel Creator Partnerships (10) | Influencer | Partner with travel creators for authentic trip-planning content showing group expense splitting in real use. | Travel is the highest-value use case (large groups, high spend) and the most natural product demo context. | Medium | IM | Partnership management | 3 wks | ₹1,00,000 | IG, YouTube | P7-05 | 10 travel collaborations | 5,000 installs; group creation rate ≥60% | Day 40–65 | Not Started |
| P7-10 | Comedy / Relatable Creator Collabs (10) | Influencer | Sketch-format collabs on the "friend who never pays back" trope — highest shareability. | Humour drives the reach that finance content can't; these become your best paid ad creatives. | Medium | IM + VE | Creative briefing | 3 wks | ₹90,000 | IG, YouTube Shorts | P7-05 | 10 comedy collaborations | 3M+ combined reach; 6,000 installs | Day 45–70 | Not Started |
| P7-11 | Affiliate / Performance Creator Programme | Influencer | Always-on programme: any creator earns ₹35 per verified registration + ₹500 bonus per 50 registrations, self-serve. | Converts creator marketing from a fixed cost into a variable, risk-free CAC channel that scales without headcount. | High | IM + BE | Affiliate ops | 5 days build | ₹15,000 setup + variable | Branch, Tolt/Rewardful, custom dashboard | P8-02, P13-03 | Live affiliate programme + creator dashboard | 100 active affiliates by Day 90; CPA ≤ ₹40 | Day 30–40 | Not Started |
| P7-12 | Creator Brief & Asset Kit | Influencer | Standard brief pack: dos/don'ts, hooks that work, key messages, legal disclosures (ASCI), asset links, tracking link setup. | Bad briefs produce unusable content; a good brief is the difference between a ₹5,000 dud and a ₹5,000 winner. | High | IM + CW | Briefing | 2 days | Internal | Notion, Figma | P2-06 | Creator brief kit | 100% creators briefed; <10% reshoot rate | Day 13–14 | Not Started |
| P7-13 | Influencer Tracking & Attribution | Influencer | Unique Branch/OneLink + promo code per creator; dashboard showing clicks, installs, registrations, retained users, effective CPI. | Without per-creator attribution you cannot renew the winners and cut the losers — which is the entire game. | High | IM + DA | Attribution | 3 days | Included in P13 | Branch, AppsFlyer, Looker Studio | P13-03 | Creator performance dashboard | 100% creators tracked; weekly leaderboard | Day 14–17 | Not Started |
| P7-14 | Whitelisting / Spark Ads Programme | Influencer | Secure paid usage rights and run creator content as ads from their handles (Meta partnership ads). | Creator-handle ads consistently outperform brand-handle ads on CTR and CPI, often by 30–50%. | High | IM + PMK | Paid social, rights management | 2 days | Media budget | Meta Ads Manager | P7-05, P7-06 | Whitelisted ad campaigns live | ≥10 creators whitelisted; CPI 25% below brand ads | Day 40–42 | Not Started |
| P7-15 | Creator Relationship & Renewal Programme | Influencer | Convert top 20% performers into ongoing ambassadors with monthly retainers and early feature access. | Repeat creator content outperforms one-off posts — their audience needs 3+ exposures to convert. | Medium | IM | Relationship management | Ongoing | ₹60,000/mo | Creator CRM | P7-13 | Ambassador roster (10 creators) | 10 ambassadors retained; 40% of installs from repeat creators | Day 60 → ongoing | Not Started |

---

# PHASE 8 — Referral & Viral Growth

**Objective:** Raise K-factor from ~0.1 to 0.8 within 365 days. This is the most important phase in the entire document: expense splitting is inherently multiplayer, so every group created should recruit 2–7 users at zero CAC. If K-factor works, paid marketing becomes optional.

**Phase budget:** ₹1,80,000 build + ₹60,000–₹2,00,000/month in rewards
**Phase owner:** Product Manager + Growth Manager (engineering-heavy phase)

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P8-01 | Viral Loop Audit & K-Factor Baseline | Referral | Map every existing invite surface, measure invites sent per user, invite→install rate, install→registration rate. Calculate current K-factor. | You cannot improve virality you haven't measured; most apps discover their invite flow leaks 70% at a single step. | High | PM + DA | Funnel analysis | 3 days | Internal | Mixpanel, Firebase | P13-04 | Viral loop map + K-factor baseline | Baseline K measured; top 3 leaks identified | Day 1–3 | Not Started |
| P8-02 | Referral Infrastructure Build | Referral | Backend: unique referral codes, deferred deep links, attribution, fraud checks, reward ledger, admin console. | Everything else in this phase depends on this; a fragile referral backend produces disputes and fraud losses. | High | BE + MOB | Backend, Branch SDK | 10 days | ₹80,000 | Branch/AppsFlyer OneLink, Firebase | P3-04, P13-03 | Referral system live in production | System live; 100% referrals attributed; fraud <2% | Day 4–17 | Not Started |
| P8-03 | Invite Flow Redesign (In-App) | Referral | Redesign invite UX: one-tap WhatsApp share, contact picker with pre-filled message, group-invite deep links that show the group preview before signup. | The single biggest lever — a group invite that shows "Rahul added you to Goa Trip, ₹4,200 pending" converts 3–4× better than a generic link. | High | PM + MOB + GD | UX design, Flutter | 8 days | ₹50,000 | Figma, Flutter | P8-02 | New invite flow shipped | Invite→install rate 15%→35% | Day 15–25 | Not Started |
| P8-04 | Reward Structure Design | Referral | Design a two-sided reward: referrer gets ₹50 wallet credit / premium month per verified friend; referee gets ₹30 / 1 month premium. Cap and tier it. | Two-sided rewards outperform one-sided by ~40%; caps and verification protect against reward farming. | High | PM + GM + Finance | Incentive design, unit economics | 3 days | Internal | Google Sheets model | P8-01 | Reward structure + unit economics model | Reward CAC ≤ ₹60; LTV:reward ≥ 4:1 | Day 10–12 | Not Started |
| P8-05 | Referral Programme Launch | Referral | Launch with in-app announcement, push, email, social, and a landing page explaining rewards and tiers. | A referral programme nobody knows about earns nothing; launch is a campaign, not a toggle. | High | GM + CRM + SMM | Campaign management | 5 days | ₹25,000 | CleverTap, Figma, social | P8-02, P8-03, P8-04 | Launch campaign live | 25% of MAU aware; 12% send ≥1 invite in month 1 | Day 26–30 | Not Started |
| P8-06 | Gamification Layer | Referral | Referral milestones (3/10/25/50 friends), progress bar, badges, streaks for expense logging, and an unlock ladder of premium features. | Progress mechanics reliably lift completion of multi-step behaviours like referrals by 30–60%. | High | PM + MOB + GD | Gamification design | 8 days | ₹45,000 | Flutter, Figma, Lottie | P8-05 | Gamification shipped | Avg invites/user 1.2→3.0; milestone completion ≥25% | Day 35–45 | Not Started |
| P8-07 | Referral Leaderboard & Contests | Referral | Monthly public leaderboard + quarterly contest (top 10 referrers win ₹5,000/₹3,000/₹1,000 etc.). | Competition activates the small group of super-referrers who typically drive 40%+ of all referral volume. | Medium | GM + CM | Community management | 4 days | ₹30,000/mo prizes | In-app, Firebase, social | P8-06 | Live leaderboard + monthly contest | Top-100 referrers drive ≥30% of referred installs | Day 45–50 | Not Started |
| P8-08 | Group Virality Optimisation | Referral | Optimise the natural loop: when a user adds a non-user to a group, send them a WhatsApp/SMS with the group context and a deep link straight into the group. | This is organic virality with no reward cost — the highest-margin growth in the product. | High | PM + BE + MOB | Product growth engineering | 6 days | ₹40,000 | Flutter, WhatsApp Business API | P8-02 | Non-user invite flow live | Non-user invite→install ≥40%; K-factor +0.2 | Day 30–38 | Not Started |
| P8-09 | Shareable Moments (Viral Artefacts) | Referral | Auto-generate shareable images: trip expense summary card, "Your month in money", settle-up receipt, year-in-review. Branded, watermark-linked. | Turns normal product usage into organic distribution — users share because it's about them, not you. | High | PM + MOB + GD | Product design, Flutter | 7 days | ₹40,000 | Flutter, Figma | P2-06 | 4 shareable artefacts live | 20% of active users share ≥1/month; 5,000 installs/mo | Day 40–50 | Not Started |
| P8-10 | Referral Fraud Prevention | Referral | Device fingerprinting, phone verification, reward-on-qualified-action (not on install), velocity limits, manual review queue. | Unprotected referral programmes in India get farmed within weeks and can burn an entire quarter's budget. | High | BE + DA | Fraud prevention | 5 days | ₹25,000 | Firebase App Check, MMP fraud tools | P8-02 | Fraud rules live + review dashboard | Fraudulent reward rate <2% | Day 20–25 | Not Started |
| P8-11 | Referral Funnel Optimisation Loop | Referral | Continuous A/B testing of invite copy, reward amount, placement, timing, and channel. | Referral funnels have 5+ steps; each 10% step improvement compounds multiplicatively into K-factor. | High | GM + PM | Experimentation | Ongoing 6 hrs/wk | Internal | Firebase Remote Config, Mixpanel | P8-05 | Monthly referral experiment log | 2 experiments/month; K-factor +0.05/month | Day 50 → ongoing | Not Started |
| P8-12 | Referral Analytics Dashboard | Referral | Dashboard: invites sent, invite CTR, install rate, registration rate, K-factor, viral cycle time, reward cost per acquired user, cohort quality. | Viral cycle time matters as much as K-factor — halving cycle time doubles effective growth rate. | High | DA | Dashboarding | 3 days | Internal | Looker Studio, Mixpanel | P8-02, P13-05 | Live referral dashboard | Dashboard live; reviewed weekly | Day 25–28 | Not Started |

---

# PHASE 9 — Community Marketing

**Objective:** Build a 50,000-strong owned community that lowers CAC, raises retention, generates UGC, and provides a permanent product feedback loop. Communities are slow to build and nearly impossible for competitors to copy.

**Phase budget:** ₹65,000/month
**Phase owner:** Community Manager

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P9-01 | Community Strategy & Platform Selection | Community | Choose primary (WhatsApp + Discord) vs secondary (Reddit, Telegram, FB Groups) platforms; define purpose, rules, moderation and content cadence for each. | Communities fail from unclear purpose more than low numbers; the strategy defines why anyone would stay. | High | CM + GM | Community strategy | 2 days | Internal | Notion | P2-08 | Community strategy doc + rules | Strategy approved; 2 primary platforms chosen | Day 1–2 | Not Started |
| P9-02 | Reddit Presence & Value-First Programme | Community | Participate genuinely in r/india, r/personalfinanceindia, r/IndiaInvestments, r/developersIndia, r/bangalore etc. Answer 10 threads/week; never spam. Do an AMA at Day 60. | Reddit content ranks in Google and Reddit users are highly influential recommenders — but the community punishes overt marketing instantly. | High | CM | Reddit literacy, authentic writing | 5 hrs/wk | Internal | Reddit, F5Bot | P9-01 | Weekly Reddit activity log + AMA | 40 threads/quarter; 2,000 referred sessions/mo | Day 5 → ongoing | Not Started |
| P9-03 | Discord Server Launch | Community | Launch server with channels: announcements, feature-requests, bug-reports, money-tips, trip-planning, campus-ambassadors, off-topic. Onboarding bot + roles. | Discord suits the student/tech segment and gives you a real-time feedback and beta-testing surface. | Medium | CM | Discord admin | 4 days | ₹5,000 | Discord, MEE6 | P9-01 | Live Discord server | 2,000 members by Day 90; 15% weekly active | Day 10–14 | Not Started |
| P9-04 | Telegram Channel + Group | Community | Broadcast channel for updates/tips + a discussion group for power users. | Telegram has deep penetration in Indian student and tech communities and near-100% delivery. | Medium | CM | Telegram admin | 2 days | Internal | Telegram | P9-01 | Live channel + group | 8,000 channel members by Day 90 | Day 12–14 | Not Started |
| P9-05 | WhatsApp Community | Community | WhatsApp Community with topic groups (Students, Travel, Roommates, Beta Testers) — the highest-engagement Indian surface. | WhatsApp is where your users already coordinate group expenses; being present there is native, not intrusive. | High | CM | WhatsApp admin | 3 days | Internal | WhatsApp Communities | P4-16 | Live WhatsApp Community | 10,000 members by Day 90; 40% weekly active | Day 15–18 | Not Started |
| P9-06 | Facebook Groups Strategy | Community | Own a "Smart Money India" group + participate in 20 existing groups (travel, flatmates, city groups, student groups). | Facebook Groups remain the biggest peer-recommendation surface for 25–40 India and tier-2 cities. | Medium | CM | FB group management | 5 hrs/wk | Internal | Facebook | P9-01 | Own group + participation log | Own group 5,000 members; 300 installs/mo from groups | Day 20 → ongoing | Not Started |
| P9-07 | Community Content Calendar | Community | Weekly rhythm: Monday money tip, Wednesday AMA/poll, Friday user spotlight, Sunday challenge. | Predictable rituals are what convert a chat group into a community people return to. | High | CM + CW | Community programming | 2 days | Internal | Notion, Buffer | P9-03, P9-05 | Community calendar (90 days) | Calendar executed ≥90% of weeks | Day 18–20 | Not Started |
| P9-08 | Ambassador / Power User Programme | Community | Recruit 50 power users as ambassadors: early access, swag, direct founder line, feature naming rights, referral bonuses. | Ambassadors generate UGC, moderate, evangelise and give you honest product feedback — at near-zero cost. | High | CM + IM | Programme design | 6 days | ₹35,000/mo (swag + rewards) | Notion, Discord, WhatsApp | P9-03, P8-06 | 50 ambassadors onboarded | 50 active; 20% of UGC from ambassadors | Day 25–35 | Not Started |
| P9-09 | College Campus Programme | Community | Partner with 20 colleges: campus ambassadors, fest sponsorships, hostel activations, orientation-week presence, split-the-bill contests. | Colleges are dense, high-referral-velocity networks — one activated hostel floor can produce 200 users in a week. | High | CM + IM | BD, event management | 6 wks | ₹1,20,000 | Email, WhatsApp, event kits | P7-08 | 20 college partnerships live | 20 campuses; 15,000 student registrations | Day 25–70 | Not Started |
| P9-10 | Startup & Tech Community Presence | Community | Active presence in Indian startup communities: Headstart, TiE, Product Folks, Growth Hackers India, local city meetups. | Generates PR, partnerships, hiring pipeline and early-adopter users who give the best feedback. | Medium | CMO + CM | Networking | 4 hrs/wk | ₹15,000/mo | LinkedIn, Luma, meetups | P2-01 | Monthly community engagement log | 4 events/quarter; 3 partnerships generated | Day 30 → ongoing | Not Started |
| P9-11 | Offline Activations & Events | Community | Split-the-bill activations at cafés, co-living spaces, hostels, and travel meetups. QR-to-install with instant reward. | Offline creates high-intent installs plus content; co-living and café partnerships put you at the exact moment of splitting. | Medium | CM + MM | Event marketing | Ongoing | ₹40,000/mo | Event kits, QR, Branch | P9-09 | 4 activations/month | 4/month; 1,500 installs/month; CPI ≤ ₹25 | Day 45 → ongoing | Not Started |
| P9-12 | Community Health & Reporting | Community | Track member growth, DAU/WAU of community, sentiment, top contributors, feature requests, installs attributed. | Community effort is easy to run without accountability; metrics keep it a growth channel rather than a hobby. | Medium | CM + DA | Analytics | 1 day/mo | Internal | Looker Studio, Discord analytics | P13-07 | Monthly community report | Report monthly; 20% WAU across communities | Monthly | Not Started |

---
# PHASE 10 — PR & Media Relations

**Objective:** Earn 50+ media placements, a Product Hunt top-5 finish, and the domain authority that makes Phase 3's SEO achievable. PR is the cheapest trust you can buy and the fastest way to acquire backlinks that would otherwise take a year.

**Phase budget:** ₹85,000/month (or ₹1,50,000/month with an agency)
**Phase owner:** PR Executive + CMO

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P10-01 | PR Strategy & Story Angles | PR | Develop 8 story angles: founder story, India's ₹X of untracked friend-debt, fintech-for-Gen-Z, Splitwise alternative built for UPI, data reports, funding, milestones, social impact. | Journalists cover stories, not apps; a bank of angles means you always have something newsworthy to pitch. | High | PR + CMO | PR strategy | 3 days | Internal | Notion | P2-07 | PR strategy + 8 angle briefs | 8 angles approved; 2 pitched/month | Day 1–3 | Not Started |
| P10-02 | Press Kit / Media Room | PR | Build kharchasplit.com/press: boilerplate, founder bios + photos, logo pack, screenshots, product video, fact sheet, metrics, media contact. | Removes friction for journalists on deadline; missing assets is a common reason coverage gets cut. | High | PR + GD | PR writing, design | 3 days | ₹15,000 | Next.js, Figma | P2-06, P3-03 | Live press page + downloadable kit | Press page live; ≥50 kit downloads/quarter | Day 4–7 | Not Started |
| P10-03 | Journalist & Media Database | PR | Build a 200-contact database: Indian tech (YourStory, Inc42, ET Tech, Entrackr, Moneycontrol, TechCrunch India), personal finance desks, student media, regional press. | Targeted pitching to 200 relevant journalists beats blasting 2,000 irrelevant ones by an order of magnitude. | High | PR | Media research | 4 days | ₹8,000/mo | Muck Rack / manual + LinkedIn | P10-01 | Media database (200 contacts, beat-tagged) | 200 contacts; 100% beat-matched | Day 5–9 | Not Started |
| P10-04 | Press Release — Milestone/Launch | PR | Write and distribute a launch/milestone release (e.g. "KharchaSplit crosses 100K users; Indians tracked ₹X crore in shared expenses"). | Data-led releases get picked up; feature-led releases get ignored. Distribution also produces syndicated backlinks. | High | PR + CW | PR writing | 3 days | ₹25,000 (distribution) | PRNewswire India / NewsVoir / EIN | P10-02, P10-03 | Press release + distribution report | 15+ pickups; 10 backlinks | Day 12–15 | Not Started |
| P10-05 | Media Outreach Campaign (Monthly) | PR | Personalised pitching: 40 pitches/month, 3-touch follow-up, exclusive offers to tier-1 outlets. | Exclusives to top-tier outlets earn far better placement than blanket releases, and cost nothing. | High | PR | Pitching, relationship building | Ongoing 10 hrs/wk | Internal | Gmail, Muck Rack | P10-03, P10-04 | Monthly outreach + coverage log | 40 pitches/mo; 5 placements/mo | Day 15 → ongoing | Not Started |
| P10-06 | Product Hunt Launch | PR | Full PH launch: hunter outreach, assets, first-comment story, teaser build-up, launch-day mobilisation of community and network. | A top-5 PH finish delivers a durable DR-90 backlink, thousands of high-quality signups, and downstream press. | High | CMO + PR + CM | PH launch strategy | 2 wks prep | ₹20,000 | Product Hunt, Discord/WhatsApp | P5-04, P9-05 | PH launch executed | Top 5 Product of the Day; 2,000+ visits; 500 installs | Day 30–45 | Not Started |
| P10-07 | Startup Directory Submissions (60) | PR + SEO | Submit to 60 directories: BetaList, AlternativeTo, G2, Capterra, Product Hunt, SaaSHub, StartupStash, AppAdvice, Indian startup directories, App-of-the-day sites. | Cheap, permanent backlinks + long-tail referral traffic + "alternative to Splitwise" discovery surfaces. | High | PR + SEO | Link building | 4 days | ₹10,000 | Directory list, Ahrefs | P10-02 | 60 live directory listings | 60 submitted; 40 live; DR +8 | Day 20–25 | Not Started |
| P10-08 | Tech Blog & Niche Publication Outreach | PR + SEO | Guest posts and reviews on personal finance blogs, student blogs, travel blogs, Indian tech blogs. | Niche placements convert better than mass media and give contextual, topically-relevant backlinks. | High | PR + CW | Guest posting | Ongoing 6 hrs/wk | ₹20,000/mo | Ahrefs, Hunter.io | P10-03 | 4 guest posts/month | 4/mo published; 12 referring domains/mo | Day 25 → ongoing | Not Started |
| P10-09 | Founder Thought Leadership | PR | Position the founder as a voice on India's shared-money culture: podcasts, panels, bylined columns, quotes in trend stories. | Founder-led PR compounds — journalists return to sources they've used before, giving you ongoing free coverage. | Medium | CMO + PR | Thought leadership | Ongoing 5 hrs/wk | ₹10,000/mo | LinkedIn, podcast outreach | P4-11 | 2 podcasts + 1 byline/month | 6 podcasts, 3 bylines per quarter | Day 30 → ongoing | Not Started |
| P10-10 | Data-Led PR Reports (Quarterly) | PR + Data | Publish original anonymised-data reports: "India's Friend Debt Report", "How India Splits Trips", "Festival Spending Index". | Original data is the single most reliably covered PR asset and generates dozens of backlinks per report. | High | DA + PR + CW | Data storytelling | 10 days | ₹40,000/quarter | Python, Looker, Figma | P13-05 | Quarterly data report + press push | 1 report/quarter; 20 pickups; 30 backlinks | Day 60–75 | Not Started |
| P10-11 | Awards & Recognition Programme | PR | Apply to relevant awards: Google Play Best of, App Store Awards, ET Startup Awards, YourStory Tech30, Economic Times awards. | Awards are trust signals for users, press, investors and store editorial teams. | Medium | PR | Awards writing | 3 days/quarter | ₹25,000 (entry fees) | Award portals | P10-02 | 8 award applications/year | 8 applications; ≥2 shortlists | Day 50 → quarterly | Not Started |
| P10-12 | Store Featuring Pitch (Apple + Google) | PR + ASO | Formally pitch Apple Editorial and Google Play editorial via nomination forms, highlighting design, India relevance and seasonal hooks. | Store featuring can deliver 50K–500K installs in a week at zero cost — the single highest-ROI PR action available. | High | ASO + PR | Editorial pitching | 3 days | Internal | Apple/Google nomination forms | P1-24, P5-02 | Featuring nominations submitted | Nominated each quarter; ≥1 feature in 365 days | Day 40 → quarterly | Not Started |
| P10-13 | Crisis Communication Playbook | PR | Pre-write response protocols for: data/privacy incident, outage, negative viral post, app store removal, payment dispute. | In fintech, the first two hours of a crisis determine the outcome; improvising costs trust you can't rebuy. | Medium | PR + CMO + Legal | Crisis comms | 2 days | Internal | Notion | P2-08 | Crisis playbook + escalation tree | Playbook approved; 1 tabletop drill run | Day 45–46 | Not Started |
| P10-14 | PR Measurement & Coverage Tracking | PR | Track placements, reach, share of voice vs Splitwise, referral traffic, backlinks earned, brand search lift. | "PR is unmeasurable" is a myth — branded search volume and referring domains prove it directly. | Medium | PR + DA | Media measurement | 1 day/mo | ₹5,000/mo | Google Alerts, Ahrefs, GSC | P3-12 | Monthly PR report | 5 placements/mo; branded search +20% QoQ | Monthly | Not Started |

---

# PHASE 11 — Email & CRM Marketing

**Objective:** Build a lifecycle programme that lifts registration→activation by 20pp and D30 retention by 10pp. Email + WhatsApp is the only owned channel you keep when ad platforms change their rules.

**Phase budget:** ₹25,000/month (tooling) + ₹30,000/month (CRM Executive)
**Phase owner:** CRM Executive

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P11-01 | CRM Platform Setup | Email | Implement CleverTap/MoEngage (or Braze) with user attributes, event streams, segments, and channel orchestration across email, push, in-app, WhatsApp, SMS. | A single orchestration layer prevents the classic failure of 4 disconnected tools messaging the same user 4 times. | High | CRM + MOB + BE | CRM platform, SDK integration | 6 days | ₹18,000/mo | CleverTap / MoEngage | P13-04 | Live CRM with 30 events, 12 attributes | Platform live; events verified | Day 1–8 | Not Started |
| P11-02 | Lifecycle Map & Segmentation | Email | Map the full lifecycle: Install → Register → First group → First expense → First settle-up → Habitual → At-risk → Churned → Winback. Define 15 segments. | Segment-blind messaging is the main cause of unsubscribes; the lifecycle map defines every campaign that follows. | High | CRM + GM | Lifecycle marketing | 3 days | Internal | Miro, CleverTap | P11-01, P8-01 | Lifecycle map + 15 segments | Map approved; segments live in CRM | Day 8–11 | Not Started |
| P11-03 | Email Deliverability Foundation | Email | Configure SPF, DKIM, DMARC, dedicated subdomain, warm-up schedule, list hygiene rules. | Emails that land in spam are worse than no emails — they poison your domain reputation permanently. | High | CRM + BE | Email infrastructure | 2 days | Internal | SendGrid/SES, MXToolbox | P11-01 | Authenticated sending domain | Inbox placement ≥95%; bounce <2% | Day 8–10 | Not Started |
| P11-04 | Welcome Series (5 emails) | Email | Day 0 welcome + value, Day 1 create your first group, Day 3 how splitting works, Day 5 invite friends, Day 7 discover insights. | The first week determines lifetime retention; a structured welcome series is the highest-ROI CRM asset. | High | CRM + CW + GD | Lifecycle copywriting | 4 days | ₹15,000 | CleverTap, Figma | P11-02, P2-08 | 5-email welcome series live | Open ≥45%; activation (first expense) +18pp | Day 12–16 | Not Started |
| P11-05 | Activation Nudge Series | Email + Push | Behaviour-triggered nudges for users stuck at each funnel step (registered-no-group, group-no-expense, expense-no-settle). | Targets the exact drop-off point rather than broadcasting — typically the highest-converting CRM programme. | High | CRM | Behavioural triggers | 4 days | Internal | CleverTap | P11-02 | 6 triggered journeys live | Step-conversion +15pp per stuck segment | Day 16–20 | Not Started |
| P11-06 | Referral Email Campaigns | Email | Referral promotion flow: announce, remind at reward moments, milestone congratulations, leaderboard updates, reward-earned confirmations. | Referral programmes need continuous reminder pressure; one-time announcements decay within days. | High | CRM + CW | Campaign design | 3 days | Internal | CleverTap | P8-05 | 5 referral email flows live | ≥12% of recipients send an invite | Day 30–33 | Not Started |
| P11-07 | Retention & Engagement Campaigns | Email | Weekly digest, feature education drips, seasonal campaigns (trip season, festival, new year), re-engagement for 14/30/60-day inactives. | Retention is where LTV is made; a 5pp D30 improvement is worth more than a 20% CPI reduction. | High | CRM + CW | Retention marketing | 5 days | Internal | CleverTap | P11-02 | 8 retention campaigns live | D30 retention 6%→12%; reactivation ≥8% | Day 20–26 | Not Started |
| P11-08 | Monthly Money Report Email | Email | Personalised monthly report: total spent, split, owed, top categories, biggest group, comparison to last month, share card. | Personalised data emails achieve 2–3× normal open rates and drive both re-engagement and organic sharing. | High | CRM + BE + GD | Dynamic email, data | 6 days | ₹20,000 | CleverTap, backend job | P8-09, P13-05 | Automated monthly report email | Open ≥55%; app-open rate ≥25%; share rate ≥8% | Day 35–42 | Not Started |
| P11-09 | WhatsApp CRM Journeys | Email/CRM | Replicate key journeys on WhatsApp Business API (opt-in based): settle-up reminders, referral nudges, monthly report card. | WhatsApp open rates in India are 70–90% vs email's 25–45%; for reminders it is decisively better. | High | CRM + BE | WhatsApp Business API | 6 days | ₹15,000/mo | Gupshup / WATI / Interakt | P11-01 | 5 WhatsApp journeys live | Opt-in ≥40% of users; open ≥75% | Day 45–52 | Not Started |
| P11-10 | Email Capture & List Growth | Email | Capture emails via website (newsletter, calculator gating), blog CTAs, in-app profile completion, lead magnets (budget templates). | Your list is the only audience you own; growing it is insurance against platform risk. | Medium | CRM + SEO | Lead generation | 3 days | Internal | ConvertKit/Beehiiv, Next.js | P3-18 | Capture points live + lead magnets | 10,000 subscribers by Day 90 | Day 25–28 | Not Started |
| P11-11 | Newsletter — "Money Between Friends" | Email | Weekly newsletter: one money idea, one product tip, one community story. Also republished on LinkedIn and Substack. | Builds brand affinity beyond transactional messaging and creates a distribution channel for content and launches. | Medium | CW + CRM | Newsletter writing | 4 hrs/wk | Internal | Beehiiv / Substack | P11-10 | Weekly newsletter live | 12 issues/quarter; open ≥40%; CTR ≥6% | Day 30 → ongoing | Not Started |
| P11-12 | CRM Experimentation Programme | Email | A/B test subject lines, send times, channel choice, frequency caps, and message tone continuously. | Frequency and timing errors cause opt-outs; systematic testing finds the ceiling without burning the list. | High | CRM + DA | Experimentation | Ongoing 5 hrs/wk | Internal | CleverTap, Mixpanel | P11-04 | Monthly CRM experiment log | 4 tests/month; ≥1 winner/month | Day 30 → ongoing | Not Started |

---

# PHASE 12 — Push Notifications & In-App Messaging

**Objective:** Use push as a retention engine, not a spam cannon. Target 12% average push CTR (vs 3% industry) and 25% of MAU re-engaged weekly by push — while keeping opt-out below 4%.

**Phase budget:** Included in Phase 11 tooling
**Phase owner:** CRM Executive + Product Manager

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P12-01 | Push Infrastructure & Permission Strategy | Push | Implement FCM/APNs via CRM. Replace the cold system permission prompt with a soft in-app pre-prompt shown after the first successful expense split. | Once a user denies push on iOS you may never get them back; a pre-prompt typically lifts opt-in from 40% to 70%. | High | MOB + CRM | Flutter, FCM/APNs | 4 days | Internal | Firebase, CleverTap | P11-01 | Push infra + soft prompt shipped | Push opt-in ≥65% (iOS), ≥90% (Android) | Day 5–9 | Not Started |
| P12-02 | Notification Taxonomy & Frequency Caps | Push | Categorise pushes: Transactional (always), Reminder, Social, Educational, Promotional. Set caps (max 1/day, 4/week promotional) and quiet hours (10pm–8am). | Uncontrolled push volume is the #1 driver of uninstalls; caps protect the channel's long-term value. | High | CRM + PM | Lifecycle strategy | 2 days | Internal | CleverTap | P12-01 | Push taxonomy + cap rules live | Opt-out rate <4%; uninstall rate stable | Day 9–11 | Not Started |
| P12-03 | Notification Preference Centre | Push | In-app settings letting users choose which categories they receive, instead of all-or-nothing. | Granular control converts would-be opt-outs into partial opt-ins, preserving the transactional channel. | Medium | MOB + PM | Flutter, UX | 4 days | ₹20,000 | Flutter, CleverTap | P12-02 | Preference centre shipped | Full opt-out reduced by 40% | Day 30–34 | Not Started |
| P12-04 | Onboarding Push Series (Day 0–7) | Push | 6 pushes across week 1 mapped to onboarding milestones: create group, add expense, invite friend, try split modes, see insights, set reminder. | Week-1 activation is the strongest predictor of D30 retention; push is the cheapest way to drive it. | High | CRM + CW | Lifecycle copywriting | 3 days | Internal | CleverTap | P12-01, P11-02 | Onboarding push journey live | Day-7 activation +20pp; CTR ≥15% | Day 12–15 | Not Started |
| P12-05 | Settle-Up Reminder Engine | Push | Smart reminders to both debtor and creditor: gentle, humorous, escalating politely. Let the creditor trigger a nudge. | This is the app's core job-to-be-done; a well-designed nudge is a product feature users actively want. | High | PM + MOB + CW | Product + copy | 5 days | ₹25,000 | Flutter, CleverTap | P12-02, P2-08 | Reminder engine live | 35% of reminded debts settled within 7 days | Day 18–24 | Not Started |
| P12-06 | Inactive User Re-Engagement | Push | Tiered winback: 7-day (feature nudge), 14-day (pending balance), 30-day (what's new), 60-day (personal report + reward), 90-day (final value push). | Reactivating a lapsed user costs ~1/5 of acquiring a new one; most apps never build this. | High | CRM | Winback campaigns | 4 days | Internal | CleverTap | P12-02 | 5 winback journeys live | 10% of 30-day inactives reactivated/month | Day 24–28 | Not Started |
| P12-07 | Weekly Summary Push | Push | Sunday evening: "Last week you spent ₹X across 3 groups. ₹Y still pending." — personalised, data-led. | Personalised data pushes materially out-perform generic ones and build a weekly habit loop. | High | CRM + BE | Dynamic personalisation | 4 days | Internal | CleverTap, backend | P13-05 | Weekly summary push live | CTR ≥18%; Sunday DAU +25% | Day 28–32 | Not Started |
| P12-08 | Referral Push Campaigns | Push | Referral prompts at high-intent moments: after settling a debt, after a trip group closes, at milestone completion. | Context is everything — a referral ask right after a successful settle-up converts several times better than a random blast. | High | CRM + PM | Trigger design | 2 days | Internal | CleverTap | P8-05 | 4 referral push triggers live | ≥8% of recipients send an invite | Day 32–34 | Not Started |
| P12-09 | Rich Push & In-App Messaging | Push | Implement image/carousel/button pushes and in-app messages (modals, banners, tooltips) for feature discovery and announcements. | In-app messages reach 100% of active users without permission and drive feature adoption far better than push. | Medium | MOB + CRM + GD | Rich push, in-app messaging | 5 days | ₹20,000 | CleverTap, Flutter | P12-01 | Rich push + in-app messaging live | Feature adoption +25% on promoted features | Day 35–40 | Not Started |
| P12-10 | Push Optimisation & Testing Loop | Push | Continuous A/B tests: copy, emoji, personalisation, send-time optimisation (per-user ML timing), deep-link destination. | Send-time optimisation alone commonly lifts CTR 20–30%; the rest compounds on top. | High | CRM + DA | Experimentation | Ongoing 4 hrs/wk | Internal | CleverTap, Mixpanel | P12-04 | Monthly push experiment log | Avg CTR 3%→12%; 4 tests/month | Day 40 → ongoing | Not Started |

---

# PHASE 13 — Analytics & Measurement Infrastructure

**Objective:** Achieve a single source of truth for every growth decision within 30 days. **This phase blocks everything else** — do not spend meaningful media budget until P13-01 through P13-05 are complete.

**Phase budget:** ₹65,000 setup + ₹45,000/month tooling
**Phase owner:** Data Analyst + Mobile Developer

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P13-01 | Measurement Plan & Event Taxonomy | Analytics | Define every event, property, and user attribute to be tracked, with naming conventions (`object_action`), owners, and a tracking spec doc. | Retrofitting analytics after launch means months of unusable historical data; the taxonomy is the foundation. | High | DA + PM | Analytics architecture | 4 days | Internal | Google Sheets, Avo/Amplitude | — | Tracking Plan (60 events, 25 properties) | Plan signed off by Product + Growth | Day 1–4 | Not Started |
| P13-02 | Firebase Analytics Implementation | Analytics | Implement Firebase Analytics in Flutter per the tracking plan: screen views, user properties, conversion events, audiences, debug validation. | Firebase is free, feeds Google Ads optimisation directly, and is the baseline every other tool reconciles against. | High | MOB + DA | Flutter, Firebase | 5 days | Free | Firebase, DebugView | P13-01 | Firebase live with 60 events | 100% of plan events firing; 0 naming violations | Day 5–10 | Not Started |
| P13-03 | MMP Implementation (AppsFlyer or Adjust) | Analytics | Integrate MMP SDK, configure SKAdNetwork/AdAttributionKit conversion values, deep linking (OneLink), fraud protection, and all ad network integrations. | Attribution is the referee between channels; without it, every channel claims the same install. | High | MOB + PMK | MMP integration, SKAN | 6 days | ₹25,000/mo | AppsFlyer / Adjust | P13-01 | MMP live + attribution QA report | All channels attributed; SKAN CV schema live | Day 5–12 | Not Started |
| P13-04 | Mixpanel / Amplitude Product Analytics | Analytics | Implement product analytics for funnels, cohorts, retention curves, path analysis, and feature-level engagement. | Firebase answers "how many"; Mixpanel answers "why" — you need both to fix activation and retention. | High | MOB + DA | Product analytics | 4 days | ₹15,000/mo | Mixpanel / Amplitude | P13-02 | Mixpanel live + 8 saved funnels | Funnels live; weekly retention review running | Day 10–14 | Not Started |
| P13-05 | Data Warehouse & Modelling | Analytics | Pipe Firebase (BigQuery export), MMP, CRM, ad platforms and app database into BigQuery. Build modelled tables: users, cohorts, spend, LTV. | A warehouse is the only way to answer cross-source questions like "what is the D90 LTV of a Meta-acquired student user?" | High | DA + BE | SQL, dbt, BigQuery | 8 days | ₹12,000/mo | BigQuery, dbt, Fivetran/Airbyte | P13-02, P13-03 | Warehouse + 6 modelled tables | Daily pipeline running; <1% data variance | Day 14–24 | Not Started |
| P13-06 | Crashlytics & Performance Monitoring | Analytics | Firebase Crashlytics + Performance Monitoring with alerting to Slack; velocity alerts on crash-free rate. | Crashes are silent CAC destruction — a crash spike wipes out ratings and retention while ads keep spending. | High | MOB | Crashlytics | 2 days | Free | Crashlytics, Slack | P13-02 | Crashlytics live + alerting | Crash-free users ≥99.5%; alerts <15min | Day 5–7 | Not Started |
| P13-07 | Looker Studio Executive Dashboard | Analytics | Build the master dashboard: installs, CPI, registrations, activation, DAU/MAU, retention curves, K-factor, channel ROAS, spend pacing, North Star (WAG). | One dashboard everyone trusts eliminates the weekly ritual of arguing about whose numbers are right. | High | DA | Looker Studio, SQL | 5 days | Free | Looker Studio, BigQuery | P13-05 | Live executive dashboard | Dashboard live; used in weekly growth meeting | Day 24–29 | Not Started |
| P13-08 | Channel-Level Dashboards (5) | Analytics | Sub-dashboards for ASO, Paid, Organic/SEO, Referral, CRM — each with its own KPI set and drill-down. | Channel owners need daily operating views; the exec dashboard is too coarse for optimisation decisions. | Medium | DA | Dashboarding | 4 days | Free | Looker Studio | P13-07 | 5 channel dashboards | All 5 live; owners using daily | Day 29–33 | Not Started |
| P13-09 | Cohort & Retention Analysis Framework | Analytics | Standardised cohort reporting by install week, channel, campaign, and segment — with D1/D7/D30/D90 retention and LTV curves. | Retention by cohort is the only way to know whether growth is real or a leaky bucket refilled by ad spend. | High | DA | Cohort analysis | 3 days | Internal | Mixpanel, BigQuery | P13-05 | Cohort framework + weekly report | Weekly cohort report live | Day 30–33 | Not Started |
| P13-10 | LTV & Unit Economics Model | Analytics | Build a predictive LTV model by channel and segment; derive maximum allowable CAC per channel and payback period. | Sets the bid ceilings that keep paid scaling profitable rather than growth-at-any-cost. | High | DA + Finance | Financial modelling | 5 days | Internal | BigQuery, Sheets | P13-05, P13-09 | LTV model + max-CAC by channel | Model live; used to set paid bids | Day 34–39 | Not Started |
| P13-11 | Alerting & Anomaly Detection | Analytics | Automated Slack alerts on: CPI spike >25%, install drop >20%, crash-free <99%, rating drop, conversion drop, spend overrun. | Catches problems in hours instead of at month-end review, when the money is already gone. | Medium | DA | Monitoring | 3 days | ₹5,000/mo | Looker alerts, Slack, Zapier | P13-07 | 10 live alerts | Alerts live; MTTD <2 hours | Day 40–42 | Not Started |
| P13-12 | Data Governance & Privacy Compliance | Analytics + Legal | DPDP Act (India), GDPR (UK/EU), consent management, data retention policy, ATT prompt, privacy nutrition labels, deletion request flow. | A fintech app mishandling personal data faces regulatory action and store removal — this is existential, not optional. | High | DA + Legal + MOB | Privacy compliance | 6 days | ₹40,000 (legal) | Consent SDK, ASC, Play Data Safety | P13-01 | Compliance doc + consent flow live | 100% compliant; Data Safety forms accurate | Day 15–22 | Not Started |
| P13-13 | Weekly Growth Review Ritual | Analytics | Fixed 60-minute Monday meeting: dashboard review, experiment results, blockers, next week's priorities. Written recap circulated. | The operating cadence that converts data into decisions; without it dashboards go unread. | High | GM + all leads | Facilitation | 1 hr/wk | Internal | Looker, Notion | P13-07 | Weekly recap docs | Held 100% of weeks; decisions logged | Day 30 → ongoing | Not Started |

---

# PHASE 14 — Growth Metrics Framework

**Objective:** A single, shared definition of every metric, its target, its owner, and its review cadence. Ambiguous metric definitions are the most common cause of misaligned growth teams.

| # | Metric | Definition | Formula | Owner | Baseline | Day 90 Target | Day 365 Target | Review Cadence | Source | Action Trigger |
|---|---|---|---|---|---|---|---|---|---|---|
| M-01 | Downloads / Installs | Unique first-time app installs | Count of `first_open` | GM | 5,000 total | 60,000 cumulative | 1,000,000 cumulative | Daily | Firebase / MMP | −20% WoW → investigate |
| M-02 | Registrations | Users completing signup | `registration_complete` | PM | 45% of installs | 62% | 72% | Daily | Mixpanel | <55% → onboarding audit |
| M-03 | Activation Rate | Added first expense within 7 days | Activated / Registered | PM | 38% | 60% | 70% | Weekly | Mixpanel | <50% → activation sprint |
| M-04 | CPI | Cost per install (paid) | Media spend / paid installs | PMK | — | ≤ ₹28 | ≤ ₹16 | Daily | Ad platforms + MMP | +25% → creative refresh |
| M-05 | CAC (blended) | All acquisition cost / new users | (Media + creator + team) / new registered users | GM | — | ≤ ₹65 | ≤ ₹40 | Weekly | Warehouse | > LTV/3 → pause scaling |
| M-06 | LTV (D180 predicted) | Predicted revenue+value per user | Cohort LTV model | DA | — | ₹120 | ₹250 | Monthly | BigQuery model | Falling → retention sprint |
| M-07 | LTV:CAC Ratio | Unit economics health | LTV / CAC | GM/CMO | — | ≥ 2:1 | ≥ 3:1 | Monthly | Warehouse | <2:1 → cut worst channel |
| M-08 | ROAS | Return on ad spend | Attributed value / spend | PMK | — | 1.2× | 2.5× | Weekly | MMP | <1× for 2 wks → restructure |
| M-09 | D1 Retention | % returning next day | Cohort | PM | 32% | 42% | 50% | Weekly | Firebase | <35% → onboarding fix |
| M-10 | D7 Retention | % returning day 7 | Cohort | PM | 14% | 22% | 33% | Weekly | Firebase | <18% → habit-loop work |
| M-11 | D30 Retention | % returning day 30 | Cohort | PM | 6% | 12% | 20% | Monthly | Firebase | <10% → retention sprint |
| M-12 | Churn Rate | % of MAU not returning next month | 1 − (retained MAU / prior MAU) | PM | ~55%/mo | ≤ 40% | ≤ 28% | Monthly | Mixpanel | >45% → winback push |
| M-13 | DAU | Daily active users | Unique daily actives | GM | 250 | 4,500 | 75,000 | Daily | Firebase | Flat 2 wks → engagement review |
| M-14 | MAU | Monthly active users | Unique 30-day actives | GM | 1,200 | 18,000 | 300,000 | Weekly | Firebase | Below plan → channel review |
| M-15 | DAU/MAU (Stickiness) | Habit strength | DAU / MAU | PM | 21% | 25% | 30% | Weekly | Firebase | <20% → notification/habit work |
| M-16 | Session Length | Avg time per session | Total time / sessions | PM | 2m 10s | 3m 00s | 3m 30s | Weekly | Firebase | Falling → UX review |
| M-17 | Sessions per User/Week | Usage frequency | Sessions / WAU | PM | 2.8 | 4.5 | 6.0 | Weekly | Mixpanel | <3 → reminder tuning |
| M-18 | K-Factor | Viral coefficient | Invites/user × invite conversion | GM | 0.10 | 0.35 | 0.80 | Weekly | Referral dashboard | Flat → invite-flow test |
| M-19 | Referral Rate | % of users who invite ≥1 | Inviters / MAU | GM | <5% | 20% | 35% | Weekly | Referral dashboard | <15% → reward review |
| M-20 | Viral Cycle Time | Days from install to first successful referral | Median days | GM | — | ≤ 9 days | ≤ 5 days | Monthly | Warehouse | Rising → prompt earlier |
| M-21 | Store CVR (Play) | Store listing conversion | Installs / store listing views | ASO | 22% | 32% | 40% | Weekly | Play Console | Falling → creative test |
| M-22 | Store CVR (iOS) | Product page conversion | Installs / impressions | ASO | 28% | 34% | 42% | Weekly | ASC | Falling → PPO test |
| M-23 | Organic Share | % installs not paid-attributed | Organic / total installs | GM | 90% | 55% | 70% | Weekly | MMP | <45% → over-reliance on paid |
| M-24 | Avg Rating | Store rating | Weighted avg | ASO | 4.2 / 4.4 | 4.5 | 4.7 | Weekly | Stores | Drop 0.1 → review triage |
| M-25 | Website Organic Sessions | SEO traffic | GA4 organic sessions | SEO | 500/mo | 15,000/mo | 250,000/mo | Weekly | GA4/GSC | Flat → content/link audit |
| M-26 | Web→Install CVR | Site conversion | Store clicks / sessions | GM | — | 12% | 20% | Weekly | GA4 + MMP | <10% → CRO sprint |
| M-27 | Push Opt-in Rate | % granting push | Opted-in / installs | CRM | — | 65% (iOS) | 75% (iOS) | Monthly | CleverTap | <55% → prompt redesign |
| M-28 | Push CTR | Push engagement | Opens / delivered | CRM | 3% | 10% | 12% | Weekly | CleverTap | <6% → copy/timing test |
| M-29 | Email Open / CTR | Email engagement | Opens / CTR | CRM | — | 40% / 6% | 45% / 8% | Weekly | CRM | Falling → list hygiene |
| M-30 | North Star: WAG | Weekly active groups with ≥1 expense | Count | CMO | 180 | 3,500 | 60,000 | Weekly | Warehouse | Below plan → all-hands review |
| M-31 | Crash-Free Users | Stability | Crash-free sessions % | MOB | — | ≥99.5% | ≥99.8% | Daily | Crashlytics | <99% → release freeze |
| M-32 | Support CSAT | Support quality | Satisfied / responses | CS | — | ≥4.5/5 | ≥4.7/5 | Weekly | Freshdesk | <4.2 → process review |

---
# PHASE 15 — Competitor Research & Intelligence

**Objective:** Maintain a live intelligence picture of the category so positioning, ASO and product decisions are made against reality rather than assumption.

**Phase budget:** ₹20,000/month (tools) + ₹35,000 one-time
**Phase owner:** Growth Manager + Data Analyst

### 15.1 Competitor Research Tasks

| # | Task Name | Category | Description | Why Important | Priority | Owner | Skills Required | Est. Time | Est. Cost | Tools | Dependencies | Deliverables | KPI / Success Metric | Timeline | Status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| P15-01 | Competitor Landscape Mapping | Research | Map direct (Splitwise, Tricount, Settle Up, Splid), adjacent (Walnut, Money Manager, Wallet by BudgetBakers, Fold, Jupiter Insights) and substitute (Google Sheets, WhatsApp notes, UPI history) competitors. | Substitutes — not rival apps — are usually your real competition; most users currently "split" in a WhatsApp chat. | High | GM | Market research | 3 days | Internal | App stores, Sensor Tower | — | Competitive landscape map | 12 competitors mapped in 3 tiers | Day 1–3 | Not Started |
| P15-02 | Feature Comparison Matrix | Research | Install and use all 8 competitors for 2 weeks. Build a 60-row feature matrix scoring presence and quality. | Reveals genuine gaps to exploit and table stakes you're missing — the basis for both roadmap and comparison pages. | High | PM + GM | Product analysis | 5 days | ₹5,000 (subs) | Notion, competitor apps | P15-01 | Feature matrix (60 features × 8 apps) | Matrix complete; 10 gaps + 5 table stakes identified | Day 3–8 | Not Started |
| P15-03 | Download & Revenue Estimation | Research | Estimate competitor installs, MAU, revenue, growth rate and market share in India using third-party intelligence. | Sizes the opportunity and sets a realistic ceiling for your own forecasts and investor conversations. | High | DA | Market intelligence | 2 days | ₹20,000/mo | Sensor Tower / data.ai / Appfigures | P15-01 | Market sizing report | Estimates for 8 apps; India TAM sized | Day 5–7 | Not Started |
| P15-04 | Competitor ASO Benchmarking | Research | Benchmark competitor keyword rankings, listing CVR proxies, ratings velocity, update frequency and creative changes. | Feeds Phase 1 directly and reveals when a competitor is investing in growth (update velocity is a strong signal). | High | ASO | ASO analysis | 3 days | Included | AppTweak, Sensor Tower | P1-07 | ASO benchmark report (monthly refresh) | Report monthly; 40 keyword gaps identified | Day 6–9 | Not Started |
| P15-05 | Competitor Marketing Teardown | Research | Analyse their ad creatives (Meta Ad Library, Google Ads Transparency), SEO footprint, social presence, influencer partners, PR coverage and email flows. | Their ad library shows you which creatives they keep running — i.e. which ones work — for free. | High | GM + PMK | Competitive analysis | 4 days | Internal | Meta Ad Library, Ahrefs, Google Ads Transparency | P15-01 | Marketing teardown deck | 8 teardowns; 15 tactics adopted/rejected | Day 9–13 | Not Started |
| P15-06 | Pricing & Monetization Analysis | Research | Compare pricing, paywall placement, free-tier limits, conversion tactics and India-specific pricing across competitors. | Splitwise's aggressive paywall is your single biggest positioning opportunity in India — but only if priced correctly. | High | PM + GM | Pricing strategy | 3 days | Internal | Competitor apps, Sensor Tower | P15-02 | Pricing analysis + recommendation | Pricing recommendation approved | Day 10–13 | Not Started |
| P15-07 | SWOT & Positioning Synthesis | Research | Synthesise everything into a SWOT per competitor and a positioning map (axes: ease-of-use × India-localisation). | Turns raw research into a decision: exactly where KharchaSplit wins and what claim you own. | High | CMO + GM | Strategic synthesis | 2 days | Internal | Miro, Slides | P15-02..P15-06 | SWOT deck + positioning map | Positioning locked; used in Phase 2 | Day 14–15 | Not Started |
| P15-08 | Continuous Competitive Monitoring | Research | Weekly automated monitoring: app updates, new features, price changes, campaign launches, press, review sentiment shifts. | Category dynamics change quarterly; a one-off study is stale within 60 days. | Medium | DA | Monitoring | 2 hrs/wk | Included | Sensor Tower alerts, Google Alerts, Appbot | P15-01 | Weekly competitive digest | Digest sent weekly; 100% delivery | Day 16 → ongoing | Not Started |

### 15.2 Competitor Comparison Snapshot (populate with live data at Day 15)

| Dimension | Splitwise | Tricount | Settle Up | Wallet (BudgetBakers) | Money Manager | **KharchaSplit (Us)** |
|---|---|---|---|---|---|---|
| Primary job | Split expenses with friends | Split group/trip expenses | Split group expenses | Personal finance + budgets | Personal expense tracking | **Split + personal money clarity, India-first** |
| Est. India installs | Very high (category leader) | Medium | Low–medium | Medium | High | Early |
| Avg rating (Play) | ~4.4 | ~4.6 | ~4.4 | ~4.5 | ~4.6 | 4.2 (target 4.7) |
| Monetization | Freemium, aggressive paywall (limits free entries) | Freemium | Freemium | Subscription | Ads + subscription | **Generous free tier, low-priced INR premium** |
| India localisation | Weak (no UPI-native settle, USD-first mindset) | Weak | Weak | Weak | Moderate | **Strong — UPI, INR, Hinglish, vernacular** |
| Settle-up flow | Manual mark-as-paid | Manual | Manual | N/A | N/A | **UPI deep-link settle** |
| Group virality | Moderate | Moderate | Low | Low | Low | **Target: strongest in category** |
| ASO strength | Very strong (brand term dominates) | Strong | Moderate | Strong | Strong | **Weak → Phase 1 priority** |
| Content/SEO | Minimal blog | Minimal | Minimal | Strong blog | Moderate | **Target: category-leading (Phase 3)** |
| Community | Minimal | Minimal | Minimal | Moderate | Minimal | **Target: strongest (Phase 9)** |
| Key strength | Brand = category name | Clean trip UX | Simplicity | Budgeting depth | Feature richness | Speed, India-native, generous free tier |
| Key weakness | Paywall frustration, not India-native | Limited features | Dated UI | Complex | Cluttered UX | Low awareness, small user base |
| **Our opportunity** | Position as *the* India-native, UPI-first, no-paywall-frustration alternative — and win the SEO/content/community ground all of them have ignored | | | | | |

### 15.3 Strategic Opportunities Identified

| # | Opportunity | Evidence | Action | Owner | Phase |
|---|---|---|---|---|---|
| O-1 | Splitwise paywall frustration | Recurring theme in their 1–2 star reviews | Position generous free tier; build "Splitwise alternative" SEO + ASA competitor campaign | CMO | P3-06, P6-21 |
| O-2 | No UPI-native settle-up in any competitor | Feature matrix gap | Make UPI settle-up the hero feature in all creative | PM | P5-03 |
| O-3 | Zero vernacular presence in category | ASO benchmark | Localise into 6 Indian languages ahead of everyone | ASO | P1-17 |
| O-4 | Nobody owns "split expenses" content in India | SERP analysis | Build the content + calculator moat | SEO | P3-07, P3-19 |
| O-5 | No competitor runs a community | Community audit | Own campus + WhatsApp communities | CM | P9-05, P9-09 |
| O-6 | Weak group-invite virality across category | Product teardown | Build best-in-class invite flow | PM | P8-03, P8-08 |

---

# PHASE 16 — Team Structure & Responsibilities

**Objective:** A hiring and RACI plan that scales with budget. Phase 18 tells you which of these roles you can afford at each spend tier.

### 16.1 Role Definitions

| # | Role | Reports To | Core Responsibility | Specific Duties | Owns (Phases) | Key KPIs | Seniority | Monthly Cost (₹) | Hire Priority |
|---|---|---|---|---|---|---|---|---|---|
| R-01 | **Marketing Manager (MM)** | CMO | Runs day-to-day marketing execution and calendar | Campaign planning, brief writing, vendor management, budget tracking, cross-team coordination, monthly reporting | 4, 5, 10 | Campaigns shipped on time, budget variance <5% | Mid–Senior | 70,000–1,10,000 | P1 (Month 1) |
| R-02 | **Growth Manager (GM)** | CMO | Owns the growth model, experiments and funnel metrics | Growth model ownership, experiment roadmap, funnel diagnosis, channel P&L, weekly growth review, North Star accountability | 6, 8, 13, 14 | North Star (WAG), CAC:LTV, experiment velocity | Senior | 1,00,000–1,60,000 | P1 (Month 1) |
| R-03 | **ASO Specialist** | GM | Owns store visibility and conversion on both stores | Keyword research, metadata, creative briefs, A/B tests, localisation, review strategy, store featuring pitches, monthly ASO reporting | 1 | Store CVR, keyword rankings, organic installs | Mid | 45,000–75,000 (or ₹35k/mo freelance) | P1 (Month 1) |
| R-04 | **SEO Specialist** | MM | Owns organic web traffic and site authority | Keyword mapping, technical SEO, content briefs, internal linking, link building, GSC/GA4 monitoring, programmatic SEO | 3 | Organic sessions, rankings, referring domains | Mid | 50,000–80,000 | P2 (Month 2) |
| R-05 | **Performance Marketer (PMK)** | GM | Owns all paid acquisition and its efficiency | Campaign build, bidding, budget pacing, audience strategy, creative testing, attribution QA, daily optimisation, incrementality testing | 6 | CPI, CAC, ROAS, spend pacing | Mid–Senior | 70,000–1,20,000 (or 10–15% of spend, agency) | P1 (Month 1, if spending) |
| R-06 | **Social Media Manager (SMM)** | MM | Owns organic social presence and engagement | Content calendar, publishing, community replies, trend jacking, platform analytics, UGC coordination, social listening | 4 | Reach, engagement rate, follower growth, social-attributed installs | Junior–Mid | 35,000–60,000 | P1 (Month 1) |
| R-07 | **Content Writer (CW)** | MM | Produces all written content | Blog articles, ad copy, ASO copy, email/push copy, scripts, social captions, press releases, landing page copy | 1, 3, 4, 11 | Articles published, organic traffic, copy CTR | Junior–Mid | 35,000–60,000 (or ₹2.5k/article) | P1 (Month 1) |
| R-08 | **Graphic Designer (GD)** | MM | All static visual output | Store screenshots, feature graphics, icons, social creatives, ad statics, website design, brand assets, templates | 1, 2, 3, 4 | Assets delivered on time, creative CTR/CVR | Mid | 45,000–75,000 | P1 (Month 1) |
| R-09 | **Video Editor (VE)** | MM | All video output | Reels, Shorts, YouTube edits, store preview videos, ad creatives, tutorials, subtitle/localisation | 5, 4 | Videos shipped, 3s retention, video ad CPI | Mid | 45,000–75,000 | P1 (Month 1) |
| R-10 | **Motion Designer (MD)** | MM | Animation and motion identity | Logo animation, explainer animations, app UI motion, ad motion graphics, sound/motion branding | 2, 5 | Motion assets delivered, engagement lift | Mid | 50,000–80,000 (or freelance ₹25k/mo) | P3 (Month 3) |
| R-11 | **Influencer Manager (IM)** | MM | Creator partnerships end-to-end | Discovery, vetting, outreach, negotiation, briefing, content approval, tracking, renewals, affiliate programme, whitelisting | 7 | Effective CPI from creators, creators activated | Mid | 45,000–75,000 | P2 (Month 2) |
| R-12 | **PR Executive** | CMO | Earned media and reputation | Story angles, media database, pitching, press releases, Product Hunt, directories, awards, crisis comms, coverage reporting | 10 | Placements, backlinks, share of voice | Mid | 45,000–70,000 (or agency ₹1.5L/mo) | P2 (Month 2) |
| R-13 | **Community Manager (CM)** | MM | Owns all community surfaces | Discord/WhatsApp/Telegram/Reddit/FB, ambassador programme, campus programme, events, moderation, community reporting | 9 | Community size, WAU%, community-attributed installs | Junior–Mid | 35,000–60,000 | P2 (Month 2) |
| R-14 | **CRM / Lifecycle Executive** | GM | Owns retention messaging across channels | Lifecycle journeys, email, push, in-app, WhatsApp campaigns, segmentation, deliverability, CRM experimentation | 11, 12 | Activation rate, D30 retention, push CTR | Mid | 45,000–75,000 | P2 (Month 2) |
| R-15 | **Data Analyst (DA)** | GM | Single source of truth for all numbers | Tracking plan, warehouse, dashboards, cohort/LTV analysis, experiment analysis, competitive data, anomaly alerting | 13, 14, 15 | Data accuracy, dashboard adoption, insight velocity | Mid–Senior | 70,000–1,10,000 | P1 (Month 1) |
| R-16 | **Customer Support (CS)** | PM | User support and review management | Ticket handling, store review responses, feedback triage to product, help centre content, CSAT tracking | 1 | First response time, CSAT, rating recovery | Junior | 25,000–40,000 (×2 by Month 6) | P1 (Month 1) |
| R-17 | **Product Manager (PM)** | Founder | Product decisions that drive growth metrics | Growth roadmap, onboarding/activation, referral product, retention features, experiment specs, analytics requirements | 8, 12, 13 | Activation, retention, K-factor | Senior | 1,20,000–1,80,000 | P1 (Month 1) |
| R-18 | **Mobile Developer (MOB, Flutter)** | PM | Ships growth-critical app changes | SDK integrations, referral flow, deep links, push, in-app messaging, rating prompts, shareable artefacts, A/B infrastructure | 8, 12, 13 | Ship velocity, crash-free rate | Mid–Senior | 90,000–1,50,000 | Existing |
| R-19 | **Backend Developer (BE)** | PM | Server-side growth infrastructure | Referral ledger, fraud checks, WhatsApp/email APIs, personalisation jobs, data pipelines, website/API support | 3, 8, 11, 13 | Uptime, pipeline reliability | Mid–Senior | 90,000–1,50,000 | Existing |
| R-20 | **CMO / Head of Growth** | Founder | Owns the entire plan and its outcomes | Strategy, positioning, budget allocation, hiring, board/investor reporting, PR spokesperson, final creative approval | All | North Star, CAC:LTV, growth vs plan | Leadership | 2,00,000–3,50,000 (or founder-led) | Month 1 |

### 16.2 RACI Summary (by Phase)

| Phase | Responsible | Accountable | Consulted | Informed |
|---|---|---|---|---|
| 1 ASO | ASO, GD, CW | GM | PM, PMK, CS | CMO |
| 2 Branding | GD, CW | CMO | PM, MM | All |
| 3 Website/SEO | SEO, CW, BE, GD | MM | GM, DA | CMO |
| 4 Content | SMM, CW, GD, VE | MM | CM, IM | CMO |
| 5 Video | VE, MD | MM | PMK, SMM | CMO |
| 6 Paid | PMK | GM | DA, VE, ASO | CMO |
| 7 Influencer | IM | MM | PMK, CM | CMO |
| 8 Referral | PM, MOB, BE | GM | DA, CRM, GD | CMO |
| 9 Community | CM | MM | IM, SMM | CMO |
| 10 PR | PR | CMO | SEO, CM | All |
| 11 Email/CRM | CRM, CW | GM | PM, DA | CMO |
| 12 Push | CRM, MOB | PM | GM, CW | CMO |
| 13 Analytics | DA, MOB, BE | GM | PMK, PM | CMO |
| 14 Metrics | DA | GM | All leads | CMO, Founder |
| 15 Competitor | GM, DA | CMO | PM, ASO, PMK | All |

### 16.3 Hiring Sequence

| Month | Hires Added | Cumulative Team Cost/mo (₹) | Rationale |
|---|---|---|---|
| 1 | GM, ASO (freelance), CW, GD, SMM, DA (part-time) | ~2,60,000 | Foundation: measurement + ASO + content engine |
| 2 | PMK, CRM, VE | ~4,50,000 | Turn on paid + retention once measurement is trustworthy |
| 3 | SEO, CM, IM | ~6,00,000 | Scale organic and creator channels |
| 4–6 | PR, MD, CS ×2, MM | ~8,20,000 | Full-stack marketing org |
| 7–12 | +Senior PMK, +CW, +VE, +DA, Regional CM | ~11,50,000 | Scale depth in the channels that proved out |

---

# PHASE 17 — Roadmap

### 17.1 30-Day Plan — "Foundation & Measurement"
**Theme:** Fix the leaks and instrument everything before spending.
**Budget:** ₹1,50,000 (₹40,000 media)
**Target:** 6,000 new installs · 3,800 registrations · MAU 4,000

| Week | Focus | Key Tasks | Milestone |
|---|---|---|---|
| W1 | Instrumentation + audit | P13-01, P13-02, P13-06, P1-01, P1-02, P2-01, P15-01, P3-01, P6-01 | Tracking plan approved; ASO audit delivered; positioning locked |
| W2 | Metadata + brand + MMP | P13-03, P1-03, P1-05, P1-10..P1-16, P2-02, P2-07, P3-11, P3-12, P6-13 | New metadata live on both stores; MMP live |
| W3 | Creative + first paid | P1-19..P1-23, P1-32, P1-34, P5-01, P6-06, P6-09, P6-14, P6-19, P11-01, P12-01 | New screenshots + icon live; first campaigns running |
| W4 | Content engine + website | P1-24, P3-02, P3-03, P4-01..P4-08, P5-02, P11-04, P12-04, P13-07 | Website live; social publishing daily; exec dashboard live |

**Exit criteria:** All tracking verified · New store listings live · Paid running with attribution · Website live · Content publishing daily · Exec dashboard in weekly use.

### 17.2 60-Day Plan — "Activation & Distribution"
**Theme:** Fix activation and retention; turn on creators and community.
**Budget:** ₹3,00,000 (₹1,20,000 media)
**Target:** cumulative 22,000 installs · MAU 9,000 · D7 retention 18%

| Week | Focus | Key Tasks | Milestone |
|---|---|---|---|
| W5 | Referral infrastructure | P8-02, P8-03, P8-04, P8-10, P1-17, P3-05 | Referral system live in production |
| W6 | Creator + community launch | P7-06, P7-08, P9-03, P9-05, P9-09, P10-06 (prep) | 25 micro creators live; communities launched |
| W7 | Retention systems | P11-05, P11-07, P12-05, P12-06, P12-07, P1-28 | Lifecycle + reminder engine live; ASO tests running |
| W8 | Referral launch + PR | P8-05, P10-04, P10-06, P10-07, P3-06, P3-19 | Referral programme launched; Product Hunt executed |

**Exit criteria:** K-factor ≥0.25 · D7 retention ≥18% · 25 creators live · 15 media placements · Push CTR ≥8%.

### 17.3 90-Day Plan — "Scale & Compound"
**Theme:** Scale what works; kill what doesn't; build compounding assets.
**Budget:** ₹5,00,000 (₹2,50,000 media)
**Target:** cumulative 60,000 installs · MAU 18,000 · D7 22% · K-factor 0.35

| Week | Focus | Key Tasks | Milestone |
|---|---|---|---|
| W9 | Gamification + scale paid | P8-06, P8-07, P6-17, P6-18, P7-11 | Gamification shipped; affiliate programme live |
| W10 | Segment pages + CPPs | P1-30, P1-31, P6-05, P6-21, P3-07 | Custom product pages live; calculators shipped |
| W11 | Campus + vernacular push | P9-09, P1-26, P5-10, P7-09, P7-10 | 20 campuses active; localised creative live |
| W12 | Data PR + review + plan Q2 | P10-10, P6-24, P13-09, P13-10, P4-19, quarterly planning | Data report published; Q2 plan approved |

**Exit criteria:** Blended CPI ≤ ₹28 · LTV:CAC ≥ 2:1 · Organic ≥55% of installs · 15K organic web sessions/mo · Rating ≥4.5.

### 17.4 180-Day Plan — "Category Position"
**Budget:** ₹8,00,000/month by Month 6
**Target:** cumulative 200,000 installs · MAU 60,000 · D30 16% · K-factor 0.55

| Month | Focus | Key Initiatives | Milestone |
|---|---|---|---|
| M4 | Vernacular + tier-2 expansion | Full localisation (6 languages), regional creators, ShareChat/Moj tests, regional community managers | 30% of installs from vernacular locales |
| M5 | International diaspora launch | UAE/SG/MY/UK metadata, ASA in those geos, diaspora creators, multi-currency positioning | 4 markets live; 15% of revenue-grade users international |
| M6 | Monetization + LTV | Premium tier launch, paywall optimisation, LTV modelling, ROAS-based bidding, partnership BD (co-living, travel, fintech) | LTV:CAC ≥2.5:1; 3 partnerships signed |

**Exit criteria:** 200K installs · DR ≥35 · 60K organic sessions/mo · 3 partnerships · Store featuring achieved or shortlisted.

### 17.5 365-Day Plan — "Scale to 1M"
**Budget:** ₹12,00,000–₹15,00,000/month by Month 12
**Target:** cumulative 1,000,000 installs · MAU 300,000 · D30 20% · K-factor 0.8

| Quarter | Theme | Key Initiatives | Milestone |
|---|---|---|---|
| Q3 (M7–9) | Compounding organic | 100+ SEO articles, programmatic SEO at scale, YouTube channel to 100K subs, 500-strong ambassador network, quarterly data reports | Organic ≥65% of installs; 150K sessions/mo |
| Q4 (M10–12) | Category leadership | Brand campaign, major PR moment, awards, category-defining data study, offline/OOH test in 2 cities, strategic partnerships (banks, travel, co-living) | 1M installs; unaided brand awareness ≥15% in target segment |

**Annual exit criteria:** 1M installs · 300K MAU · LTV:CAC ≥3:1 · K-factor ≥0.8 · Organic ≥70% · Rating ≥4.7 · Recognised as the India-first alternative in the category.

---

# PHASE 18 — Budget Scenarios

All figures are **monthly**. "Team" assumes a mix of in-house and freelance. Install estimates assume blended CPI improves as ASO, referral and organic mature. Ranges reflect execution quality — the low end is what a mediocre team gets, the high end what a disciplined one gets.

### 18.1 Tier 1 — ₹50,000/month (Bootstrap / Founder-Led)

| Line Item | Allocation (₹) | % | Notes |
|---|---|---|---|
| ASO (freelance specialist) | 8,000 | 16% | Part-time; metadata + creative briefs |
| Creative (design + video freelance) | 10,000 | 20% | Screenshots, 10 reels/month |
| Paid media (Meta only) | 15,000 | 30% | Single Advantage+ campaign, retargeting off |
| Micro-influencers | 8,000 | 16% | 4–5 nano creators (₹1.5–2k each) |
| Tools | 5,000 | 10% | Firebase (free), Canva, CapCut, Buffer, Ahrefs Lite |
| Referral rewards | 4,000 | 8% | Capped programme |
| **Total** | **50,000** | 100% | |

**What you skip:** MMP (use Firebase + Play/ASC organic reporting), paid PR, agency, motion designer, community events.
**Team:** Founder + 1 generalist marketer + freelancers.

| KPI | Monthly Expectation |
|---|---|
| Installs | 1,800–2,500 |
| Paid installs | 600–750 (CPI ~₹22) |
| Organic installs | 1,200–1,750 |
| Registrations | 1,100–1,600 |
| MAU growth | +900–1,300 |
| Blended CAC | ₹20–28 |
| K-factor | 0.15–0.25 |
| **90-day cumulative** | **6,000–8,000 installs** |

### 18.2 Tier 2 — ₹1,00,000/month (Early Traction)

| Line Item | Allocation (₹) | % | Notes |
|---|---|---|---|
| Paid media (Meta + Google UAC) | 35,000 | 35% | Two channels, tCPI then tCPA |
| Creative production | 15,000 | 15% | 20 videos + statics/month |
| Influencers (micro + campus) | 18,000 | 18% | 8–10 micro creators |
| ASO (freelance) | 8,000 | 8% | Ongoing optimisation + tests |
| Content/SEO (freelance writer) | 10,000 | 10% | 6 articles/month |
| Tools & attribution | 8,000 | 8% | Basic MMP tier, CRM starter, Ahrefs |
| Referral rewards | 6,000 | 6% | Two-sided, capped |
| **Total** | **1,00,000** | 100% | |

| KPI | Monthly Expectation |
|---|---|
| Installs | 4,500–6,000 |
| Paid installs | 1,600–1,900 (CPI ~₹20) |
| Organic + referral | 2,900–4,100 |
| Registrations | 2,900–4,000 |
| MAU growth | +2,400–3,300 |
| Blended CAC | ₹18–24 |
| K-factor | 0.25–0.35 |
| **90-day cumulative** | **15,000–20,000 installs** |

### 18.3 Tier 3 — ₹2,50,000/month (Growth Mode) — *Recommended starting tier*

| Line Item | Allocation (₹) | % | Notes |
|---|---|---|---|
| Paid media (Meta, Google, ASA) | 90,000 | 36% | Full channel mix per §6.5 |
| Influencer marketing | 45,000 | 18% | 20 micro + 3 finance creators + campus programme |
| Creative production (video + design) | 35,000 | 14% | 30 videos + 40 statics/month |
| Content & SEO | 30,000 | 12% | 8 articles/month + link building |
| Tools (MMP, CRM, ASO, SEO, listening) | 25,000 | 10% | Full stack |
| Referral & gamification rewards | 15,000 | 6% | Scaled programme + contests |
| PR & community | 10,000 | 4% | Directories, PH, community events |
| **Total** | **2,50,000** | 100% | Team cost separate (~₹4–6L) |

| KPI | Monthly Expectation |
|---|---|
| Installs | 14,000–18,000 |
| Paid installs | 4,000–4,800 (CPI ~₹20) |
| Organic + referral + creator | 10,000–13,200 |
| Registrations | 9,000–12,000 |
| MAU growth | +7,500–10,000 |
| Blended CAC | ₹16–20 |
| K-factor | 0.35–0.50 |
| Organic share | 55–60% |
| **90-day cumulative** | **45,000–60,000 installs** |

### 18.4 Tier 4 — ₹5,00,000/month (Scale Mode)

| Line Item | Allocation (₹) | % | Notes |
|---|---|---|---|
| Paid media (all channels + alt networks) | 1,80,000 | 36% | Adds YouTube, Demand Gen, ShareChat, retargeting at scale |
| Influencer & creator programme | 90,000 | 18% | 40 micro + 8 finance + 10 travel + ambassadors |
| Creative production | 70,000 | 14% | 50 videos/month + full localisation |
| Content, SEO & programmatic | 60,000 | 12% | 16 articles/month, programmatic pages, aggressive link building |
| Tools & data infrastructure | 40,000 | 8% | Full MMP, CRM, warehouse, BI, listening, ASO |
| Referral, gamification & rewards | 35,000 | 7% | Contests, leaderboards, milestone rewards |
| PR, events & community | 25,000 | 5% | Agency retainer or in-house PR + campus events |
| **Total** | **5,00,000** | 100% | Team cost separate (~₹8–11L) |

| KPI | Monthly Expectation |
|---|---|
| Installs | 30,000–40,000 |
| Paid installs | 8,000–10,000 (CPI ~₹18) |
| Organic + referral + creator | 22,000–30,000 |
| Registrations | 20,000–28,000 |
| MAU growth | +17,000–24,000 |
| Blended CAC | ₹13–17 |
| K-factor | 0.55–0.80 |
| Organic share | 65–70% |
| **90-day cumulative** | **95,000–125,000 installs** |

### 18.5 Budget Comparison Summary

| | ₹50K | ₹1L | ₹2.5L | ₹5L |
|---|---|---|---|---|
| Monthly installs | 1.8–2.5K | 4.5–6K | 14–18K | 30–40K |
| Blended CAC | ₹20–28 | ₹18–24 | ₹16–20 | ₹13–17 |
| Cost per registration | ₹31–45 | ₹25–34 | ₹21–28 | ₹18–25 |
| Organic share | 65% | 60% | 58% | 68% |
| K-factor | 0.15–0.25 | 0.25–0.35 | 0.35–0.50 | 0.55–0.80 |
| Channels active | 2 | 4 | 8 | 12 |
| Team size needed | 1–2 | 3–4 | 7–9 | 14–18 |
| Time to 100K installs | ~40 months | ~18 months | ~7 months | ~3.5 months |
| Time to 1M installs | Not achievable | ~5+ years | ~26 months | ~14 months |

**Recommendation:** Start at **₹1,00,000/month for Months 1–2** while Phase 13 (analytics) and Phase 1 (ASO) mature — spending more before attribution and store conversion are fixed simply buys expensive installs that churn. Step up to **₹2,50,000/month from Month 3** once CPI, activation and K-factor are measured and trending correctly, then to **₹5,00,000/month from Month 6** only if LTV:CAC ≥ 2.5:1.

---

# PHASE 19 — Project Management Tables

Import-ready for Jira / ClickUp / Notion. `Start`/`End` are day offsets from project kickoff (Day 1). Duration in working days. Status for all rows: **Not Started**.

### 19.1 Master Task Register (Sprint-Ordered)

| Task ID | Task | Phase | Owner | Priority | Start (Day) | End (Day) | Duration | Dependencies | Status |
|---|---|---|---|---|---|---|---|---|---|
| P13-01 | Measurement plan & event taxonomy | 13 | DA | High | 1 | 4 | 4 | — | Not Started |
| P1-01 | ASO audit — current state | 1 | ASO | High | 1 | 3 | 3 | — | Not Started |
| P2-01 | Brand positioning workshop | 2 | CMO | High | 1 | 1 | 1 | — | Not Started |
| P15-01 | Competitor landscape mapping | 15 | GM | High | 1 | 3 | 3 | — | Not Started |
| P3-01 | Website strategy & sitemap | 3 | SEO | High | 1 | 2 | 2 | — | Not Started |
| P6-01 | Paid media strategy | 6 | PMK | High | 1 | 3 | 3 | P13-01 | Not Started |
| P8-01 | Viral loop audit & K-factor baseline | 8 | PM | High | 1 | 3 | 3 | — | Not Started |
| P9-01 | Community strategy | 9 | CM | High | 1 | 2 | 2 | — | Not Started |
| P10-01 | PR strategy & story angles | 10 | PR | High | 1 | 3 | 3 | — | Not Started |
| P1-02 | Seed keyword brainstorm | 1 | ASO | High | 2 | 4 | 3 | P1-01 | Not Started |
| P2-02 | Brand identity refresh | 2 | GD | High | 2 | 8 | 5 | P2-01 | Not Started |
| P4-01 | Social audit & channel prioritisation | 4 | SMM | High | 1 | 2 | 2 | P2-07 | Not Started |
| P1-03 | Keyword research & scoring | 1 | ASO | High | 4 | 7 | 3 | P1-02 | Not Started |
| P13-02 | Firebase analytics implementation | 13 | MOB | High | 5 | 10 | 5 | P13-01 | Not Started |
| P13-03 | MMP implementation | 13 | MOB | High | 5 | 12 | 6 | P13-01 | Not Started |
| P13-06 | Crashlytics & performance monitoring | 13 | MOB | High | 5 | 7 | 2 | P13-02 | Not Started |
| P15-02 | Feature comparison matrix | 15 | PM | High | 3 | 8 | 5 | P15-01 | Not Started |
| P2-07 | Value proposition & messaging house | 2 | CMO | High | 5 | 7 | 2 | P2-01 | Not Started |
| P1-07 | Competitor metadata teardown | 1 | ASO | High | 3 | 5 | 2 | — | Not Started |
| P1-09 | Competitor review mining | 1 | ASO | High | 5 | 8 | 3 | — | Not Started |
| P6-13 | Meta business setup & CAPI | 6 | PMK | High | 5 | 7 | 2 | P6-02 | Not Started |
| P1-10..16 | Metadata rewrite (both stores) | 1 | ASO/CW | High | 8 | 11 | 4 | P1-03 | Not Started |
| P6-02 | Tracking & attribution wiring | 6 | PMK | High | 3 | 8 | 5 | P13-01, P13-03 | Not Started |
| P3-11 | GA4 setup | 3 | DA | High | 14 | 15 | 2 | P3-03 | Not Started |
| P3-12 | Google Search Console setup | 3 | SEO | High | 14 | 14 | 1 | P3-09 | Not Started |
| P1-19 | Screenshot strategy & storyboard | 1 | ASO/GD | High | 11 | 13 | 2 | P1-08, P1-09 | Not Started |
| P1-32 | In-app rating prompt (smart trigger) | 1 | MOB | High | 12 | 15 | 3 | P13-02 | Not Started |
| P1-20 | Screenshot design — Play | 1 | GD | High | 13 | 17 | 4 | P1-19 | Not Started |
| P1-21 | Screenshot design — iOS | 1 | GD | High | 13 | 17 | 3 | P1-19 | Not Started |
| P1-23 | App icon redesign & testing | 1 | GD | High | 15 | 18 | 3 | P2-02 | Not Started |
| P6-06 | Google App Campaign (tCPI) | 6 | PMK | High | 10 | 13 | 3 | P6-02 | Not Started |
| P6-14 | Meta app install campaigns | 6 | PMK | High | 12 | 15 | 3 | P6-13 | Not Started |
| P6-19 | Apple Search Ads — brand | 6 | PMK | High | 14 | 14 | 1 | P6-02 | Not Started |
| P11-01 | CRM platform setup | 11 | CRM | High | 1 | 8 | 6 | P13-04 | Not Started |
| P12-01 | Push infrastructure & permission strategy | 12 | MOB | High | 5 | 9 | 4 | P11-01 | Not Started |
| P3-02 | Landing page design | 3 | GD | High | 3 | 7 | 4 | P3-01, P2-06 | Not Started |
| P3-03 | Landing page development | 3 | BE | High | 8 | 14 | 5 | P3-02 | Not Started |
| P13-04 | Mixpanel implementation | 13 | MOB | High | 10 | 14 | 4 | P13-02 | Not Started |
| P1-24 | App preview video — Play | 1 | VE | High | 18 | 23 | 5 | P1-19 | Not Started |
| P5-02 | Brand promo video | 5 | VE | High | 5 | 18 | 10 | P5-01 | Not Started |
| P4-08 | Instagram growth engine | 4 | SMM | High | 8 | Ongoing | — | P4-05 | Not Started |
| P8-02 | Referral infrastructure build | 8 | BE | High | 4 | 17 | 10 | P13-03 | Not Started |
| P13-12 | Data governance & privacy compliance | 13 | DA/Legal | High | 15 | 22 | 6 | P13-01 | Not Started |
| P8-03 | Invite flow redesign | 8 | PM/MOB | High | 15 | 25 | 8 | P8-02 | Not Started |
| P11-04 | Welcome series | 11 | CRM | High | 12 | 16 | 4 | P11-01 | Not Started |
| P12-04 | Onboarding push series | 12 | CRM | High | 12 | 15 | 3 | P12-01 | Not Started |
| P13-05 | Data warehouse & modelling | 13 | DA | High | 14 | 24 | 8 | P13-02, P13-03 | Not Started |
| P7-02 | Creator discovery & database | 7 | IM | High | 3 | 10 | 6 | P7-01 | Not Started |
| P7-06 | Micro-influencer batch 1 | 7 | IM | High | 15 | 35 | 15 | P7-04, P8-02 | Not Started |
| P13-07 | Looker Studio executive dashboard | 13 | DA | High | 24 | 29 | 5 | P13-05 | Not Started |
| P1-17 | Metadata localization (6 languages) | 1 | ASO | High | 25 | 32 | 5 | P1-15 | Not Started |
| P8-10 | Referral fraud prevention | 8 | BE | High | 20 | 25 | 5 | P8-02 | Not Started |
| P9-05 | WhatsApp community | 9 | CM | High | 15 | 18 | 3 | P4-16 | Not Started |
| P9-09 | College campus programme | 9 | CM | High | 25 | 70 | 30 | P7-08 | Not Started |
| P8-05 | Referral programme launch | 8 | GM | High | 26 | 30 | 5 | P8-02, P8-03, P8-04 | Not Started |
| P10-06 | Product Hunt launch | 10 | CMO | High | 30 | 45 | 10 | P5-04, P9-05 | Not Started |
| P12-05 | Settle-up reminder engine | 12 | PM/MOB | High | 18 | 24 | 5 | P12-02 | Not Started |
| P3-19 | Publish 24 SEO articles | 3 | CW | High | 20 | 90 | Ongoing | P3-17, P3-18 | Not Started |
| P8-06 | Gamification layer | 8 | PM/MOB | High | 35 | 45 | 8 | P8-05 | Not Started |
| P1-30 | Custom product pages (iOS) | 1 | ASO/GD | High | 40 | 44 | 4 | P1-21 | Not Started |
| P7-11 | Affiliate/performance creator programme | 7 | IM/BE | High | 30 | 40 | 5 | P8-02 | Not Started |
| P3-07 | Free tools / calculators | 3 | Web Dev | High | 30 | 40 | 8 | P3-03 | Not Started |
| P11-08 | Monthly money report email | 11 | CRM/BE | High | 35 | 42 | 6 | P8-09 | Not Started |
| P8-09 | Shareable moments (viral artefacts) | 8 | PM/MOB | High | 40 | 50 | 7 | P2-06 | Not Started |
| P5-07 | Customer story videos | 5 | VE | High | 40 | 55 | 8 | P5-01 | Not Started |
| P13-10 | LTV & unit economics model | 13 | DA | High | 34 | 39 | 5 | P13-05, P13-09 | Not Started |
| P10-10 | Data-led PR report (Q1) | 10 | DA/PR | High | 60 | 75 | 10 | P13-05 | Not Started |
| P3-20 | Programmatic SEO pages | 3 | Web Dev | Medium | 60 | 70 | 5 | P3-07 | Not Started |
| P6-24 | Incrementality & MMM check | 6 | DA | Medium | 80 | 85 | 5 | P13-07 | Not Started |

*(The full register is the union of all phase tables above — 223 tasks. Import each phase table as its own epic; this sprint-ordered view is the critical path.)*

### 19.2 Epic Structure (Jira / ClickUp)

| Epic ID | Epic Name | Phase | Owner | Task Count | Start | End | Status |
|---|---|---|---|---|---|---|---|
| EP-01 | App Store Optimization | 1 | ASO | 37 | Day 1 | Ongoing | Not Started |
| EP-02 | Branding | 2 | CMO | 13 | Day 1 | Day 23 | Not Started |
| EP-03 | Website & SEO | 3 | SEO | 22 | Day 1 | Ongoing | Not Started |
| EP-04 | Content & Social | 4 | SMM | 19 | Day 1 | Ongoing | Not Started |
| EP-05 | Video Marketing | 5 | VE | 12 | Day 1 | Ongoing | Not Started |
| EP-06 | Paid Marketing | 6 | PMK | 24 | Day 1 | Ongoing | Not Started |
| EP-07 | Influencer Marketing | 7 | IM | 15 | Day 1 | Ongoing | Not Started |
| EP-08 | Referral & Virality | 8 | PM | 12 | Day 1 | Ongoing | Not Started |
| EP-09 | Community | 9 | CM | 12 | Day 1 | Ongoing | Not Started |
| EP-10 | PR & Media | 10 | PR | 14 | Day 1 | Ongoing | Not Started |
| EP-11 | Email & CRM | 11 | CRM | 12 | Day 1 | Ongoing | Not Started |
| EP-12 | Push & In-App | 12 | CRM | 10 | Day 5 | Ongoing | Not Started |
| EP-13 | Analytics Infrastructure | 13 | DA | 13 | Day 1 | Day 42 | Not Started |
| EP-14 | Growth Metrics Framework | 14 | DA | 32 metrics | Day 24 | Ongoing | Not Started |
| EP-15 | Competitive Intelligence | 15 | GM | 8 | Day 1 | Ongoing | Not Started |
| **Total** | | | | **223 tasks** | | | |

### 19.3 Sprint Plan (2-Week Sprints)

| Sprint | Days | Sprint Goal | Key Epics | Definition of Done |
|---|---|---|---|---|
| S1 | 1–14 | Measurement live + new store metadata shipped | EP-13, EP-01, EP-02, EP-15 | Tracking verified in DebugView; new titles/descriptions live both stores |
| S2 | 15–28 | Creative refresh live + paid on + website live | EP-01, EP-03, EP-06, EP-05 | Screenshots + icon live; 3 campaigns running with attribution; site indexed |
| S3 | 29–42 | Referral shipped + retention systems live | EP-08, EP-11, EP-12 | Referral programme launched; welcome + winback journeys live |
| S4 | 43–56 | Creators + community + PR at scale | EP-07, EP-09, EP-10 | 25 creators live; PH launched; communities >3K members |
| S5 | 57–70 | Gamification + segment pages + campus | EP-08, EP-01, EP-09 | Gamification shipped; 5 CPPs live; 20 campuses signed |
| S6 | 71–84 | Localization + scale + optimisation | EP-01, EP-05, EP-06 | 6 locales live; localised creative shipped; CPI ≤ ₹28 |
| S7 | 85–90 | Q1 review, data PR, Q2 planning | EP-14, EP-10 | Quarterly report published; Q2 plan approved |

### 19.4 Weekly Operating Cadence

| Day | Meeting | Duration | Attendees | Output |
|---|---|---|---|---|
| Monday | Growth Review | 60 min | All leads | Dashboard review, decisions log, week's priorities |
| Monday | Paid Optimisation | 60 min | PMK, GM, DA | Budget reallocation, creative pause/scale |
| Tuesday | Content Standup | 30 min | SMM, CW, GD, VE | Week's content locked and in production |
| Wednesday | Product-Growth Sync | 45 min | PM, GM, MOB, DA | Growth feature priorities, experiment specs |
| Thursday | Creative Review | 45 min | CMO, GD, VE, MM | Approve next week's creative batch |
| Friday | Experiment Readout | 45 min | GM, DA, all owners | Test results, ship/kill decisions |
| Monthly (1st) | Business Review | 120 min | All + founders | Monthly report, budget reallocation, next month's plan |
| Quarterly | Strategy Review | Half day | All + founders | Roadmap reset, budget tier decision, hiring plan |

### 19.5 Risk Register

| Risk | Likelihood | Impact | Mitigation | Owner |
|---|---|---|---|---|
| Attribution not ready before spend starts | Medium | High | Hard gate: no media spend until P13-03 QA passes | GM |
| CPI rises faster than LTV | Medium | High | Weekly CAC:LTV check; automatic pause at CAC > LTV/2 | PMK |
| Referral programme farmed by fraud | High | High | P8-10 fraud rules; reward on qualified action only | BE |
| Creative fatigue stalls paid scaling | High | Medium | 20 new creatives/month minimum (P5-08) | VE |
| Splitwise responds with India-specific launch | Medium | High | Defensible moats: community, SEO, vernacular, virality | CMO |
| Low D30 retention caps all growth | Medium | Very High | Phases 11/12 prioritised ahead of paid scaling | PM |
| Key hire attrition | Medium | Medium | Documented playbooks (this doc), cross-training | CMO |
| Store policy violation / removal | Low | Very High | P13-12 compliance; policy review before each release | PM |
| Influencer fraud (fake followers) | High | Medium | P7-03 mandatory vetting; performance-based deals | IM |
| Budget cut mid-quarter | Medium | Medium | Tier-down plan pre-defined in Phase 18 | CMO |

---

## Appendix A — Tool Stack Summary

| Category | Tool | Monthly Cost (₹) | Phase | Priority |
|---|---|---|---|---|
| Attribution (MMP) | AppsFlyer / Adjust | 25,000 | 13 | Critical |
| Product analytics | Mixpanel / Amplitude | 15,000 | 13 | Critical |
| App analytics | Firebase + Crashlytics | Free | 13 | Critical |
| Data warehouse | BigQuery + dbt | 12,000 | 13 | High |
| BI / dashboards | Looker Studio | Free | 13 | Critical |
| CRM / lifecycle | CleverTap / MoEngage | 18,000 | 11, 12 | Critical |
| WhatsApp API | Gupshup / WATI | 15,000 | 11 | High |
| ASO intelligence | AppTweak / Sensor Tower | 20,000 | 1, 15 | Critical |
| SEO | Ahrefs / Semrush | 15,000 | 3 | High |
| Deep linking | Branch.io | 8,000 | 3, 8 | High |
| Review management | Appbot | 4,000 | 1 | Medium |
| Influencer discovery | Modash / Phyllo | 12,000 | 7 | High |
| Social scheduling | Buffer / Later | 3,000 | 4 | Medium |
| Social listening | Brand24 | 5,000 | 4 | Medium |
| Design | Figma + Canva Pro | 4,000 | 1, 2, 4 | Critical |
| Video | Adobe CC + CapCut + Submagic | 8,000 | 5 | High |
| Stock music/footage | Epidemic Sound + Envato | 5,000 | 5 | Medium |
| Web analytics | GA4 + Clarity + PostHog | 6,000 | 3 | High |
| Project management | ClickUp / Jira / Notion | 4,000 | 19 | Critical |
| Support | Freshdesk / Intercom | 8,000 | 1 | High |
| Email | SendGrid/SES (via CRM) | Included | 11 | High |
| Media database | Muck Rack / manual | 8,000 | 10 | Medium |
| **Total (full stack)** | | **~2,15,000/mo** | | |
| **Lean stack (₹50K–1L tier)** | Firebase, GA4, Canva, CapCut, Buffer, Ahrefs Lite, Notion, Appbot | **~18,000/mo** | | |

## Appendix B — Content Idea Bank (Reusable)

**Finance tips (30):** 50-30-20 on an Indian salary · emergency fund sizing · UPI spending traps · credit card float discipline · SIP vs savings · rent-to-income ratio · lifestyle inflation after a raise · tracking cash spends · splitting recurring subscriptions · the ₹200 leak audit · festival budget rules · travel fund automation · salary-day allocation ritual · zero-based budgeting for freshers · negotiating with flatmates · money conversations with a partner · student loan basics · first-job tax basics · insurance before investing · sinking funds · the 24-hour purchase rule · annual subscription audit · food delivery spend reality check · cab vs metro maths · group gifting rules · wedding season budgeting · hostel mess bill fairness · sharing a car cost-per-km · the "I'll pay you later" tax · how to say no to expensive plans.

**Expense management tips (25):** categorise on the spot · settle weekly not monthly · one group per context · use split-by-share for unequal usage · screenshot receipts immediately · set a group budget cap · nominate a treasurer · pre-agree the split rule before the trip · handle the "I didn't eat that" case · recurring expenses automation · multi-currency travel handling · settle before the trip ends · reconcile with UPI history · rounding conventions · handling partial payments · what to do when someone won't pay · splitting a shared subscription fairly · tracking cash-only spends · shared grocery systems · utility bill splitting by usage · rent splitting by room size · handling deposits and refunds · offsite/team expense claims · gift contributions tracking · year-end group summary.

**Meme/relatable formats (20):** the friend who always forgets · calculator in the group chat · "I'll Google Pay you" (never does) · one person paying for everything · the trip budget vs actual · splitting the bill at 11pm · the vegetarian at a non-veg dinner · "just adjust it next time" · the cousin who orders the most · settling ₹7 · the group treasurer's mental health · screenshot receipt archaeology · the birthday-gift chase · reverse-splitting the airport cab · month-end vs salary-day energy · "who ordered the mojito" · the roommate who never buys detergent · the fest budget spreadsheet · the person who leaves early but pays late · the WhatsApp poll about money.

---

## Document Control

| Field | Value |
|---|---|
| Total tasks | 223 across 14 task phases (+ Phases 14, 16-19 are frameworks, not tasks) |
| Total metrics tracked | 32 |
| Roles defined | 20 |
| Budget scenarios | 4 (₹50K / ₹1L / ₹2.5L / ₹5L per month) |
| Roadmap horizons | 30 / 60 / 90 / 180 / 365 days |
| Review cadence | Weekly (growth), Monthly (business), Quarterly (strategy) |
| Next review | Day 30 |

