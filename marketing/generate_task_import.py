#!/usr/bin/env python3
"""
Generates the Notion / ClickUp / Jira import CSV for the KharchaSplit Growth Master Plan.

Usage:
    python3 generate_task_import.py                    # kickoff = 2026-08-03
    python3 generate_task_import.py 2026-09-01         # custom kickoff (Monday recommended)

Outputs:
    KharchaSplit-Tasks-Import.csv        (all tasks, full field set)
    KharchaSplit-Tasks-ClickUp.csv       (ClickUp-native column names)

Source of truth for task content: KharchaSplit-Growth-Master-Plan.md
Descriptions here are condensed one-liners; the full "Description" and
"Why this task is important" prose lives in the Markdown plan.
"""

import csv
import sys
from datetime import date, timedelta

KICKOFF = date.fromisoformat(sys.argv[1]) if len(sys.argv) > 1 else date(2026, 8, 3)

PHASE_NAMES = {
    1: "App Store Optimization (ASO)",
    2: "Branding",
    3: "Website & SEO",
    4: "Content & Social Media",
    5: "Video Marketing",
    6: "Paid Marketing",
    7: "Influencer Marketing",
    8: "Referral & Viral Growth",
    9: "Community Marketing",
    10: "PR & Media Relations",
    11: "Email & CRM Marketing",
    12: "Push Notifications & In-App",
    13: "Analytics & Measurement",
    15: "Competitor Research",
}

EPIC = {p: f"EP-{p:02d} {n}" for p, n in PHASE_NAMES.items()}

SPRINTS = [
    ("S1 — Measurement & Metadata", 1, 14),
    ("S2 — Creative, Paid On, Website", 15, 28),
    ("S3 — Referral & Retention", 29, 42),
    ("S4 — Creators, Community, PR", 43, 56),
    ("S5 — Gamification & Segments", 57, 70),
    ("S6 — Localization & Scale", 71, 84),
    ("S7 — Q1 Review & Planning", 85, 90),
]


def sprint_for(day):
    for name, lo, hi in SPRINTS:
        if lo <= day <= hi:
            return name
    return "Backlog / Q2+"


# ---------------------------------------------------------------------------
# TASK DATA
# Columns: ID|Name|Category|Priority|Owner|Skills|EstTime|EstCost|Tools|Deps|
#          Deliverables|KPI|StartDay|EndDay|Description|WhyImportant
# "Deps" uses "-" for none. EndDay 999 marks an ongoing/always-on task.
# ---------------------------------------------------------------------------

