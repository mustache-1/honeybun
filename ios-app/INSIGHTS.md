# Smarter Honeybun (Phase 7): how Bun's insights work

Bun's notes are **calculations on the data the user has entered**, not advice. Same inputs, same output, every time. No network call, no
model, nothing random, nothing sent anywhere. Code: `ios/App/HoneybunSwiftUI/Core/HBInsights.swift`. Tests: `tests/InsightsFlowCheck`.

## What feeds it
The `/api/nest` snapshot the app already has (entries as Home counts them, including ones saved offline; bills and paydays; budgets; goals and
their deposits; debts and payments; carry-over), last month's expenses as small facts (no labels), and the Debt Center+ strategy / extra amount.
Existing logic is reused, not copied: `HBPlan.forecast`, `beforePayday`, `payoffPlan`, `compareStrategies`, `extraImpact`, `HBHeadsUpRules`
(budgets at 80%+, price changes), `HBRecur.occurrences`.

## What it can say (each has a threshold and a test)
| Rule | Says something when |
|---|---|
| Safe to Spend line | always one factual line under the number (formula, or bills before payday). Never claims bills are "already accounted for". |
| Safe to Spend change | the last 7 days moved it by $40 or more (needs 7 days inside the month). Adds "more than a usual week" only if that is also true. |
| Over | spending is above what has come in AND income was logged |
| Forecast | `HBPlan.forecast` is ready: on track / cutting it close (< $50) / heading short, biggest everyday categories (≥ 20% share), and a "$X less a week" only when that is a believable cut (≤ 80% of everyday spending) |
| Budget pace | 50–80% used while ≥ 15 points ahead of the calendar, from day 5. (80%+ is the original Heads-up rule.) |
| Week | everyday spending in 7 days is ≥ 1.4× and ≥ $30 above (or ≤ 0.6× and ≥ $30 below) a usual week |
| Same point last month | everyday spending differs by ≥ max($25, 10%) with ≥ $100 of history; categories by ≥ max($25, 30%) |
| Bills | bills before payday exceed what is left; a day in the next 7 is ≥ 1.5× a usual bill day (≥ $75, 2+ bills); recurring costs up ≥ $5/month across 2+ items in 90 days |
| Debt | latest payment (14 days) moved the debt-free month; +$50/month saves ≥ 2 months and ≥ $25; Avalanche saves ≥ $50 over Snowball |
| Goals | milestone (25/50/75/90%) crossed within 10 points; pace from ≥ 2 deposits in 90 days (≤ 5 years out); no deposit for 45 days (gentle); completed |
| Together | shared spending vs last month; ≥ 2 shared bills before payday; debt paid together this month (only when the payment list is complete) |
| Low data | nothing logged / no budget yet: one neutral nudge, only when nothing else applies |

## Priority and what reaches Home
`score = (0.40 urgency + 0.30 impact + 0.30 timing) × confidence × novelty`. Novelty drops 20% for each day (up to 3) an insight was already on
Home, never below 40%, so something urgent never disappears. Dismissed insights stay gone for their period (ids carry the month or week).
Home shows the top **3** (a 4th only if its score is ≥ 0.75), **one per group**, nothing under 0.18, and at least one good-news insight whenever
one exists. The rest wait behind "More from Bun". Every insight has two explanations: a `trace` (rule, inputs, the priority breakdown) that stays internal for tests and debugging, and a `detail` (plain labelled numbers plus a short footnote) that is what "Why am I seeing this?" shows. The customer UI never reads the trace (`check_project.rb` enforces that).

## Privacy
The snapshot never contains another member's private entries. Household ("together") insights additionally read **only** entries that are
shared and not private, shared bills, and debt payments (the debts and their payments are visible to the whole household already). Tests
prove adding private entries, unshared entries or unshared bills changes none of them. Bun's memory (dismissed ids, day counts) is stored on the
device only (UserDefaults, already declared in the privacy manifest), is never transmitted, and is wiped on log out or changing household.

## Where things live now
- The streak card moved from Home to the Inbox tab (top, under the header); tapping it opens Stats. Streak maths (`HBProgress.streak`) and state are unchanged.
- "More from Bun" is the quiet footer row of the From Bun card.
- The extra-monthly-payment you set in Plan / Debt Center (`hb-debt-extra`) is read as-is; it is mentioned only in the debt footnote when it is above $0.
