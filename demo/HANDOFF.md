# Handoff: run the demo on Reson8

For whoever drives the app. The deck and script tell the October story on Reson8, but the
app still ships with the Shelfwise data. Nothing in `lib/`, `test/` or `assets/` has been
changed for you: every change is in one patch for you to review and apply.

## 1. Apply the patch

```bash
git checkout -b reson8-demo
git apply --check demo/reson8-switch.patch   # prints nothing if it applies
git apply demo/reson8-switch.patch
flutter test
```

The patch was written against `main` at `43d0e8c` and applies cleanly there. It has not
been compiled or run: there was no Flutter SDK on the machine it was written on. Read it
before applying. If `flutter test` fails, the new code is the place to look first:
`buildDefaultAlive()` in `lib/app_state.dart` and `_DefaultAliveBlock` in
`lib/ui/report_screen.dart`.

If `main` has moved and the patch no longer applies, `git apply --reject
demo/reson8-switch.patch` applies what it can and leaves `.rej` files for the rest.

## 2. What the patch changes

**Data.** The seven files in `assets/mock/` become the Reson8 versions from
`demo/reson8-mock/`, and a new `packages.json` adds SDK download counts.

**A sixth source, PyPI · npm.** Download counts for Reson8's LiveKit plugins, as a
developer-adoption source. These numbers are real (see the note at the end). It is wired
into `sourceInfos` in `connectors.dart`, the connector list in `app_state.dart`, both
source enums in `tools.dart`, and the "all six sources" line in `prompts.dart`. The
Sources screen picks it up on its own.

**Names.** Lena, Tom and Anna become Thomas, Jarno and Mirte. Shelfwise becomes Reson8, and
Northstar becomes Balderton and NP-Hard. This covers the team directory, prompts, sidebar,
window title, the report's To line and sign-off, the Slack webhook text and the welcome
card. Two of these break the demo if they are missed:

- The strict tool schemas in `tools.dart` only accept `Lena`, `Tom` and `Anna` as owners.
- The Reson8 vocabulary in `reson8_client.dart` is what makes "Noorderlicht" and "NRR"
  come back spelled right. That is the point of the voice beat.

**Scripted fallback.** `scripted.dart` holds a hardcoded report that cites source records
by ID. Every ID moves to its Reson8 equivalent:

| Shelfwise | Reson8 |
| --- | --- |
| `hs-deal-2310` | `hs-deal-1160` (Noorderlicht pilot) |
| `gh-rel-2.0`, `gh-rel-2.1` | `gh-rel-1.8`, `gh-rel-1.9` |
| `gh-pr-412`, `gh-pr-447` | `gh-pr-318`, `gh-pr-349` |
| `hs-churn-0457` | `hs-churn-0231` |
| `jamie-mtg-1016` | `jamie-mtg-1019` |

The rewritten report adds two highlights: SDK downloads (`pkg-oct-23`) and Free to Pro
conversion (`stripe-plg-oct`). Only the "all 14 clinics in Q1" claim cites a meeting-only
fact, so the verifier still flags exactly one claim.

**Default alive.** A new section under the KPI table answers Paul Graham's
[default alive or default dead](https://paulgraham.com/aord.html) question. It is
computed in code from confirmed ARR (September and October), net burn and cash, and the
model never writes it. It assumes flat costs and simulates month by month, then finds the
growth rate where the answer flips. On the Reson8 data it says default alive: break-even
in 13 months with €1.83M left, and default dead below about 8.6% monthly growth. It also
goes into the copy-as-text export.

- `lib/models/report.dart`: a `DefaultAlive` class and a `Report.defaultAlive` field.
- `lib/app_state.dart`: `buildDefaultAlive()`.
- `lib/agent/runs.dart`: sets it after either the live or the scripted report run.
- `lib/ui/report_screen.dart`: shows it, and adds it to `reportAsText`.

**Test.** `test/demo_flow_test.dart` now expects €413k, ARR change `+17%`, 30.7k downloads,
the 14 clinics flag, and the default-alive numbers.

**README.** Describes Reson8 as the demo company, the sixth source and the default-alive
check.

## 3. Check the demo is really live

Keep the model as it is in `lib/agent/claude_client.dart:8`:

```dart
const claudeModel = 'claude-sonnet-5-5';
```

That is a valid ID (Claude Sonnet 5.5), and the request already suits it: `tool_choice` is
`auto`, and `fallbacks: 'default'` is a form Sonnet 5.5 accepts. Two things not to add while
tuning, because Sonnet 5.5 rejects both with a 400: `temperature`/`top_p`/`top_k`, and
`thinking: {budget_tokens: N}`.

The app never crashes on a failed call. It falls back to the scripted run, so the UI looks
the same either way. Expand any agent message and read the model row:

- `claude-sonnet-5-5`: live.
- `scripted`: no key, or scripted mode is on.
- `fallback`: the live call failed. The step shows the error.

## 4. Before you present

- [ ] `flutter test` passes.
- [ ] No Shelfwise names left. This should print nothing:
      `grep -rniwE "shelfwise|lena|anna|tom|mara|northstar|freshmart" lib/ assets/mock/`
- [ ] Sources shows six cards, including PyPI · npm.
- [ ] A live run shows `claude-sonnet-5-5` in the model row of an expanded message.
- [ ] Dictate a sentence with "Noorderlicht" and "NRR" in it. Both come back spelled right.
- [ ] The week 3 anomaly fires and drafts a message to Mirte.
- [ ] The report reads 413k, 44, 112%, 231k, 3.89M, 17 months, shows the default-alive
      section, and flags only the 14 clinics claim.

## A note on the data

Public and checkable: the €5M pre-seed led by Balderton with NP-Hard, March 2026,
Amsterdam, Resonate Labs B.V., the three founders, 10 supported languages, the
Prerecorded, Realtime and Turns endpoints, ISO 27001, GDPR, EU AI Act, zero audio
retention, and the Free, Pro at €20, Growth at €100 and Enterprise pricing tiers.

Real, pulled on 24 Oct 2026: the SDK download counts in `packages.json`. PyPI
`livekit-plugins-reson8` (pypistats.org, without mirrors) had 4,929 downloads in September
and 3,941 from 1 to 23 October. npm `@reson8-labs/agents-plugin-reson8` (api.npmjs.org) had
16,639 and 26,794. Downloads include CI installs, so they track developer adoption, not
users.

Invented: every revenue, burn, cash, runway, customer-count and demo figure, all customer
names (Noorderlicht Zorggroep, Van Dijk Advocaten, Contactpunt BV, Helder Notarissen,
Brugman Verzekeringen), Mirte, and all release contents.

The deck carries a visible line saying so. Leave it on screen.