RAW = """
P1-01|ASO Audit — Current State|ASO|High|ASO Specialist|ASO; Play Console; ASC analytics|3 days|Rs 15,000|Play Console; App Store Connect; AppTweak|-|ASO Audit Deck + scored rubric|Audit delivered; 20+ prioritised issues logged|1|3|Full audit of both listings: metadata, keyword coverage, creative, reviews, conversion funnel, scored against a rubric|Establishes the baseline every later ASO claim is measured against
P1-02|Seed Keyword Brainstorm|ASO|High|ASO Specialist; Content Writer|Keyword research; user empathy|2 days|Internal|Google Sheets; AnswerThePublic; Play autosuggest|P1-01|Seed keyword sheet (300+ terms)|300+ seeds across 5 categories|2|4|Build 300+ raw keyword list from features, review language, support tickets, competitor metadata and autosuggest|Keyword tools only rank what you feed them; the seed list sets the ceiling of the whole ASO program
P1-03|Keyword Research & Scoring (India)|ASO|High|ASO Specialist|ASO tooling; spreadsheet modelling|3 days|Rs 8,000/mo tool|AppTweak; Sensor Tower; MobileAction|P1-02|Master Keyword Sheet with scores and buckets|150 scored keywords; 60 target set locked|4|7|Pull volume, difficulty and chance-to-rank for every seed; score and bucket into head/mid-tail/long-tail|Ranking #1 for 60 mid-tail terms beats chasing 5 unwinnable head terms
P1-04|Keyword Research — Tier-2 Markets|ASO|Medium|ASO Specialist|Multi-market ASO|2 days|Internal|AppTweak|P1-03|Per-market keyword sheets (UAE, SG, MY, UK)|4 market sheets; 25 keywords each|8|10|Repeat keyword research for UAE, Singapore, Malaysia and UK diaspora markets|Diaspora markets convert on the same value prop with higher LTV and far less competition
P1-05|Keyword Gap Analysis vs Competitors|ASO|High|ASO Specialist|Competitive ASO|2 days|Internal|AppTweak Keyword Gap|P1-03; P15-01|Gap report with 40 winnable keywords|40 gaps identified; 15 targeted in metadata|8|10|Map keywords where competitors rank top-10 and we do not rank at all; flag winnable gaps|Gaps are the fastest ranking wins because demand is already proven
P1-06|Keyword Ranking Tracker Setup|ASO|High|ASO Specialist|Tool configuration|4 hrs|Included in tool|AppTweak; Google Sheets|P1-03|Live rank dashboard + weekly report|Tracker live; report auto-sends Mondays|7|7|Configure daily rank tracking for 150 keywords across 2 stores and 5 markets|Without daily rank data you cannot attribute a metadata change to a ranking move
P1-07|Competitor Metadata Teardown|ASO|High|ASO Specialist|Competitive analysis|2 days|Internal|AppTweak; Sensor Tower|-|Competitor Metadata Matrix (living sheet)|8 competitors tracked; weekly diff logged|3|5|Line-by-line teardown of competitor titles, subtitles, descriptions, keyword fields and update cadence|Competitor metadata is a free continuously-updated feed on what converts in the category
P1-08|Competitor Creative Teardown|ASO|High|ASO Specialist; Graphic Designer|Visual analysis|2 days|Internal|Figma; AppTweak Creative Gallery|-|Creative teardown board in Figma|8 teardowns; 10 pattern insights|3|5|Analyse competitor screenshots, captions, videos and icons for patterns and test behaviour|Prevents designing screenshots in a vacuum and reveals category conversion conventions
P1-09|Competitor Review Mining|ASO|High|ASO Specialist; Data Analyst|Data analysis; sentiment analysis|3 days|Rs 5,000|Appbot; Python scraper; LLM clustering|-|Review Insight Report + copy angle list|3,000 reviews analysed; 12 positioning angles|5|8|Scrape and NLP-cluster 3,000+ competitor reviews into a hate list and a love list|Competitor 1-star reviews are positioning copy your audience already wrote for you
P1-10|App Title Optimization (Play, 30 chars)|ASO|High|ASO Specialist; Content Writer|Copywriting; ASO|1 day|Internal|Play Console|P1-03|3 title variants + rationale doc|Title live; keyword rank +10 positions in 21 days|8|8|Rewrite Play title as brand plus highest-value keyword; test 3 variants|Title carries the heaviest keyword weight in Play and is seen by 100% of impressions
P1-11|App Title Optimization (iOS, 30 chars)|ASO|High|ASO Specialist; Content Writer|iOS ASO|1 day|Internal|App Store Connect|P1-03|iOS title variants|Title live; iOS rank lift measured|8|8|Rewrite iOS title respecting Apple's separate title/subtitle/keyword indexing model|iOS indexes three fields independently so duplicating words wastes character budget
P1-12|iOS Subtitle Optimization (30 chars)|ASO|High|ASO Specialist; Content Writer|iOS ASO; copywriting|4 hrs|Internal|App Store Connect|P1-11|3 subtitle variants|Live; +8 keywords entering top-50|9|9|Craft subtitle covering the secondary keyword cluster without repeating title words|Subtitle is a full second keyword field on iOS and doubles indexed surface
P1-13|iOS Keyword Field Optimization (100 chars)|ASO|High|ASO Specialist|iOS ASO|4 hrs|Internal|App Store Connect; AppTweak|P1-03|Keyword string v1|100/100 chars used; +15 keywords ranked|9|9|Pack 100 chars with comma-separated non-duplicated keywords including misspellings and Hinglish|The densest ranking lever on iOS; wasted characters are pure lost visibility
P1-14|Play Short Description (80 chars)|ASO|High|ASO Specialist; Content Writer|Conversion copywriting|4 hrs|Internal|Play Console|P1-03|3 short description variants|+3-5% listing CVR in A/B test|9|9|Write a benefit-led hook that doubles as a keyword carrier above the fold|Highest-read text on the Play listing and a confirmed ranking factor
P1-15|Play Long Description (4000 chars)|ASO|High|Content Writer; ASO Specialist|SEO copywriting|2 days|Rs 6,000|Play Console; Grammarly|P1-03; P1-09|Final long description + 2 variants|Keyword coverage 60/60 targets; CVR +2%|10|11|Rewrite with 2-3% keyword density, scannable structure, social proof, feature list, FAQ and CTA|Play indexes the full description and it is the main persuasion surface for expanders
P1-16|iOS Description & Promo Text|ASO|High|Content Writer|Copywriting|1 day|Internal|App Store Connect|P1-11|iOS description + 12-month promo text calendar|Promo text updated monthly without fail|10|11|Write iOS description plus a rolling 170-char promotional text calendar|Promo text is the only iOS field editable without app review - your monthly megaphone
P1-17|Metadata Localization — 6 Indian Languages|ASO|High|ASO Specialist; Translation vendor|Native language copywriting|5 days|Rs 36,000|Play Console; ASC; native translators|P1-15; P1-16|6 localized metadata sets|6 locales live; regional CVR +15%|25|32|Transcreate title, subtitle, description and keywords into Hindi, Marathi, Tamil, Telugu, Bengali, Gujarati|70%+ of India's next internet users are vernacular-first; localized listings lift CVR 15-25%
P1-18|Metadata Localization — 4 International Markets|ASO|Medium|ASO Specialist|Multi-market ASO|2 days|Rs 12,000|App Store Connect; Play Console|P1-04|4 international metadata sets|4 markets live; CVR >=25% each|45|48|Adapt metadata for UAE, Singapore, Malaysia and UK including currency and idiom|Currency and idiom mismatch is the top CVR killer in diaspora markets
P1-19|Screenshot Strategy & Storyboard|ASO|High|ASO Specialist; Graphic Designer|Conversion design; storytelling|2 days|Internal|Figma; Miro|P1-08; P1-09|Screenshot storyboard + caption copy deck|Storyboard approved; captions under 7 words|11|13|Define the 8-screenshot narrative arc and write caption copy before any design work|Screenshots drive 60%+ of store conversion; the first two decide most installs
P1-20|Screenshot Design — Play (8 sets)|ASO|High|Graphic Designer|Mobile UI design; Figma|4 days|Rs 25,000|Figma; Previewed; AppLaunchpad|P1-19; P2-05|8 Play screenshots across densities|Live; Play CVR 22% to 28%|13|17|Design 8 device-framed screenshots with bold captions in brand colours, portrait and tablet|Play's first three screenshots appear in search results and act as ad creative
P1-21|Screenshot Design — iOS (all sizes)|ASO|High|Graphic Designer|iOS design specs|3 days|Rs 18,000|Figma; App Store Connect|P1-19|Full iOS screenshot set (6.7in, 6.5in, 5.5in, iPad)|Live; iOS CVR 28% to 34%|13|17|Adapt the screenshot narrative to every required Apple device size|Apple rejects incomplete sets and wrong sizes render letterboxed and untrustworthy
P1-22|Feature Graphic (Play 1024x500)|ASO|High|Graphic Designer|Graphic design|1 day|Rs 5,000|Figma|P2-05|Feature graphic + 2 variants|Live; used in 1 A/B test|14|14|Design the feature graphic used in Play collections, search and as video poster frame|Required for Play editorial featuring consideration and doubles as video thumbnail
P1-23|App Icon Redesign & Testing|ASO|High|Graphic Designer; ASO Specialist|Icon design; brand|3 days|Rs 12,000|Figma; Play Experiments; PickFu|P2-02|4 icon candidates + test results|Winning icon +5% CVR (significant)|15|18|Design and test 4 icon candidates via Play Experiments and a user panel|The icon appears in every impression surface; 5-10% CVR swings are common
P1-24|App Preview Video — Play (30s)|ASO|High|Video Editor; Motion Designer|Video editing; motion graphics|5 days|Rs 30,000|After Effects; Premiere; Rive|P1-19; P2-05|30s Play preview video + YouTube upload|Live; CVR +4% vs no-video control|18|23|Produce a sound-off-first 30-second preview: problem, solution in 3 taps, settle up, CTA|Listings with video convert 20-35% better and most store views are muted
P1-25|App Preview Videos — iOS (3 x 30s)|ASO|High|Video Editor|iOS preview specs|4 days|Rs 22,000|Final Cut; Premiere; device capture|P1-24|3 iOS preview videos|Live; iOS CVR +5%|20|25|Produce three iOS previews (Groups, Smart Settle-up, Insights) from real device capture|Apple allows three previews and auto-plays the first - triple the storytelling space
P1-26|Localized Creative Sets (Hindi + 2)|ASO|Medium|Graphic Designer; Video Editor|Localization design|3 days|Rs 18,000|Figma; Premiere|P1-17; P1-20|3 localized creative sets|Regional CVR +10%|33|36|Produce screenshot caption and video subtitle variants in Hindi, Marathi and Tamil|Localized creative beats localized text alone because visuals carry the value prop
P1-27|A/B Test Roadmap (12 tests)|ASO|High|ASO Specialist; Data Analyst|Experiment design; statistics|1 day|Internal|Notion; Play Experiments|P1-20; P1-23|A/B Test Roadmap sheet|12 tests queued; 2 running concurrently|19|19|Build a prioritised backlog of 12 store experiments with hypothesis, metric and expected lift|You only get ~2 test slots per month so each must be spent on the biggest lever
P1-28|Run Play Store Listing Experiments|ASO|High|ASO Specialist|Experimentation; statistics|4 hrs/wk ongoing|Internal|Play Console Experiments|P1-27|Monthly experiment results log|2 tests/month; >=1 winner/month|20|999|Execute two store experiments per month on icon, screenshots, short description and feature graphic|Eight winning tests at +3% compound to roughly +27% CVR across every channel
P1-29|Run Apple Product Page Optimization Tests|ASO|High|ASO Specialist|iOS PPO|4 hrs setup then ongoing|Internal|App Store Connect PPO|P1-21|PPO test live + results|1 PPO test always running|22|999|Use Apple PPO to test up to three treatments of icon, screenshots and preview|PPO is free traffic-split testing with native significance - always run it
P1-30|Custom Product Pages (iOS) — 5 variants|ASO|High|ASO Specialist; Graphic Designer|iOS CPP; segmentation|4 days|Rs 25,000|App Store Connect; Figma|P1-21; P6-14|5 live CPPs + campaign mapping|Paid CVR +20% on CPP-linked traffic|40|44|Build CPPs for Students, Travel, Roommates, Couples and Office teams linked to matching campaigns|Matching ad message to a bespoke page lifts paid conversion 20-40% for free
P1-31|Custom Store Listings (Play) — 5 variants|ASO|Medium|ASO Specialist|Play custom listings|3 days|Rs 15,000|Play Console|P1-30|5 custom Play listings|Paid CVR +15%|45|48|Build Play custom listings segmented by keyword group, country and install-state audience|Lets one app serve five positioning promises without diluting the main listing
P1-32|In-App Rating Prompt — Smart Trigger|ASO|High|Mobile Developer; Product Manager|Flutter; in_app_review API|3 days|Internal (Rs 15,000 effort)|in_app_review; Firebase Remote Config|P13-02|Shipped release with smart prompts|Prompt-to-rating >=15%; avg rating >=4.5 in 60 days|12|15|Trigger review prompts at happiness moments (3rd expense, successful settle-up, money received)|Moment-based prompts routinely move ratings from 4.2 to 4.6 and acceptance from 5% to 20%
P1-33|Negative Feedback Interception|ASO|High|Mobile Developer; Customer Support|Flutter; UX|2 days|Internal|Flutter; Freshdesk|P1-32|Feedback interception flow live|1-star share drops below 6%|15|17|Pre-prompt routes happy users to the store and unhappy users to an in-app feedback form|Diverts unhappy users into support where they can be recovered rather than into public 1-stars
P1-34|Review Response SLA & Playbook|ASO|High|Customer Support; ASO Specialist|Support writing; empathy|1 day setup then 1 hr/day|Internal|Play Console; ASC; Appbot|-|Response playbook + SLA dashboard|100% response rate; >=25 rating upgrades/month|10|999|Respond to all reviews within 24h (1-3 star) or 72h (4-5 star) using 20 templated patterns|Play weighs responsiveness and replied-to users upgrade their rating ~30% of the time
P1-35|Review Sentiment Dashboard|ASO|Medium|Data Analyst|Data pipeline; NLP|2 days|Rs 4,000/mo|Appbot; Metabase|P1-34|Live sentiment dashboard|Weekly digest delivered; bug detection under 48h|20|22|Auto-tag reviews by theme and pipe a weekly digest to Product|Turns the review stream into free continuous product research and early bug detection
P1-36|Rating Recovery Campaign|ASO|Medium|Customer Support; CRM Executive|CRM; support|2 hrs/wk ongoing|Internal|Freshdesk; CleverTap|P1-33; P11-01|Recovery campaign + tracked outcomes|30% of contacted users re-rate; +0.2 avg rating|30|999|Identify 1-3 star raters, fix their issue, then personally invite them to re-rate|A recovered 1-star to 5-star is a two-point swing; 200 of these move a 4.2 to 4.5
P1-37|Monthly ASO Report & Iteration|ASO|High|ASO Specialist|Reporting; analysis|1 day/month|Internal|Looker Studio; AppTweak|P1-06|Monthly ASO report|Report on the 1st; >=5 keyword rank gains/month|30|999|Monthly report on rank movement, CVR, impressions and next month's metadata changes|ASO decays as competitors move; a fixed cadence keeps it a program not a project
P2-01|Brand Positioning Workshop|Branding|High|CMO; Product Manager|Brand strategy; facilitation|1 day|Rs 25,000|Miro; Figma|-|Positioning Statement + Brand Strategy doc|Signed off by founders; used in all briefs|1|1|Half-day workshop locking category, segment, enemy, unique mechanism and reason to believe|Every downstream asset inherits this; ambiguity here multiplies into inconsistency everywhere
P2-02|Brand Identity Refresh / Audit|Branding|High|Graphic Designer; CMO|Brand identity design|5 days|Rs 60,000|Figma; Illustrator|P2-01|Identity system (logo, mark, lockups)|Identity approved and applied to store and site|2|8|Audit and refresh logo, mark, colours and type for distinctiveness and fintech trust|Money apps live on perceived trust; an amateur identity suppresses install intent
P2-03|Logo Usage Rules|Branding|High|Graphic Designer|Brand systems|1 day|Internal|Figma|P2-02|Logo usage spec + asset pack|Zero off-spec logo uses in QA|9|9|Define clear-space, minimum sizes, mono and inverse versions, co-branding and icon safe area|Prevents the slow visual erosion that starts once ten people make assets
P2-04|Colour Palette System|Branding|High|Graphic Designer|Colour theory; accessibility|1 day|Internal|Figma; Stark|P2-02|Colour token sheet (hex, RGB, Flutter constants)|All tokens WCAG AA compliant; adopted in Flutter theme|9|9|Define primary, secondary, accent, semantic (owed/settled) and neutral tokens with dark-mode pairs|Money UI encodes meaning in colour so ad-hoc choices create real usability failures
P2-05|Typography System|Branding|High|Graphic Designer|Typography|1 day|Rs 8,000|Google Fonts; Fontshare|P2-02|Type system spec + licensed font files|Type scale live in app and web|9|10|Choose display and body type with Indic script support and define the full scale|Devanagari and Tamil support is non-negotiable; retrofitting fonts breaks every asset
P2-06|Brand Guidelines Document|Branding|High|Graphic Designer; Content Writer|Brand systems; writing|4 days|Rs 35,000|Figma; Notion|P2-02; P2-03; P2-04; P2-05|Brand Guidelines PDF + Figma library|Distributed to 100% of vendors|10|14|Compile a 30-40 page brand book covering strategy, identity, motion, tone and misuse|The artefact that lets you hire freelancers and agencies without quality collapse
P2-07|Value Proposition & Messaging House|Branding|High|CMO; Content Writer|Messaging strategy|2 days|Rs 15,000|Google Docs|P2-01|Messaging House doc + headline bank|Used in >=90% of live creative|5|7|Build core promise, three pillars, proof points and 15 approved headlines|Gives ads, ASO and PR a shared vocabulary so 500 assets sound like one company
P2-08|Brand Voice & Tone Guide|Branding|High|Content Writer; CMO|Copy strategy|2 days|Rs 12,000|Notion|P2-07|Voice guide with 40 before/after examples|Applied to all push and email copy|7|9|Define voice, tone modulation by context, banned words and Hinglish rules|Wrong tone in a "you owe Rs 450" notification reads as harassment and drives uninstalls
P2-09|Brand Asset Library|Branding|Medium|Graphic Designer|Asset management|2 days|Internal|Figma; Google Drive|P2-06|Live asset library with access matrix|100% of team using library; retrieval under 5 min|15|16|Central permissioned library of logos, templates, screenshots, icons, stings and fonts|Removes the daily "can you send me the logo" tax and guarantees current assets
P2-10|Social Media Template Kit|Branding|High|Graphic Designer|Template design|3 days|Rs 20,000|Figma; Canva Pro|P2-06|25 templates in Figma and Canva|Template reuse >=80% of posts|16|18|Build 25 editable templates for carousels, quotes, tips, memes, reel covers and stories|Lets the SMM ship 30 posts/month without a designer in the loop for each asset
P2-11|Motion & Sound Identity|Branding|Medium|Motion Designer|Motion design; sound|4 days|Rs 30,000|After Effects; Rive; Audition|P2-02|Motion kit + audio sting files|Used in 100% of videos from Day 30|18|22|Create logo animation, transition style, micro-interaction language and a 2-second audio sting|Sonic and motion branding make short-form video instantly recognisable in a feed
P2-12|Brand Awareness Baseline Survey|Branding|Medium|Growth Manager; Data Analyst|Survey design; analysis|3 days|Rs 15,000|Google Forms; Typeform; panel|P2-01|Baseline awareness report|500 responses; baseline % recorded|20|23|Survey 500 target users on aided and unaided awareness versus Splitwise|You cannot claim brand growth without a baseline and it reveals what people think you do
P2-13|Trademark & Brand Protection|Branding|High|CMO; Legal|IP basics|3 days|Rs 35,000|IP attorney; Namecheap|P2-02|TM applications + handle inventory|TM filed; all key handles secured|10|13|File trademarks for name and logo and secure handles plus defensive domains|An unprotected fintech brand is a lawsuit and a rebrand waiting to happen
P3-01|Website Strategy & Sitemap|Website|High|SEO Specialist; Growth Manager|Information architecture; SEO|2 days|Internal|Miro; Screaming Frog|-|Sitemap + URL structure doc|Approved sitemap; max 3 clicks to any page|1|2|Define site architecture across home, features, use-cases, blog, tools, comparisons and legal|Architecture decides crawl equity and which pages can ever rank; retrofitting costs rankings
P3-02|Landing Page Design|Website|High|Graphic Designer|Web design; CRO|4 days|Rs 40,000|Figma|P3-01; P2-02|Home page design (desktop + mobile)|Design approved; >=3 CTA placements|3|7|Design hero, social proof, benefits, how-it-works, comparison, testimonials, FAQ and sticky CTA|Every PR mention, influencer link and ad lands here so its CVR multiplies every channel
P3-03|Landing Page Development|Website|High|Backend/Web Developer|Next.js or Webflow; Tailwind|5 days|Rs 50,000|Next.js; Vercel; Webflow|P3-02|Live home page|Live; LCP under 2.0s; CVR >=12% to store click|8|14|Build the home page statically generated and image-optimised with minimal critical CSS|Speed is both a ranking and a conversion factor; 1s delay costs ~7% of conversions
P3-04|Smart App Banner + Deferred Deep Linking|Website|High|Backend Developer; Mobile Developer|Deep linking; Branch SDK|3 days|Rs 8,000/mo|Branch.io; AppsFlyer OneLink|P3-03; P13-03|Working deep links across all app states|100% of web CTAs deep-link; install-to-registration +15%|15|17|Implement smart banners and deferred deep links so web visitors land on the right in-app screen|Deferred deep linking decides whether a web visitor becomes an activated user
P3-05|Use-Case Landing Pages (6)|Website|High|Content Writer; SEO Specialist; Graphic Designer|SEO copywriting|6 days|Rs 36,000|Next.js; Figma|P3-03|6 live use-case pages|6 live; 3 ranking top-20 within 90 days|18|25|Build pages for Roommates, Trips, Couples, Office lunch, Weddings and Hostel/College|Captures high-intent long-tail search the home page can never rank for
P3-06|Comparison Pages (5)|Website|High|Content Writer; SEO Specialist|Competitive copywriting|4 days|Rs 25,000|Next.js|P15-02|5 comparison pages|Top-10 for 3 "vs" queries; CVR >=18%|26|30|Build honest "KharchaSplit vs X" pages with feature tables, migration guides and pricing|Comparison queries carry the highest install intent of any organic traffic
P3-07|Free Tools / Calculators (5)|Website|High|Web Developer; SEO Specialist|JavaScript; SEO|8 days|Rs 60,000|Next.js|P3-03|5 live calculators|20K organic sessions/mo by Day 180; 200+ backlinks|30|40|Build indexable Split Bill, Trip Budget, Rent Split, Tip and Group Settle-Up calculators|Tools are link magnets that rank for years and demonstrate value before install
P3-08|Conversion Rate Optimization Program|Website|High|Growth Manager; Web Developer|CRO; experimentation|6 hrs/wk ongoing|Rs 6,000/mo|Microsoft Clarity; PostHog; VWO|P3-03; P3-11|Monthly CRO report + test log|2 tests/month; CVR 12% to 20% by Day 180|20|999|Run heatmaps, recordings and funnel analysis then A/B test hero, CTA, proof and forms|Doubling site CVR doubles the return on every SEO, PR and ad rupee already spent
P3-09|Technical SEO Foundation|SEO|High|SEO Specialist; Web Developer|Technical SEO|3 days|Internal|Screaming Frog; GSC|P3-03|Tech SEO checklist signed off|0 critical crawl errors; 100% pages indexed|14|16|Configure robots.txt, sitemaps, canonicals, hreflang, 301 map and crawl-budget hygiene|Technical errors silently cap the ceiling of all content investment
P3-10|Schema Markup Implementation|SEO|High|SEO Specialist; Web Developer|Schema.org; JSON-LD|2 days|Internal|Schema validator; GSC|P3-09|Validated schema on all templates|0 schema errors; rich results on 5 page types|16|18|Implement SoftwareApplication, Organization, FAQPage, HowTo, Breadcrumb and Article schema|Rich results raise CTR from the same ranking position - free traffic without new rankings
P3-11|Google Analytics 4 Setup|Analytics|High|Data Analyst; SEO Specialist|GA4; GTM|2 days|Free|GA4; GTM; BigQuery|P3-03|Live GA4 with 12 events and 4 conversions|All events firing; BigQuery export daily|14|15|Configure GA4 property, enhanced measurement, custom events, conversions and BigQuery export|Without event-level GA4 you cannot tell which content drives installs versus just traffic
P3-12|Google Search Console Setup|SEO|High|SEO Specialist|GSC|3 hrs|Free|Google Search Console|P3-09|Verified GSC + connected reporting|Sitemaps submitted; weekly index check|14|14|Verify all properties, submit sitemaps, configure alerts and connect to Looker Studio|GSC is the only source of truth for query-level organic data and indexation health
P3-13|Core Web Vitals Optimization|SEO|High|Web Developer|Performance engineering|4 days|Internal|PageSpeed Insights; Lighthouse CI; Cloudflare|P3-03|CWV passing on 100% of URLs|All green in CrUX; mobile score >=90|19|23|Optimise LCP, INP and CLS via image formats, font-display, code-splitting, CDN and lazy-loading|Mobile-first Indian traffic on 4G punishes heavy sites with both bounce and ranking loss
P3-14|Mobile UX & Accessibility Audit|Website|Medium|Web Developer; Graphic Designer|Accessibility; mobile UX|2 days|Internal|Lighthouse; axe; BrowserStack|P3-03|Audit + fix list with all P0 resolved|Accessibility score >=95; 0 P0 issues|24|25|Audit tap targets, contrast, font sizes and forms on real low-end Android devices|~85% of traffic is mobile on mid-range Android where desktop-tested sites break
P3-15|Internal Linking Architecture|SEO|Medium|SEO Specialist|SEO architecture|2 days|Internal|Screaming Frog; Ahrefs|P3-05; P3-16|Internal linking map + implementation|Every page has >=3 internal inbound links|35|36|Define hub-and-spoke linking with use-case pages as hubs and automated related-posts logic|Internal links distribute authority to money pages and are fully within your control
P3-16|SEO Keyword Research (Web)|SEO|High|SEO Specialist|Keyword research|3 days|Rs 15,000/mo tool|Ahrefs; Semrush|P3-01|Keyword map (500 terms mapped to URLs)|500 keywords mapped; 60 briefs queued|5|8|Build a 500-keyword map across five clusters mapped to URLs and funnel stages|Prevents cannibalisation and gives every article a defined ranking job before writing
P3-17|Content Pillar & Cluster Plan|SEO|High|SEO Specialist; Content Writer|Content strategy|2 days|Internal|Notion; Ahrefs|P3-16|Pillar-cluster map|5 pillars and 60 clusters defined|9|10|Design 5 pillar pages each with 8-12 supporting cluster posts|Google rewards topical depth far more than scattered one-off posts
P3-18|Blog Setup & Templates|Website|High|Web Developer; Graphic Designer|Web development|3 days|Rs 18,000|Next.js; Ghost|P3-03|Live blog with SEO article template|Blog live; in-article CTA CTR >=5%|15|18|Build the article template with TOC, schema, author box, related posts and app CTA|The template's CTA and capture points decide whether traffic ever becomes users
P3-19|Publish 24 SEO Articles (Q1)|SEO|High|Content Writer; SEO Specialist|SEO writing|2 articles/week ongoing|Rs 2,500/article (Rs 60,000)|Surfer SEO; Grammarly; GSC|P3-17; P3-18|24 published articles|24 published; 10K organic sessions/mo by Day 90|20|90|Publish two 1,500-2,500 word articles weekly with original data, screenshots and internal links|Volume plus consistency is how new domains earn crawl frequency and topical trust
P3-20|Programmatic SEO Pages|SEO|Medium|Web Developer; SEO Specialist|Programmatic SEO|5 days|Rs 35,000|Next.js; Airtable/CMS|P3-07; P3-09|200+ programmatic pages live|200 indexed; 15K sessions/mo by Day 180|60|70|Generate quality-gated templated pages for cities, split counts and destinations|Captures thousands of long-tail queries at near-zero marginal cost per page
P3-21|Backlink Acquisition Campaign|SEO|High|SEO Specialist; PR Executive|Link building; outreach|8 hrs/wk ongoing|Rs 25,000/mo|Ahrefs; Hunter.io; BuzzStream|P3-07|Monthly backlink report|25 referring domains/month; DR 0 to 35 by Day 180|30|999|Run HARO, guest posts, tool link-building, broken-link building and directory outreach|Domain authority is the gating factor on ranking for competitive money keywords
P3-22|Looker Studio SEO Dashboard|SEO|Medium|Data Analyst; SEO Specialist|Looker Studio|2 days|Free|Looker Studio; GSC; GA4|P3-11; P3-12|Live SEO dashboard|Dashboard live; weekly review meeting|25|26|Blend GSC, GA4 and rank tracker into one dashboard through to assisted installs|Makes SEO's contribution to installs visible to leadership, protecting the budget
P4-01|Social Audit & Channel Prioritisation|Content|High|Social Media Manager; Growth Manager|Social strategy|2 days|Internal|Native analytics; Notion|P2-01|Channel strategy doc with tiering|Tiering approved; effort split 60/25/15|1|2|Audit profiles and tier platforms by audience fit, content cost and install intent|Spreading equally across 8 platforms is the most common growth mistake
P4-02|Profile Optimization — All 8 Platforms|Content|High|Social Media Manager; Graphic Designer|Social copywriting; design|2 days|Rs 8,000|Canva; Linktree or custom|P2-02|8 optimised profiles + link-in-bio page|All live; bio-to-install CVR >=8%|3|4|Optimise handle, keyword name field, bio, link-in-bio, highlights, banner and pinned post|Profiles are your social landing pages; an unoptimised bio wastes every viral post
P4-03|Content Pillars Definition|Content|High|Content Writer; Social Media Manager|Content strategy|1 day|Internal|Notion|P2-07|Content pillar doc + ratio|Pillars used in 100% of calendar entries|3|3|Lock five pillars and a 40/25/15/15/5 mix across education, tips, product, humour and community|A fixed pillar ratio prevents drift into all-promo content that kills engagement
P4-04|Persona & Voice Adaptation per Platform|Content|Medium|Content Writer|Copy adaptation|1 day|Internal|Notion|P2-08|Platform voice matrix|Applied across the content calendar|4|4|Map how brand voice flexes across LinkedIn, Instagram, X and YouTube|Cross-posting identical copy is why most brand accounts flatline
P4-05|Content Production System|Content|High|Social Media Manager; Marketing Manager|Operations; workflow design|2 days|Rs 3,000/mo|Notion or ClickUp; Buffer or Later|P4-03|Documented workflow + Notion board|Pipeline live; 2 weeks of content always buffered|5|6|Set up idea-to-publish pipeline with SLAs at brief, script, design, edit, approve and schedule|Content dies from process failure not idea failure; the pipeline makes 30 posts/mo repeatable
P4-06|UGC & Creator Sourcing Pipeline|Content|High|Social Media Manager; Influencer Manager|Creator sourcing|4 days|Rs 40,000/mo|Instagram; Billo; Insense|P4-05|10 signed UGC creators + brief pack|20 UGC videos/month delivered|10|14|Recruit 10 student and young-professional UGC creators on retainer for vertical video|UGC-style creative outperforms polished brand video on organic reach and paid CTR
P4-07|Social Listening & Monitoring|Content|High|Social Media Manager; Community Manager|Social listening|1 hr/day ongoing|Rs 5,000/mo|Brand24; TweetDeck; F5Bot|-|Daily listening log + response record|>=20 high-intent replies/week|7|999|Monitor mentions of splitting keywords across X, Reddit, Threads and Quora and reply within 2 hours|Real-time interception of high-intent conversations converts far better than broadcast
P4-08|Instagram Growth Engine|Content|High|Social Media Manager; Video Editor; Graphic Designer|Reels editing; design|20 hrs/wk ongoing|Rs 15,000/mo production|CapCut; Canva; Later|P4-05|Weekly IG content pack + monthly report|0 to 50K followers in 180 days; 500K reach/mo by Day 90|8|999|Ship 5 reels, 3 carousels and 10 stories weekly against the pillar mix|Instagram is where the 18-30 India segment lives and Reels is the cheapest organic reach
P4-09|YouTube Shorts Engine|Content|High|Video Editor; Social Media Manager|Short-form editing|8 hrs/wk ongoing|Internal|CapCut; YouTube Studio|P5-06|60 Shorts in 90 days|0 to 25K subs in 180 days; 2M views/quarter|10|999|Repurpose and natively produce 5 Shorts weekly with 1.5s hooks and burned subtitles|Shorts have the best long-tail resurfacing and feed the long-form channel
P4-10|YouTube Long-Form Channel|Content|High|Video Editor; Content Writer|YouTube SEO; scripting|12 hrs/wk ongoing|Rs 20,000/mo|Premiere; TubeBuddy; Photoshop|P5-01|12 long-form videos per quarter|12/quarter; 4,000 watch hours by Day 180|15|999|Publish one SEO-optimised long-form video weekly with chapters and custom thumbnails|YouTube is the world's #2 search engine and these videos deliver installs for years
P4-11|LinkedIn Founder-Led Growth|Content|High|CMO; Content Writer|LinkedIn writing|4 hrs/wk ongoing|Internal|LinkedIn; Taplio|P2-08|Weekly LinkedIn content pack|Founder 0 to 15K followers in 180 days; 5 inbound press/mo|8|999|Founder posts 4x weekly on build-in-public metrics, product decisions and India fintech|The cheapest B2B, investor, press and talent channel; drives disproportionate PR pickup
P4-12|X / Twitter Presence|Content|Medium|Social Media Manager|Short-form writing|5 hrs/wk ongoing|Internal|X; Typefully|P4-04|Daily X schedule|0 to 10K followers in 180 days; 3 threads over 50K views|8|999|Post 3x daily plus a weekly long thread and reply into fintech conversations|X drives PR, Product Hunt momentum and tech-community credibility
P4-13|Threads Presence|Content|Low|Social Media Manager|Conversational writing|3 hrs/wk ongoing|Internal|Threads|P4-02|Daily Threads schedule|0 to 8K followers in 180 days|20|999|Post twice daily, reply-heavy, cross-pollinating the Instagram audience|Threads still gives outsized organic reach to early consistent accounts
P4-14|Facebook Page + Groups Strategy|Content|Medium|Social Media Manager; Community Manager|Facebook marketing|5 hrs/wk ongoing|Internal|Meta Business Suite|P4-02|FB content plan + group engagement log|0 to 20K page followers; 200 group-driven installs/mo|12|999|Post 4x weekly to the page and genuinely participate in 20 relevant groups|Facebook still dominates tier-2/3 India and the 30+ household budget audience
P4-15|Pinterest SEO Strategy|Content|Low|Graphic Designer; Social Media Manager|Pinterest SEO; design|4 hrs/wk ongoing|Internal|Pinterest; Canva; Tailwind|~P3-19|120 pins in 90 days|100K monthly pin impressions by Day 90|25|999|Publish 10 pins weekly of templates, infographics and checklists linking to blog and tools|Pinterest is a search engine with multi-year pin half-life and strong budget intent
P4-16|WhatsApp Channel|Content|High|Social Media Manager; CRM Executive|WhatsApp marketing|2 days setup then ongoing|Internal|WhatsApp Channels|P4-02|Live channel + weekly broadcast|0 to 25K subscribers in 180 days|20|999|Launch a WhatsApp Channel for money tips and product updates|The highest-open-rate broadcast surface in India at 70-90% versus email
P4-17|Quora & Reddit Answer Programme|Content|High|Community Manager; Content Writer|Community writing|4 hrs/wk ongoing|Internal|Quora; Reddit|P4-07|60 answers in 90 days|60 answers; 3,000 referred sessions/mo by Day 90|15|999|Answer 5 high-intent questions weekly with genuine non-promotional value|These answers rank in Google and deliver compounding high-intent traffic for years
P4-18|Meme & Trend Jacking Desk|Content|Medium|Social Media Manager; Graphic Designer|Meme literacy; fast design|5 hrs/wk ongoing|Internal|CapCut; Canva|P2-10|3 trend posts per week|>=1 post over 100K reach per month|15|999|Maintain a 24-hour capability to turn trending audio and formats into on-brand money memes|Trend participation is the highest reach-per-rupee format and speed is the whole advantage
P4-19|Monthly Content Performance Review|Content|High|Social Media Manager; Data Analyst|Analytics|1 day/month|Internal|Looker Studio; native analytics|P13-07|Monthly content report|Report by the 3rd; >=1 format doubled down per month|30|999|Review reach, saves, shares and attributed installs by pillar and format; kill bottom 20%|Content without a kill-and-double loop plateaus; this review is what compounds it
P5-01|Video Strategy & Asset Map|Video|High|Video Editor; CMO|Video strategy; production planning|2 days|Internal|Notion; Frame.io|P2-01|Video asset map + production schedule|40+ assets planned from 3 shoot days|1|2|Map every video asset by surface and design a shoot plan producing all of them in minimum sessions|Shooting per-request costs 3-4x more than a mapped plan since most assets share footage
P5-02|Brand Promo Video (60s)|Video|High|Video Editor; Motion Designer|Directing; editing|10 days|Rs 1,20,000|Premiere; After Effects; crew|P5-01; P2-02|60s promo + 30s and 15s cutdowns|Delivered; >=100K views in 60 days|5|18|Produce the hero brand film: the money-awkwardness problem, the shift, the product, the payoff|The anchor asset for website, PR, investor decks, pre-roll and launch moments
P5-03|Feature Videos (6 x 45s)|Video|High|Video Editor; Motion Designer|Screen capture; motion|8 days|Rs 60,000|Rive; After Effects|P5-01|6 feature videos + vertical cuts|6 delivered; each used in >=3 surfaces|12|22|Produce one video per core feature with screen recording plus motion overlays|Feature videos are the reusable middle-funnel workhorse across ads, store, help and onboarding
P5-04|Product Demo Video (90s)|Video|High|Video Editor|Screen recording; editing|4 days|Rs 30,000|QuickTime; Premiere|P5-03|90s demo + 30s cut|Delivered; live on homepage and Product Hunt|20|24|Film the end-to-end flow from group creation through uneven split to UPI settle-up and report|The asset that answers "does it actually work" - critical for press and considered installs
P5-05|App Walkthrough / Tutorial Series (8)|Video|High|Video Editor; Content Writer|Tutorial scripting; editing|10 days|Rs 50,000|Premiere; TubeBuddy|P5-04|8 tutorial videos with chapters|8 published; 50K cumulative views in 90 days|25|40|Produce a long-form how-to series covering onboarding through troubleshooting|Captures YouTube search demand, cuts support load and improves activation
P5-06|Short-Form Video Factory (30/month)|Video|High|Video Editor; Social Media Manager|Fast vertical editing|Ongoing|Rs 35,000/mo|CapCut; Descript; Submagic|P4-06|30 vertical videos per month|30/mo shipped; >=3 over 100K views per month|15|999|Run a standing pipeline producing 30 vertical videos monthly from hooks, UGC and repurposing|Volume is the algorithm's price of entry and a factory sustains it where one-off creativity cannot
P5-07|Customer Story Videos (6)|Video|High|Video Editor; Influencer Manager|Interviewing; documentary editing|8 days|Rs 45,000|Premiere; crew|P5-01|6 story videos + vertical cuts|6 delivered; used in ads at CTR >=1.8%|40|55|Film six real user groups: hostel, Europe trip, couple, office lunch, startup team, family|Authentic proof outperforms every claim you make about yourself and makes the best ad creative
P5-08|Paid Ad Creative Batch (20/month)|Video|High|Video Editor; Performance Marketer|Direct-response video|Ongoing|Rs 40,000/mo|CapCut; Meta Ads Library|P6-01|20 ad creatives per month|20/mo; >=3 winners scaled monthly|19|999|Produce 20 monthly ad variants across hook tests, UGC, problem-agitate-solve, testimonial and demo|Creative fatigue is the top cause of rising CPI and a 20/month refresh is the antidote
P5-09|Motion Graphics & Explainers|Video|Medium|Motion Designer|After Effects; Rive|6 days|Rs 40,000|After Effects; Rive|P2-11|4 animated explainers|4 delivered and used in onboarding|45|52|Animate abstract concepts: debt simplification, split modes and privacy/security|Some product ideas cannot be screen-recorded; animation is the only way to make them intuitive
P5-10|Video Localization|Video|Medium|Video Editor; Localization vendor|Localization; subtitling|5 days|Rs 35,000|Submagic; ElevenLabs; VO artists|P5-02; P5-04|20 localized videos (4 languages x 5 videos)|Regional watch-time +40%|55|62|Subtitle and voiceover key videos in Hindi, Marathi, Tamil and Telugu|Vernacular video is the largest untapped India audience and competitors are absent there
P5-11|Video Performance Review Loop|Video|High|Video Editor; Data Analyst|Video analytics|3 hrs/wk ongoing|Internal|YouTube Studio; Meta Ads; Looker|P13-07|Weekly video insight sheet|3s retention >=55% and improving month on month|30|999|Review 3-second hook retention, view duration, CTR and install attribution weekly|The 3-second hook rate is the highest-leverage number in the video funnel
P5-12|Video Asset Library & Rights Management|Video|Medium|Video Editor|Asset management|2 days|Rs 5,000/mo|Frame.io; Google Drive; Epidemic Sound|P5-01|Tagged library + licence register|100% assets tagged; 0 copyright claims|30|31|Build a tagged library of footage, b-roll, music licences, releases and final assets|Prevents re-shooting what you own and prevents strikes from unlicensed music
P6-01|Paid Media Strategy & Channel Mix|Paid|High|Performance Marketer; Growth Manager|Media planning|3 days|Internal|Google Sheets|P13-01|Paid media plan + budget model|Plan approved; 20% testing budget ring-fenced|1|3|Define channel mix, funnel stages, budget split, target CPI/CPR and scale-or-kill rules|Without pre-agreed rules budgets get spent on whatever looked good last week
P6-02|Tracking & Attribution Wiring|Paid|High|Performance Marketer; Mobile Developer|MMP; SKAdNetwork; CAPI|5 days|Included in Phase 13|AppsFlyer; GA4; Meta Events Manager|P13-01; P13-03|Attribution QA doc with all channels verified|100% install plus 6 post-install events attributed|3|8|Connect the MMP to Google, Meta and Apple Search Ads and configure conversion values and CAPI|Every rupee spent before attribution is live is unmeasurable and effectively wasted
P6-03|Audience & Segment Definition|Paid|High|Performance Marketer; Data Analyst|Audience strategy|2 days|Internal|Meta Ads Manager; Google Ads|P6-02|Audience library doc + built audiences|12 audiences live; lookalikes seeded on active groups|8|10|Build interest, lookalike and retargeting audiences seeded from active users not installers|Seeding lookalikes from active users rather than installers is the key CPI lever
P6-04|Creative Testing Framework|Paid|High|Performance Marketer|Experiment design|2 days|Internal|Google Sheets; Meta Ads|P6-01|Testing framework + naming convention|>=10 creative tests/month with documented winners|8|10|Standardise naming, one-variable testing, minimum spend per variant and decision thresholds|Turns creative from opinion into a data pipeline and keeps results readable months later
P6-05|Landing / Store Page Matching|Paid|High|Performance Marketer; ASO Specialist|CRO|2 days|Internal|App Store Connect; Play Console|P1-30; P1-31|Campaign-to-destination mapping sheet|100% campaigns mapped; paid CVR +20%|44|45|Map each campaign to a matching custom product page, custom store listing or web landing page|Message-match between ad and destination is worth 20-40% conversion lift for zero extra spend
P6-06|Google App Campaign — Install (tCPI)|Paid|High|Performance Marketer; Video Editor|UAC; creative operations|3 days setup then ongoing|Rs 40,000+/mo media|Google Ads|P6-02; P5-08|Live UAC campaign + asset library|CPI <= Rs 25; >=1,500 installs/mo at base budget|10|999|Launch UAC for installs across all networks with 5 headlines, 5 descriptions, 20 images and 8 videos|UAC is the highest-volume install source in India and needs asset variety not bid tinkering
P6-07|Google App Campaign — In-App Action (tCPA)|Paid|High|Performance Marketer|UAC; event optimisation|2 days then ongoing|Rs 30,000+/mo media|Google Ads; AppsFlyer|P6-06; P13-04|Live tCPA campaign|Cost per registration <= Rs 45; D7 within 5pp of organic|20|999|Run a second UAC optimising for registration and first expense added rather than raw installs|Optimising for installs buys cheap junk; optimising for activation buys users who retain
P6-08|Google App Campaign — Re-engagement|Paid|Medium|Performance Marketer; Mobile Developer|Deep links; remarketing|2 days then ongoing|Rs 15,000+/mo media|Google Ads; Firebase|P3-04; P13-03|Live re-engagement campaign|Cost per reactivation <= Rs 18|45|999|Run deep-linked campaigns targeting lapsed installers into specific in-app screens|Reactivating a lapsed user costs a fraction of acquiring a new one and lifts MAU immediately
P6-09|Google Search — Brand Defence|Paid|High|Performance Marketer|Search ads|1 day then ongoing|Rs 5,000/mo media|Google Ads|P3-03|Brand campaign live|Brand impression share >=95%; CPC <= Rs 4|12|999|Bid on brand terms and misspellings to defend against competitor conquesting|Competitors bidding on your brand steal your hardest-earned demand at your expense
P6-10|Google Search — Non-Brand & Competitor|Paid|Medium|Performance Marketer; SEO Specialist|Search ads|2 days then ongoing|Rs 20,000/mo media|Google Ads|P3-05; P3-06|Search campaigns live|CPA <= Rs 60; CVR >=15%|30|999|Run campaigns on category and competitor terms driving to web landing pages|Captures explicit bottom-funnel demand - the highest-intent traffic money can buy
P6-11|Google Demand Gen / Display|Paid|Low|Performance Marketer; Graphic Designer|Display advertising|2 days then ongoing|Rs 15,000/mo media|Google Ads|P6-03|Demand Gen campaign live|CPM <= Rs 60; view-through installs tracked|50|999|Run Demand Gen across Discover, Gmail and YouTube feeds with lifestyle creative|Cheap reach that warms audiences and improves efficiency of bottom-funnel campaigns
P6-12|YouTube Video Action Campaigns|Paid|Medium|Performance Marketer; Video Editor|YouTube ads|2 days then ongoing|Rs 25,000/mo media|Google Ads; YouTube|P5-02; P5-04|YouTube campaigns live|CPI <= Rs 30; view rate >=25%|40|999|Run skippable in-stream and in-feed video ads using promo, demo and UGC creative|YouTube gives storytelling room static formats cannot and India CPMs are among the cheapest
P6-13|Meta Business Setup & SDK/CAPI|Paid|High|Performance Marketer; Mobile Developer|Meta infrastructure|2 days|Internal|Meta Business Suite|P6-02|Verified Meta setup + event QA|Events verified; AEM priority configured|5|7|Configure Business Manager, pixel, app events via MMP, AEM priority order and domain verification|AEM priority order decides which iOS events you can see; getting it wrong blinds the account
P6-14|Meta App Install Campaigns (Advantage+)|Paid|High|Performance Marketer|Meta ads|3 days then ongoing|Rs 50,000+/mo media|Meta Ads Manager|P6-13; P5-08|Live Advantage+ App campaigns|CPI <= Rs 20; cost per registration <= Rs 40|12|999|Run Advantage+ App Campaigns on broad targeting optimising for installs then app events|Meta's algorithm outperforms manual targeting; the lever is creative volume and event quality
P6-15|Instagram Reels-First Creative Campaigns|Paid|High|Performance Marketer; Video Editor|Reels ads|2 days then ongoing|Shared media budget|Meta Ads Manager|P4-06; P5-06|Reels ad sets live|Reels CPI <= Rs 18; >=40% of Meta spend|18|999|Build dedicated 9:16 native-feeling ad sets for Reels and Stories placements|Reels is the cheapest quality inventory on Meta but only native-feeling creative works there
P6-16|Meta Retargeting & App Event Campaigns|Paid|High|Performance Marketer|Retargeting|2 days then ongoing|Rs 15,000/mo media|Meta Ads Manager|P6-03|Retargeting campaigns live|CPA <= Rs 20; 3x better than cold|25|999|Retarget site visitors, video viewers, IG engagers and installed-not-registered users|The cheapest conversions in any account; warm audiences convert 3-5x better
P6-17|Meta Lookalike Scaling|Paid|High|Performance Marketer; Data Analyst|Audience modelling|2 days then ongoing|Shared media budget|Meta Ads Manager; MMP|P6-03; P13-05|Lookalike audience set live|LAL campaigns beat broad CPI by >=15%|35|999|Build 1/3/5% lookalikes from high-value seeds such as users in 2+ active groups|Seed quality separates a Rs 18 CPI from a Rs 40 one
P6-18|Meta Creative Refresh Cadence|Paid|High|Performance Marketer; Video Editor|Creative operations|3 hrs/wk ongoing|Included in P5-08|Meta Ads Manager|P5-08|Weekly creative refresh log|>=5 new creatives/week; CPI stable at 2x spend|25|999|Inject 5 new creatives weekly and pause ads above 2.5 frequency or 30% CTR decay|Meta creative fatigue in India hits within 10-14 days; cadence keeps CPI flat as spend scales
P6-19|Apple Search Ads — Brand Campaign|Paid|High|Performance Marketer|Apple Search Ads|1 day then ongoing|Rs 8,000/mo media|Apple Search Ads Advanced|P6-02|Brand campaign live|Tap-through rate >=55%; CPA <= Rs 35|14|999|Run exact-match brand terms at high bid to own your own listing|ASA brand traffic converts above 60% TTR and is the cheapest install in any iOS account
P6-20|Apple Search Ads — Generic & Discovery|Paid|High|Performance Marketer; ASO Specialist|ASA structure|2 days then ongoing|Rs 25,000/mo media|Apple Search Ads|P6-19; P1-03|Generic and discovery campaigns live|CPA <= Rs 70; 20 winning terms graduated/month|16|999|Run discovery to mine terms then graduate winners into exact-match generic campaigns|The discovery-to-exact loop is the core ASA growth mechanic and feeds ASO research
P6-21|Apple Search Ads — Competitor Campaign|Paid|Medium|Performance Marketer|Apple Search Ads|1 day then ongoing|Rs 15,000/mo media|Apple Search Ads|P1-30|Competitor campaign live|CPA <= Rs 100; CVR >=25%|46|999|Bid on competitor brand terms paired with a comparison-focused custom product page|Intercepts users at the exact moment they are looking for a competitor
P6-22|Alternative Networks Test|Paid|Low|Performance Marketer|Media buying|3 days|Rs 30,000 test budget|Snap Ads; ShareChat Ads; Moj|P6-04|Test results memo|Test complete; scale if CPI <= Rs 15|60|65|Ring-fenced tests on Snap, ShareChat, Moj and Josh for tier-2/3 reach|Vernacular platforms deliver very low CPI where competitor spend is near zero
P6-23|Weekly Paid Optimisation Ritual|Paid|High|Performance Marketer|Media buying|4 hrs/wk ongoing|Internal|All ad platforms; Looker Studio|P6-06; P6-14; P6-19|Weekly optimisation log|Ritual completed 100% of weeks|15|999|Fixed Monday routine of budget reallocation, creative pause/scale, bids, negatives and anomalies|Discipline beats cleverness in paid; the ritual prevents slow budget leakage
P6-24|Incrementality & MMM Check|Paid|Medium|Data Analyst; Performance Marketer|Experiment design; statistics|5 days|Rs 20,000|Geo-holdout; Looker Studio|P13-07|Incrementality report|Run quarterly; incrementality ratio published|80|85|Run a quarterly geo-holdout pausing paid in matched regions to measure true incremental installs|Attribution over-credits paid; incrementality is the only way to know real CAC
P7-01|Influencer Strategy & Tier Model|Influencer|High|Influencer Manager; Growth Manager|Influencer strategy|2 days|Internal|Notion; Google Sheets|P2-07|Influencer strategy doc + tier budget model|Strategy approved; 40% of budget on micro tier|1|2|Define nano, micro, mid and macro tiers with a 40/35/20/5 budget split favouring micro|Micro creators deliver 3-5x better engagement-to-cost for installs than macro
P7-02|Creator Discovery & Database Build|Influencer|High|Influencer Manager|Research; sourcing|6 days|Rs 12,000/mo tool|Modash; Phyllo; Collabstr|P7-01|Creator database (500 profiles, scored)|500 creators; 150 shortlisted|3|10|Build a 500-creator database across finance, student, travel, comedy and tech verticals|Discovery is the bottleneck; a pre-built scored database turns launch from weeks into days
P7-03|Creator Vetting & Fraud Screening|Influencer|High|Influencer Manager; Data Analyst|Audience auditing|3 days|Included in tool|Modash; HypeAuditor|P7-02|Vetted shortlist (150 creators)|>=85% real-follower score on all signed creators|10|13|Screen for fake followers, engagement pods, geography mismatch and brand-safety risk|India's creator market has significant fraud; unvetted spend delivers zero installs at full price
P7-04|Outreach Sequence & Templates|Influencer|High|Influencer Manager; Content Writer|Outreach copywriting|2 days|Rs 4,000/mo|Instagram; Gmail; Lemlist; Notion CRM|P7-03|Outreach sequences + creator CRM|30% response rate; 60 conversations opened|12|14|Build a 4-touch outreach sequence with personalised templates per vertical|Creator outreach response rates are 5-15%; sequencing and personalisation triple that
P7-05|Rate Card & Negotiation Playbook|Influencer|High|Influencer Manager; CMO|Negotiation|2 days|Internal|Google Sheets|P7-02|Rate benchmark sheet + negotiation playbook|Average rate at or below benchmark; 100% deals include paid usage rights|12|14|Benchmark rates by tier and vertical and define negotiable terms and walk-away prices|Paid usage rights are worth more than the post - winning creator videos run as ads for months
P7-06|Micro-Influencer Campaign — Batch 1 (25)|Influencer|High|Influencer Manager|Campaign management|3 weeks|Rs 1,25,000|Creator CRM; Branch links|P7-04; P7-05; P13-03|25 creator campaigns live|8,000+ installs; effective CPI <= Rs 18|15|35|Sign 25 micro creators for 1 reel and 2 stories each with unique tracking links and codes|The core volume engine - 25 micro creators outperform 2 macro creators at half the cost
P7-07|Finance Creator Partnerships (8)|Influencer|High|Influencer Manager|Partnership management|4 weeks|Rs 1,60,000|YouTube; Instagram|P7-05|8 integrated finance collaborations|6,000 installs; D7 retention >=28%|25|55|Run longer-form integrated segments with personal-finance creators rather than 15-second reads|Finance creators transfer trust which drives registration and retention above average
P7-08|Student / Campus Creator Programme (40)|Influencer|High|Influencer Manager; Community Manager|Programme management|4 weeks|Rs 80,000|Google Forms; Branch; WhatsApp|P13-03|40 campus creators onboarded|10,000 registrations; CPA <= Rs 40|20|50|Recruit 40 campus creators across 20 colleges on a per-registration performance model|Students are the core segment and cheapest creator inventory; performance pricing removes risk
P7-09|Travel Creator Partnerships (10)|Influencer|Medium|Influencer Manager|Partnership management|3 weeks|Rs 1,00,000|Instagram; YouTube|P7-05|10 travel collaborations|5,000 installs; group creation rate >=60%|40|65|Partner with travel creators for authentic trip-planning content showing real splitting|Travel is the highest-value use case and the most natural product demo context
P7-10|Comedy / Relatable Creator Collabs (10)|Influencer|Medium|Influencer Manager; Video Editor|Creative briefing|3 weeks|Rs 90,000|Instagram; YouTube Shorts|P7-05|10 comedy collaborations|3M+ combined reach; 6,000 installs|45|70|Commission sketch content on the "friend who never pays back" trope|Humour drives reach finance content cannot and produces your best paid ad creative
P7-11|Affiliate / Performance Creator Programme|Influencer|High|Influencer Manager; Backend Developer|Affiliate operations|5 days build then ongoing|Rs 15,000 setup + variable|Branch; Tolt; custom dashboard|P8-02; P13-03|Live affiliate programme + creator dashboard|100 active affiliates by Day 90; CPA <= Rs 40|30|999|Build an always-on self-serve programme paying per verified registration plus volume bonuses|Converts creator marketing from fixed cost into risk-free variable CAC that scales without headcount
P7-12|Creator Brief & Asset Kit|Influencer|High|Influencer Manager; Content Writer|Briefing|2 days|Internal|Notion; Figma|P2-06|Creator brief kit|100% creators briefed; under 10% reshoot rate|13|14|Build a standard brief with dos and don'ts, proven hooks, key messages, ASCI disclosure and assets|Bad briefs produce unusable content; the brief separates a Rs 5,000 dud from a Rs 5,000 winner
P7-13|Influencer Tracking & Attribution|Influencer|High|Influencer Manager; Data Analyst|Attribution|3 days|Included in Phase 13|Branch; AppsFlyer; Looker Studio|P13-03|Creator performance dashboard|100% creators tracked; weekly leaderboard|14|17|Issue unique deep links and promo codes per creator and dashboard through to retained users|Without per-creator attribution you cannot renew winners and cut losers - the entire game
P7-14|Whitelisting / Partnership Ads Programme|Influencer|High|Influencer Manager; Performance Marketer|Paid social; rights management|2 days then ongoing|Media budget|Meta Ads Manager|P7-05; P7-06|Whitelisted ad campaigns live|>=10 creators whitelisted; CPI 25% below brand ads|40|999|Secure paid usage rights and run creator content as ads from their own handles|Creator-handle ads consistently beat brand-handle ads on CTR and CPI by 30-50%
P7-15|Creator Relationship & Renewal Programme|Influencer|Medium|Influencer Manager|Relationship management|Ongoing|Rs 60,000/mo|Creator CRM|P7-13|Ambassador roster (10 creators)|10 ambassadors retained; 40% of installs from repeat creators|60|999|Convert the top 20% of performers into retained ambassadors with early feature access|Repeat creator content outperforms one-offs because audiences need 3+ exposures to convert
P8-01|Viral Loop Audit & K-Factor Baseline|Referral|High|Product Manager; Data Analyst|Funnel analysis|3 days|Internal|Mixpanel; Firebase|P13-02|Viral loop map + K-factor baseline|Baseline K measured; top 3 leaks identified|1|3|Map every invite surface and measure invites per user, invite-to-install and install-to-registration|You cannot improve virality you have not measured; most invite flows leak 70% at one step
P8-02|Referral Infrastructure Build|Referral|High|Backend Developer; Mobile Developer|Backend; Branch SDK|10 days|Rs 80,000|Branch or AppsFlyer OneLink; Firebase|P3-04; P13-03|Referral system live in production|System live; 100% referrals attributed; fraud under 2%|4|17|Build referral codes, deferred deep links, attribution, fraud checks, reward ledger and admin console|Everything else in this phase depends on it and a fragile backend produces disputes and fraud
P8-03|Invite Flow Redesign (In-App)|Referral|High|Product Manager; Mobile Developer; Graphic Designer|UX design; Flutter|8 days|Rs 50,000|Figma; Flutter|P8-02|New invite flow shipped|Invite-to-install rate 15% to 35%|15|25|Redesign invites with one-tap WhatsApp share, contact picker and group-preview deep links|A group invite showing the pending amount converts 3-4x better than a generic link
P8-04|Reward Structure Design|Referral|High|Product Manager; Growth Manager; Finance|Incentive design; unit economics|3 days|Internal|Google Sheets model|P8-01|Reward structure + unit economics model|Reward CAC <= Rs 60; LTV to reward ratio >=4:1|10|12|Design a two-sided capped reward for referrer and referee with verification gates|Two-sided rewards beat one-sided by ~40% and caps protect against reward farming
P8-05|Referral Programme Launch|Referral|High|Growth Manager; CRM Executive; Social Media Manager|Campaign management|5 days|Rs 25,000|CleverTap; Figma; social channels|P8-02; P8-03; P8-04|Launch campaign live|25% of MAU aware; 12% send >=1 invite in month 1|26|30|Launch with in-app announcement, push, email, social and an explainer landing page|A referral programme nobody knows about earns nothing; launch is a campaign not a toggle
P8-06|Gamification Layer|Referral|High|Product Manager; Mobile Developer; Graphic Designer|Gamification design|8 days|Rs 45,000|Flutter; Figma; Lottie|P8-05|Gamification shipped|Average invites per user 1.2 to 3.0; milestone completion >=25%|35|45|Add referral milestones, progress bars, badges, streaks and a premium unlock ladder|Progress mechanics lift completion of multi-step behaviours like referrals by 30-60%
P8-07|Referral Leaderboard & Contests|Referral|Medium|Growth Manager; Community Manager|Community management|4 days|Rs 30,000/mo prizes|In-app; Firebase; social|P8-06|Live leaderboard + monthly contest|Top-100 referrers drive >=30% of referred installs|45|999|Run a public monthly leaderboard and quarterly cash-prize referral contests|Competition activates super-referrers who typically drive 40%+ of all referral volume
P8-08|Group Virality Optimisation|Referral|High|Product Manager; Backend Developer; Mobile Developer|Product growth engineering|6 days|Rs 40,000|Flutter; WhatsApp Business API|P8-02|Non-user invite flow live|Non-user invite-to-install >=40%; K-factor +0.2|30|38|When a user adds a non-user to a group, send a contextual WhatsApp/SMS deep link into that group|This is organic virality with no reward cost - the highest-margin growth in the product
P8-09|Shareable Moments (Viral Artefacts)|Referral|High|Product Manager; Mobile Developer; Graphic Designer|Product design; Flutter|7 days|Rs 40,000|Flutter; Figma|P2-06|4 shareable artefacts live|20% of active users share monthly; 5,000 installs/mo|40|50|Auto-generate shareable trip summaries, monthly wraps, settle-up receipts and year-in-review cards|Turns normal usage into distribution because users share content that is about them
P8-10|Referral Fraud Prevention|Referral|High|Backend Developer; Data Analyst|Fraud prevention|5 days|Rs 25,000|Firebase App Check; MMP fraud tools|P8-02|Fraud rules live + review dashboard|Fraudulent reward rate under 2%|20|25|Add device fingerprinting, phone verification, reward-on-qualified-action, velocity limits and review queue|Unprotected referral programmes in India get farmed within weeks and burn a quarter's budget
P8-11|Referral Funnel Optimisation Loop|Referral|High|Growth Manager; Product Manager|Experimentation|6 hrs/wk ongoing|Internal|Firebase Remote Config; Mixpanel|P8-05|Monthly referral experiment log|2 experiments/month; K-factor +0.05/month|50|999|Continuously A/B test invite copy, reward amount, placement, timing and channel|Referral funnels have 5+ steps and each 10% improvement compounds multiplicatively into K
P8-12|Referral Analytics Dashboard|Referral|High|Data Analyst|Dashboarding|3 days|Internal|Looker Studio; Mixpanel|P8-02; P13-05|Live referral dashboard|Dashboard live and reviewed weekly|25|28|Dashboard invites, CTR, install rate, K-factor, viral cycle time, reward cost and cohort quality|Viral cycle time matters as much as K-factor; halving it doubles effective growth rate
P9-01|Community Strategy & Platform Selection|Community|High|Community Manager; Growth Manager|Community strategy|2 days|Internal|Notion|P2-08|Community strategy doc + rules|Strategy approved; 2 primary platforms chosen|1|2|Choose primary versus secondary platforms and define purpose, rules, moderation and cadence|Communities fail from unclear purpose more than low numbers
P9-02|Reddit Presence & Value-First Programme|Community|High|Community Manager|Reddit literacy; authentic writing|5 hrs/wk ongoing|Internal|Reddit; F5Bot|P9-01|Weekly Reddit activity log + AMA|40 threads/quarter; 2,000 referred sessions/mo|5|999|Answer 10 threads weekly across India and personal finance subreddits and run an AMA at Day 60|Reddit content ranks in Google and users are influential recommenders but punish marketing
P9-03|Discord Server Launch|Community|Medium|Community Manager|Discord administration|4 days|Rs 5,000|Discord; MEE6|P9-01|Live Discord server|2,000 members by Day 90; 15% weekly active|10|14|Launch a server with announcements, feature requests, bugs, tips, campus and off-topic channels|Discord suits the student and tech segment and gives a real-time feedback and beta surface
P9-04|Telegram Channel + Group|Community|Medium|Community Manager|Telegram administration|2 days|Internal|Telegram|P9-01|Live channel + discussion group|8,000 channel members by Day 90|12|14|Run a broadcast channel for updates plus a discussion group for power users|Telegram has deep penetration in Indian student and tech communities with near-100% delivery
P9-05|WhatsApp Community|Community|High|Community Manager|WhatsApp administration|3 days|Internal|WhatsApp Communities|P4-16|Live WhatsApp Community|10,000 members by Day 90; 40% weekly active|15|18|Launch a WhatsApp Community with topic groups for students, travel, roommates and beta testers|WhatsApp is where users already coordinate group expenses so presence is native not intrusive
P9-06|Facebook Groups Strategy|Community|Medium|Community Manager|Facebook group management|5 hrs/wk ongoing|Internal|Facebook|P9-01|Own group + participation log|Own group at 5,000 members; 300 installs/mo from groups|20|999|Run a "Smart Money India" group and participate in 20 existing travel, flatmate and city groups|Facebook Groups remain the biggest peer-recommendation surface for 25-40 and tier-2 India
P9-07|Community Content Calendar|Community|High|Community Manager; Content Writer|Community programming|2 days|Internal|Notion; Buffer|P9-03; P9-05|90-day community calendar|Calendar executed in >=90% of weeks|18|20|Set a weekly rhythm of Monday tip, Wednesday AMA, Friday spotlight and Sunday challenge|Predictable rituals convert a chat group into a community people return to
P9-08|Ambassador / Power User Programme|Community|High|Community Manager; Influencer Manager|Programme design|6 days|Rs 35,000/mo|Notion; Discord; WhatsApp|P9-03; P9-05|50 ambassadors onboarded|50 active; 20% of UGC from ambassadors|25|35|Recruit 50 power users with early access, swag, founder access and referral bonuses|Ambassadors generate UGC, moderate, evangelise and give honest feedback at near-zero cost
P9-09|College Campus Programme|Community|High|Community Manager; Influencer Manager|Business development; events|6 weeks|Rs 1,20,000|Email; WhatsApp; event kits|~P7-08|20 college partnerships live|20 campuses; 15,000 student registrations|25|70|Partner with 20 colleges on ambassadors, fests, hostel activations and orientation presence|Colleges are dense high-referral-velocity networks; one hostel floor can produce 200 users
P9-10|Startup & Tech Community Presence|Community|Medium|CMO; Community Manager|Networking|4 hrs/wk ongoing|Rs 15,000/mo|LinkedIn; Luma; meetups|P2-01|Monthly community engagement log|4 events/quarter; 3 partnerships generated|30|999|Maintain presence in Headstart, TiE, Product Folks and local city startup meetups|Generates PR, partnerships, hiring pipeline and early adopters who give the best feedback
P9-11|Offline Activations & Events|Community|Medium|Community Manager; Marketing Manager|Event marketing|Ongoing|Rs 40,000/mo|Event kits; QR codes; Branch|~P9-09|4 activations per month|4/month; 1,500 installs/month; CPI <= Rs 25|45|999|Run split-the-bill activations at cafes, co-living spaces, hostels and travel meetups|Offline creates high-intent installs plus content at the exact moment of splitting
P9-12|Community Health & Reporting|Community|Medium|Community Manager; Data Analyst|Analytics|1 day/month|Internal|Looker Studio; Discord analytics|P13-07|Monthly community report|Report monthly; 20% weekly active across communities|30|999|Track member growth, community DAU/WAU, sentiment, contributors and attributed installs|Community effort is easy to run without accountability; metrics keep it a growth channel
P10-01|PR Strategy & Story Angles|PR|High|PR Executive; CMO|PR strategy|3 days|Internal|Notion|-|PR strategy + 8 angle briefs|8 angles approved; 2 pitched per month|1|3|Develop eight story angles across founder story, data, category and milestone narratives|Journalists cover stories not apps; an angle bank means you always have something newsworthy
P10-02|Press Kit / Media Room|PR|High|PR Executive; Graphic Designer|PR writing; design|3 days|Rs 15,000|Next.js; Figma|P2-02; P3-03|Live press page + downloadable kit|Press page live; >=50 kit downloads per quarter|4|7|Build a press page with boilerplate, bios, logos, screenshots, video, fact sheet and contact|Removes friction for journalists on deadline; missing assets is why coverage gets cut
P10-03|Journalist & Media Database|PR|High|PR Executive|Media research|4 days|Rs 8,000/mo|Muck Rack; LinkedIn|P10-01|Media database (200 beat-tagged contacts)|200 contacts; 100% beat-matched|5|9|Build a 200-contact database across Indian tech, personal finance, student and regional media|Targeted pitching to 200 relevant journalists beats blasting 2,000 irrelevant ones
P10-04|Press Release — Milestone / Launch|PR|High|PR Executive; Content Writer|PR writing|3 days|Rs 25,000 distribution|PRNewswire India; NewsVoir; EIN|P10-02; P10-03|Press release + distribution report|15+ pickups; 10 backlinks|12|15|Write and distribute a data-led milestone release with syndication|Data-led releases get picked up where feature-led releases get ignored
P10-05|Media Outreach Campaign (Monthly)|PR|High|PR Executive|Pitching; relationship building|10 hrs/wk ongoing|Internal|Gmail; Muck Rack|P10-03; P10-04|Monthly outreach + coverage log|40 pitches/month; 5 placements/month|15|999|Send 40 personalised pitches monthly with 3-touch follow-up and tier-1 exclusives|Exclusives to top outlets earn far better placement than blanket releases and cost nothing
P10-06|Product Hunt Launch|PR|High|CMO; PR Executive; Community Manager|Product Hunt strategy|2 weeks preparation|Rs 20,000|Product Hunt; Discord; WhatsApp|P5-04; P9-05|Product Hunt launch executed|Top 5 Product of the Day; 2,000+ visits; 500 installs|30|45|Run a full PH launch with hunter outreach, assets, first-comment story and community mobilisation|A top-5 finish delivers a durable high-DR backlink, quality signups and downstream press
P10-07|Startup Directory Submissions (60)|PR|High|PR Executive; SEO Specialist|Link building|4 days|Rs 10,000|Directory list; Ahrefs|P10-02|60 live directory listings|60 submitted; 40 live; DR +8|20|25|Submit to 60 directories including BetaList, AlternativeTo, G2, Capterra and SaaSHub|Cheap permanent backlinks plus long-tail referral traffic and alternative-to discovery
P10-08|Tech Blog & Niche Publication Outreach|PR|High|PR Executive; Content Writer|Guest posting|6 hrs/wk ongoing|Rs 20,000/mo|Ahrefs; Hunter.io|P10-03|4 guest posts per month|4/month published; 12 referring domains/month|25|999|Place guest posts and reviews on personal finance, student, travel and Indian tech blogs|Niche placements convert better than mass media and give contextually relevant backlinks
P10-09|Founder Thought Leadership|PR|Medium|CMO; PR Executive|Thought leadership|5 hrs/wk ongoing|Rs 10,000/mo|LinkedIn; podcast outreach|P4-11|2 podcasts + 1 byline per month|6 podcasts and 3 bylines per quarter|30|999|Position the founder as a voice on India's shared-money culture via podcasts, panels and columns|Founder-led PR compounds because journalists return to sources they have used before
P10-10|Data-Led PR Reports (Quarterly)|PR|High|Data Analyst; PR Executive; Content Writer|Data storytelling|10 days|Rs 40,000/quarter|Python; Looker Studio; Figma|P13-05|Quarterly data report + press push|1 report/quarter; 20 pickups; 30 backlinks|60|75|Publish original anonymised data reports such as India's Friend Debt Report|Original data is the most reliably covered PR asset and generates dozens of backlinks
P10-11|Awards & Recognition Programme|PR|Medium|PR Executive|Awards writing|3 days/quarter|Rs 25,000 entry fees|Award portals|P10-02|8 award applications per year|8 applications; >=2 shortlists|50|999|Apply to Google Play Best of, App Store Awards, ET Startup Awards and YourStory Tech30|Awards are trust signals for users, press, investors and store editorial teams
P10-12|Store Featuring Pitch (Apple + Google)|PR|High|ASO Specialist; PR Executive|Editorial pitching|3 days|Internal|Apple and Google nomination forms|P1-24; P5-02|Featuring nominations submitted|Nominated quarterly; >=1 feature within 365 days|40|999|Pitch Apple and Google editorial via nomination forms highlighting design and India relevance|Store featuring can deliver 50K-500K installs in a week at zero cost
P10-13|Crisis Communication Playbook|PR|Medium|PR Executive; CMO; Legal|Crisis communications|2 days|Internal|Notion|P2-08|Crisis playbook + escalation tree|Playbook approved; 1 tabletop drill run|45|46|Pre-write response protocols for privacy incidents, outages, viral criticism and store removal|In fintech the first two hours of a crisis determine the outcome
P10-14|PR Measurement & Coverage Tracking|PR|Medium|PR Executive; Data Analyst|Media measurement|1 day/month|Rs 5,000/mo|Google Alerts; Ahrefs; GSC|P3-12|Monthly PR report|5 placements/month; branded search +20% QoQ|30|999|Track placements, reach, share of voice, referral traffic, backlinks and branded search lift|PR is measurable via branded search volume and referring domains
P11-01|CRM Platform Setup|CRM|High|CRM Executive; Mobile Developer; Backend Developer|CRM platform; SDK integration|6 days|Rs 18,000/mo|CleverTap; MoEngage; Braze|P13-01|Live CRM with 30 events and 12 attributes|Platform live; events verified|1|8|Implement the CRM with user attributes, event streams, segments and cross-channel orchestration|A single orchestration layer prevents four disconnected tools messaging the same user four times
P11-02|Lifecycle Map & Segmentation|CRM|High|CRM Executive; Growth Manager|Lifecycle marketing|3 days|Internal|Miro; CleverTap|P11-01; P8-01|Lifecycle map + 15 segments|Map approved; segments live in CRM|8|11|Map install through churn and define 15 lifecycle segments|Segment-blind messaging is the main cause of unsubscribes and defines every later campaign
P11-03|Email Deliverability Foundation|CRM|High|CRM Executive; Backend Developer|Email infrastructure|2 days|Internal|SendGrid or SES; MXToolbox|P11-01|Authenticated sending domain|Inbox placement >=95%; bounce under 2%|8|10|Configure SPF, DKIM, DMARC, a dedicated subdomain, warm-up and list hygiene|Emails landing in spam are worse than none because they poison domain reputation permanently
P11-04|Welcome Series (5 emails)|CRM|High|CRM Executive; Content Writer; Graphic Designer|Lifecycle copywriting|4 days|Rs 15,000|CleverTap; Figma|P11-02; P2-08|5-email welcome series live|Open >=45%; activation +18pp|12|16|Build Day 0 to Day 7 welcome emails from value through first group to invite and insights|The first week determines lifetime retention; the highest-ROI CRM asset there is
P11-05|Activation Nudge Series|CRM|High|CRM Executive|Behavioural triggers|4 days|Internal|CleverTap|P11-02|6 triggered journeys live|Step conversion +15pp per stuck segment|16|20|Trigger nudges for users stuck at registered-no-group, group-no-expense and expense-no-settle|Targets the exact drop-off point rather than broadcasting - the highest-converting CRM programme
P11-06|Referral Email Campaigns|CRM|High|CRM Executive; Content Writer|Campaign design|3 days|Internal|CleverTap|P8-05|5 referral email flows live|>=12% of recipients send an invite|30|33|Build announce, reminder, milestone, leaderboard and reward-earned flows|Referral programmes need continuous reminder pressure; one-time announcements decay in days
P11-07|Retention & Engagement Campaigns|CRM|High|CRM Executive; Content Writer|Retention marketing|5 days|Internal|CleverTap|P11-02|8 retention campaigns live|D30 retention 6% to 12%; reactivation >=8%|20|26|Build weekly digest, feature education drips, seasonal campaigns and 14/30/60-day re-engagement|Retention is where LTV is made; 5pp of D30 beats a 20% CPI reduction
P11-08|Monthly Money Report Email|CRM|High|CRM Executive; Backend Developer; Graphic Designer|Dynamic email; data|6 days|Rs 20,000|CleverTap; backend job|P13-05|Automated monthly report email|Open >=55%; app-open >=25%; share rate >=8%|35|42|Send a personalised monthly report with spend, splits, categories, biggest group and share card|Personalised data emails get 2-3x normal open rates and drive re-engagement plus organic sharing
P11-09|WhatsApp CRM Journeys|CRM|High|CRM Executive; Backend Developer|WhatsApp Business API|6 days|Rs 15,000/mo|Gupshup; WATI; Interakt|P11-01|5 WhatsApp journeys live|Opt-in >=40% of users; open >=75%|45|52|Replicate settle-up reminders, referral nudges and monthly reports on WhatsApp with opt-in|WhatsApp open rates in India are 70-90% versus email's 25-45%
P11-10|Email Capture & List Growth|CRM|Medium|CRM Executive; SEO Specialist|Lead generation|3 days|Internal|ConvertKit or Beehiiv; Next.js|P3-18|Capture points live + lead magnets|10,000 subscribers by Day 90|25|28|Capture emails via newsletter, calculators, blog CTAs, profile completion and lead magnets|Your list is the only audience you own and insurance against platform risk
P11-11|Newsletter — Money Between Friends|CRM|Medium|Content Writer; CRM Executive|Newsletter writing|4 hrs/wk ongoing|Internal|Beehiiv; Substack|P11-10|Weekly newsletter live|12 issues/quarter; open >=40%; CTR >=6%|30|999|Publish a weekly newsletter with one money idea, one product tip and one community story|Builds brand affinity beyond transactional messaging and creates a launch distribution channel
P11-12|CRM Experimentation Programme|CRM|High|CRM Executive; Data Analyst|Experimentation|5 hrs/wk ongoing|Internal|CleverTap; Mixpanel|P11-04|Monthly CRM experiment log|4 tests/month; >=1 winner/month|30|999|Continuously test subject lines, send times, channel choice, frequency caps and tone|Frequency and timing errors cause opt-outs; testing finds the ceiling without burning the list
P12-01|Push Infrastructure & Permission Strategy|Push|High|Mobile Developer; CRM Executive|Flutter; FCM; APNs|4 days|Internal|Firebase; CleverTap|P11-01|Push infrastructure + soft prompt shipped|Opt-in >=65% iOS and >=90% Android|5|9|Implement push via the CRM and replace the cold system prompt with a soft in-app pre-prompt|Once a user denies push on iOS you may never get them back; pre-prompts lift opt-in 40% to 70%
P12-02|Notification Taxonomy & Frequency Caps|Push|High|CRM Executive; Product Manager|Lifecycle strategy|2 days|Internal|CleverTap|P12-01|Push taxonomy + cap rules live|Opt-out under 4%; uninstall rate stable|9|11|Categorise pushes and set caps of 1/day and 4/week promotional with 10pm-8am quiet hours|Uncontrolled push volume is the top driver of uninstalls; caps protect the channel's value
P12-03|Notification Preference Centre|Push|Medium|Mobile Developer; Product Manager|Flutter; UX|4 days|Rs 20,000|Flutter; CleverTap|P12-02|Preference centre shipped|Full opt-out reduced by 40%|30|34|Let users choose notification categories instead of an all-or-nothing switch|Granular control converts would-be opt-outs into partial opt-ins, preserving transactional reach
P12-04|Onboarding Push Series (Day 0-7)|Push|High|CRM Executive; Content Writer|Lifecycle copywriting|3 days|Internal|CleverTap|P12-01; P11-02|Onboarding push journey live|Day-7 activation +20pp; CTR >=15%|12|15|Send six week-one pushes mapped to create group, add expense, invite, split modes and insights|Week-one activation is the strongest predictor of D30 retention
P12-05|Settle-Up Reminder Engine|Push|High|Product Manager; Mobile Developer; Content Writer|Product design; copywriting|5 days|Rs 25,000|Flutter; CleverTap|P12-02; P2-08|Reminder engine live|35% of reminded debts settled within 7 days|18|24|Build gentle escalating reminders to both debtor and creditor with a creditor-triggered nudge|This is the app's core job-to-be-done; a well-designed nudge is a feature users actively want
P12-06|Inactive User Re-Engagement|Push|High|CRM Executive|Winback campaigns|4 days|Internal|CleverTap|P12-02|5 winback journeys live|10% of 30-day inactives reactivated monthly|24|28|Build 7, 14, 30, 60 and 90-day tiered winback journeys|Reactivating a lapsed user costs about one-fifth of acquiring a new one
P12-07|Weekly Summary Push|Push|High|CRM Executive; Backend Developer|Dynamic personalisation|4 days|Internal|CleverTap; backend job|P13-05|Weekly summary push live|CTR >=18%; Sunday DAU +25%|28|32|Send a Sunday evening personalised spend-and-pending summary|Personalised data pushes materially outperform generic ones and build a weekly habit loop
P12-08|Referral Push Campaigns|Push|High|CRM Executive; Product Manager|Trigger design|2 days|Internal|CleverTap|P8-05|4 referral push triggers live|>=8% of recipients send an invite|32|34|Trigger referral prompts after settling a debt, closing a trip group and hitting milestones|A referral ask right after a successful settle-up converts several times better than a blast
P12-09|Rich Push & In-App Messaging|Push|Medium|Mobile Developer; CRM Executive; Graphic Designer|Rich push; in-app messaging|5 days|Rs 20,000|CleverTap; Flutter|P12-01|Rich push + in-app messaging live|Feature adoption +25% on promoted features|35|40|Implement image, carousel and button pushes plus in-app modals, banners and tooltips|In-app messages reach 100% of active users without permission and beat push for feature adoption
P12-10|Push Optimisation & Testing Loop|Push|High|CRM Executive; Data Analyst|Experimentation|4 hrs/wk ongoing|Internal|CleverTap; Mixpanel|P12-04|Monthly push experiment log|Average CTR 3% to 12%; 4 tests/month|40|999|Continuously test copy, emoji, personalisation, per-user send-time optimisation and deep links|Send-time optimisation alone commonly lifts CTR 20-30% and the rest compounds on top
P13-01|Measurement Plan & Event Taxonomy|Analytics|High|Data Analyst; Product Manager|Analytics architecture|4 days|Internal|Google Sheets; Avo; Amplitude|-|Tracking Plan (60 events, 25 properties)|Plan signed off by Product and Growth|1|4|Define every event, property and user attribute with naming conventions and owners|Retrofitting analytics later means months of unusable historical data
P13-02|Firebase Analytics Implementation|Analytics|High|Mobile Developer; Data Analyst|Flutter; Firebase|5 days|Free|Firebase; DebugView|P13-01|Firebase live with 60 events|100% of plan events firing; 0 naming violations|5|10|Implement Firebase Analytics in Flutter per the tracking plan with debug validation|Firebase is free, feeds Google Ads optimisation directly and is the reconciliation baseline
P13-03|MMP Implementation (AppsFlyer or Adjust)|Analytics|High|Mobile Developer; Performance Marketer|MMP integration; SKAdNetwork|6 days|Rs 25,000/mo|AppsFlyer; Adjust|P13-01|MMP live + attribution QA report|All channels attributed; SKAN conversion schema live|5|12|Integrate the MMP SDK with SKAN conversion values, OneLink deep linking, fraud protection and network integrations|Attribution is the referee between channels; without it every channel claims the same install
P13-04|Mixpanel / Amplitude Product Analytics|Analytics|High|Mobile Developer; Data Analyst|Product analytics|4 days|Rs 15,000/mo|Mixpanel; Amplitude|P13-02|Mixpanel live + 8 saved funnels|Funnels live; weekly retention review running|10|14|Implement product analytics for funnels, cohorts, retention curves and path analysis|Firebase answers how many; product analytics answers why - you need both to fix activation
P13-05|Data Warehouse & Modelling|Analytics|High|Data Analyst; Backend Developer|SQL; dbt; BigQuery|8 days|Rs 12,000/mo|BigQuery; dbt; Fivetran or Airbyte|P13-02; P13-03|Warehouse + 6 modelled tables|Daily pipeline running; under 1% data variance|14|24|Pipe Firebase, MMP, CRM, ad platforms and app DB into BigQuery with modelled tables|The only way to answer cross-source questions like D90 LTV of a Meta-acquired student user
P13-06|Crashlytics & Performance Monitoring|Analytics|High|Mobile Developer|Crashlytics|2 days|Free|Crashlytics; Slack|P13-02|Crashlytics live + alerting|Crash-free users >=99.5%; alerts under 15 min|5|7|Configure Crashlytics and Performance Monitoring with Slack alerting and velocity alerts|Crashes are silent CAC destruction - a spike wipes out ratings while ads keep spending
P13-07|Looker Studio Executive Dashboard|Analytics|High|Data Analyst|Looker Studio; SQL|5 days|Free|Looker Studio; BigQuery|P13-05|Live executive dashboard|Dashboard live and used in the weekly growth meeting|24|29|Build the master dashboard covering installs, CPI, activation, retention, K-factor, ROAS and North Star|One trusted dashboard eliminates the weekly argument about whose numbers are right
P13-08|Channel-Level Dashboards (5)|Analytics|Medium|Data Analyst|Dashboarding|4 days|Free|Looker Studio|P13-07|5 channel dashboards|All 5 live and used daily by channel owners|29|33|Build ASO, Paid, Organic, Referral and CRM dashboards with drill-downs|Channel owners need daily operating views; the exec dashboard is too coarse for optimisation
P13-09|Cohort & Retention Analysis Framework|Analytics|High|Data Analyst|Cohort analysis|3 days|Internal|Mixpanel; BigQuery|P13-05|Cohort framework + weekly report|Weekly cohort report live|30|33|Standardise cohort reporting by install week, channel, campaign and segment with LTV curves|Cohort retention is the only way to know whether growth is real or a leaky bucket
P13-10|LTV & Unit Economics Model|Analytics|High|Data Analyst; Finance|Financial modelling|5 days|Internal|BigQuery; Google Sheets|P13-05; P13-09|LTV model + max CAC by channel|Model live and used to set paid bids|34|39|Build a predictive LTV model by channel and segment deriving max allowable CAC and payback|Sets the bid ceilings that keep paid scaling profitable rather than growth-at-any-cost
P13-11|Alerting & Anomaly Detection|Analytics|Medium|Data Analyst|Monitoring|3 days|Rs 5,000/mo|Looker alerts; Slack; Zapier|P13-07|10 live alerts|Alerts live; mean time to detect under 2 hours|40|42|Automate Slack alerts on CPI spikes, install drops, crash rate, rating drops and spend overruns|Catches problems in hours instead of at month-end when the money is already gone
P13-12|Data Governance & Privacy Compliance|Analytics|High|Data Analyst; Legal; Mobile Developer|Privacy compliance|6 days|Rs 40,000 legal|Consent SDK; ASC; Play Data Safety|P13-01|Compliance doc + consent flow live|100% compliant; Data Safety forms accurate|15|22|Implement DPDP and GDPR compliance, consent management, retention policy, ATT and deletion flows|A fintech app mishandling personal data faces regulatory action and store removal
P13-13|Weekly Growth Review Ritual|Analytics|High|Growth Manager; All leads|Facilitation|1 hr/week ongoing|Internal|Looker Studio; Notion|P13-07|Weekly recap documents|Held 100% of weeks; decisions logged|30|999|Run a fixed 60-minute Monday review of dashboard, experiments, blockers and priorities|The operating cadence that converts data into decisions; without it dashboards go unread
P15-01|Competitor Landscape Mapping|Research|High|Growth Manager|Market research|3 days|Internal|App stores; Sensor Tower|-|Competitive landscape map|12 competitors mapped across 3 tiers|1|3|Map direct, adjacent and substitute competitors including WhatsApp notes and spreadsheets|Substitutes not rival apps are your real competition; most users split in a WhatsApp chat today
P15-02|Feature Comparison Matrix|Research|High|Product Manager; Growth Manager|Product analysis|5 days|Rs 5,000 subscriptions|Notion; competitor apps|P15-01|Feature matrix (60 features x 8 apps)|Matrix complete; 10 gaps and 5 table stakes identified|3|8|Install and use 8 competitors for two weeks and score 60 features for presence and quality|Reveals genuine gaps to exploit and table stakes you are missing
P15-03|Download & Revenue Estimation|Research|High|Data Analyst|Market intelligence|2 days|Rs 20,000/mo|Sensor Tower; data.ai; Appfigures|P15-01|Market sizing report|Estimates for 8 apps; India TAM sized|5|7|Estimate competitor installs, MAU, revenue, growth and India market share|Sizes the opportunity and sets realistic ceilings for forecasts and investor conversations
P15-04|Competitor ASO Benchmarking|Research|High|ASO Specialist|ASO analysis|3 days|Included in ASO tool|AppTweak; Sensor Tower|P1-07|ASO benchmark report (monthly refresh)|Monthly report; 40 keyword gaps identified|6|9|Benchmark competitor rankings, ratings velocity, update frequency and creative changes|Feeds Phase 1 directly and update velocity signals when a competitor is investing in growth
P15-05|Competitor Marketing Teardown|Research|High|Growth Manager; Performance Marketer|Competitive analysis|4 days|Internal|Meta Ad Library; Ahrefs; Google Ads Transparency|P15-01|Marketing teardown deck|8 teardowns; 15 tactics adopted or rejected|9|13|Analyse competitor ad creatives, SEO footprint, social, influencers, PR and email flows|Their ad library shows which creatives they keep running - i.e. which ones work - for free
P15-06|Pricing & Monetization Analysis|Research|High|Product Manager; Growth Manager|Pricing strategy|3 days|Internal|Competitor apps; Sensor Tower|P15-02|Pricing analysis + recommendation|Pricing recommendation approved|10|13|Compare pricing, paywall placement, free-tier limits and India-specific pricing|Splitwise's aggressive paywall is the biggest positioning opportunity if priced correctly
P15-07|SWOT & Positioning Synthesis|Research|High|CMO; Growth Manager|Strategic synthesis|2 days|Internal|Miro; Google Slides|P15-02; P15-03; P15-04; P15-05; P15-06|SWOT deck + positioning map|Positioning locked and used in Phase 2|14|15|Synthesise research into per-competitor SWOTs and a positioning map|Turns raw research into a decision about exactly where KharchaSplit wins
P15-08|Continuous Competitive Monitoring|Research|Medium|Data Analyst|Monitoring|2 hrs/wk ongoing|Included in tools|Sensor Tower alerts; Google Alerts; Appbot|P15-01|Weekly competitive digest|Digest sent weekly; 100% delivery|16|999|Automate weekly monitoring of app updates, features, pricing, campaigns, press and sentiment|Category dynamics change quarterly; a one-off study is stale within 60 days
"""

FIELDS = [
    "ID", "Name", "Category", "Priority", "Owner", "Skills", "EstTime", "EstCost",
    "Tools", "Deps", "Deliverables", "KPI", "StartDay", "EndDay", "Description", "Why",
]


def parse():
    rows = []
    for line in RAW.strip().splitlines():
        line = line.strip()
        if not line:
            continue
        parts = line.split("|")
        if len(parts) != len(FIELDS):
            raise ValueError(
                f"Row {parts[0]} has {len(parts)} fields, expected {len(FIELDS)}"
            )
        rows.append(dict(zip(FIELDS, parts)))
    return rows


def schedule(tasks):
    """Forward-pass scheduler: push each task's start until all dependencies are met.

    A finished task must END before its dependent starts. A recurring/always-on
    dependency only needs to have STARTED. Raises on unresolved deps or cycles.
    """
    by_id = {t["ID"]: t for t in tasks}
    start = {t["ID"]: int(t["StartDay"]) for t in tasks}
    dur = {t["ID"]: (1 if int(t["EndDay"]) == 999
                     else int(t["EndDay"]) - int(t["StartDay"]) + 1) for t in tasks}
    ongoing = {t["ID"]: int(t["EndDay"]) == 999 for t in tasks}
    deps = {t["ID"]: [] if t["Deps"] == "-" else
            [d.strip() for d in t["Deps"].split(";") if d.strip()] for t in tasks}

    for tid, ds in deps.items():
        for d in ds:
            d = d.lstrip("~")
            if d not in by_id:
                raise ValueError(f"{tid}: unresolved dependency {d}")

    for _ in range(len(tasks) + 1):
        moved = False
        for t in tasks:
            tid = t["ID"]
            for d in deps[tid]:
                soft = d.startswith("~")
                d = d.lstrip("~")
                earliest = start[d] if (soft or ongoing[d]) else start[d] + dur[d]
                if start[tid] < earliest:
                    start[tid] = earliest
                    moved = True
        if not moved:
            break
    else:
        raise ValueError("dependency cycle detected - schedule did not converge")

    shifts = []
    for t in tasks:
        tid = t["ID"]
        original = int(t["StartDay"])
        if start[tid] != original:
            shifts.append((tid, original, start[tid]))
        t["_start"] = start[tid]
        t["_end"] = 90 if ongoing[tid] else start[tid] + dur[tid] - 1
        t["_ongoing"] = ongoing[tid]
    return shifts


def build():
    tasks = parse()
    shifts = schedule(tasks)
    out = []
    for t in tasks:
        phase = int(t["ID"].split("-")[0][1:])
        start_day, end_day, ongoing = t["_start"], t["_end"], t["_ongoing"]
        start = KICKOFF + timedelta(days=start_day - 1)
        end = KICKOFF + timedelta(days=max(end_day, start_day) - 1)
        duration = max(end_day - start_day + 1, 1)

        timeline = (
            f"Day {start_day} onwards (ongoing)" if ongoing
            else f"Day {start_day}-{end_day}" if end_day != start_day
            else f"Day {start_day}"
        )

        out.append({
            "Task ID": t["ID"],
            "Task Name": t["Name"],
            "Phase": f"Phase {phase} - {PHASE_NAMES[phase]}",
            "Epic": EPIC[phase],
            "Category": t["Category"],
            "Description": t["Description"],
            "Why This Matters": t["Why"],
            "Priority": t["Priority"],
            "Owner": t["Owner"],
            "Skills Required": t["Skills"],
            "Estimated Time": t["EstTime"],
            "Estimated Cost": t["EstCost"],
            "Required Tools": t["Tools"],
            "Dependencies": "" if t["Deps"] == "-" else t["Deps"].replace("~", ""),
            "Deliverables": t["Deliverables"],
            "KPI / Success Metric": t["KPI"],
            "Start Date": start.isoformat(),
            "End Date": end.isoformat(),
            "Duration (days)": duration,
            "Timeline": timeline,
            "Sprint": sprint_for(start_day),
            "Recurring": "Yes" if ongoing else "No",
            "Status": "Not Started",
        })
    return out, shifts


def write_csv(path, rows, fieldnames, rename=None):
    with open(path, "w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow({k: r.get(rename.get(k, k) if rename else k, "") for k in fieldnames}
                       if rename else r)


def main():
    rows, shifts = build()

    # Full / Notion import
    full_fields = list(rows[0].keys())
    write_csv("KharchaSplit-Tasks-Import.csv", rows, full_fields)

    # ClickUp-native column names
    def est_hours(txt):
        """ClickUp time estimates must be numeric hours. Parse only clean values."""
        import re as _re
        m = _re.fullmatch(r"(\d+)\s*(day|days|hr|hrs|hour|hours|week|weeks|wk|wks)", txt.strip())
        if not m:
            return ""
        n, unit = int(m.group(1)), m.group(2)
        if unit.startswith(("hr", "hour")):
            return n
        if unit.startswith(("day",)):
            return n * 8
        return n * 40

    PRIO = {"High": "2", "Medium": "3", "Low": "4"}  # ClickUp: 1=Urgent 2=High 3=Normal 4=Low

    clickup_rows = []
    for r in rows:
        clickup_rows.append({
            "Task Name": f"[{r['Task ID']}] {r['Task Name']}",
            "Task Content": (
                f"{r['Description']}\n\n"
                f"WHY THIS MATTERS: {r['Why This Matters']}\n\n"
                f"DELIVERABLE: {r['Deliverables']}\n"
                f"SUCCESS METRIC: {r['KPI / Success Metric']}\n"
                f"OWNER ROLE: {r['Owner']}\n"
                f"SKILLS: {r['Skills Required']}\n"
                f"TOOLS: {r['Required Tools']}\n"
                f"EST. COST: {r['Estimated Cost']}\n"
                f"EST. EFFORT: {r['Estimated Time']}\n"
                f"DEPENDS ON: {r['Dependencies'] or 'None'}"
            ),
            "Status": "to do",
            "Priority": PRIO[r["Priority"]],
            "Start Date": r["Start Date"],
            "Due Date": r["End Date"],
            "Time Estimate": est_hours(r["Estimated Time"]),
            "Lists": r["Epic"],
            "Tags": f"{r['Category']},{r['Sprint'].split(' — ')[0]}",
            "Owner Role": r["Owner"],
            "Task ID": r["Task ID"],
            "Phase": r["Phase"],
            "Dependencies": r["Dependencies"],
            "Estimated Cost": r["Estimated Cost"],
            "Recurring": r["Recurring"],
        })
    write_csv("KharchaSplit-Tasks-ClickUp.csv", clickup_rows, list(clickup_rows[0].keys()))

    # Summary
    by_phase = {}
    for r in rows:
        by_phase[r["Phase"]] = by_phase.get(r["Phase"], 0) + 1
    print(f"Kickoff: {KICKOFF.isoformat()}")
    print(f"Total tasks: {len(rows)}")
    for p in sorted(by_phase, key=lambda x: int(x.split()[1])):
        print(f"  {p}: {by_phase[p]}")
    prio = {}
    for r in rows:
        prio[r["Priority"]] = prio.get(r["Priority"], 0) + 1
    print("Priority:", prio)
    print("Recurring/ongoing tasks:", sum(1 for r in rows if r["Recurring"] == "Yes"))
    over = [r for r in rows if r["Recurring"] == "No"
            and (date.fromisoformat(r["End Date"]) - KICKOFF).days + 1 > 90]
    print(f"Tasks ending beyond Day 90: {len(over)}")
    for r in over:
        print(f"  {r['Task ID']} ends {r['End Date']} ({r['Timeline']})")
    print(f"Dependency-driven date shifts: {len(shifts)}")
    for tid, a, b in shifts:
        print(f"  {tid}: Day {a} -> Day {b}")
    print("Wrote KharchaSplit-Tasks-Import.csv and KharchaSplit-Tasks-ClickUp.csv")


if __name__ == "__main__":
    main()
