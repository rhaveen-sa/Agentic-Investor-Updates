# Handoff: run the Agentic Investor Updates demo

For whoever drives the app on the day. Checked against `main` at `636f3f8`, and clicked
through in the web build on 25 Oct 2026 (Flutter 3.47.8, scripted mode).

**Where things stand:**
- **Reson8 switch:** the app runs on the Reson8 story. It was applied in `6b37f49`.
  [`reson8-switch.patch`](reson8-switch.patch) stays in the repo as a record, but don't
  apply it again.
- **Investor report:** it's built into the app (`0926e58`). The Report page follows
  [`investor-report/`](investor-report/), and **Download PDF** saves it.
- **Name:** the project is called **Agentic Investor Updates** in the README, deck, script
  and the suggested GitHub description. The app itself still says "Ledger" in a few places (see section 7).
- **Messages screen removed:** message drafts and teammate replies now live in the Agent chat.

What changed and when is in [`WORKLOG.md`](WORKLOG.md).

## 1. Run it

```bash
flutter test
flutter run -d macos --dart-define-from-file=secrets.json
```

The tests:
- **`test/demo_flow_test.dart`** runs the whole October story in scripted mode. It checks the
  Reson8 numbers, default alive, the ARR bridge, that the 14 clinics claim stays out of the
  update, and that the PDF is generated.
- **`test/live_smoke_test.dart`** runs week 1 against the real Claude API. It costs a few
  cents and is skipped without a key.

`flutter run -d chrome` also works without Xcode. That's how the 25 Oct check was done.

## 2. Check the demo is really live

The model is `claude-sonnet-5-5` (`lib/agent/claude_client.dart:8`). That's a valid ID, so
leave it. Two things not to add while tuning, because Sonnet 5.5 rejects both with a 400:
- `temperature`, `top_p` or `top_k`
- `thinking: {budget_tokens: N}`

A failed call never crashes the app. It finishes with the scripted run instead. When that
happens, the step list shows an amber **"Live run failed, finished with the backup run"** row.
It's live when:

- Settings > Agent has scripted mode **off**
- no step list shows the amber row

## 3. Before you present

- [ ] `flutter test` passes.
- [ ] No Shelfwise names left. This should print nothing:
      `grep -rniwE "shelfwise|lena|anna|tom|mara|northstar|freshmart" lib/ assets/mock/`
- [ ] Sources shows six cards, including PyPI · npm.
- [ ] A live week 1 shows no amber "Live run failed" row.
- [ ] Dictate a sentence with "Noorderlicht" and "NRR". Both come back spelled right.
- [ ] Week 3 shows the demos drop and drafts a message to Mirte. **Send**, then
      **Simulate reply from Mirte**, turns her reply into a fact.
- [ ] **Before closing the month, open Facts. The badge must show no number.** A week can
      show two cards with **Confirm all**, and the second (Mirte's reply) is easy to miss.
      With facts still pending, the report shows "6 claims not counted" and "The bridge does
      not add up to October ARR". **Confirm N** on the Facts screen clears them.
- [ ] After **Close October and draft the update**, click **Confirm & draft the update**.
- [ ] After **Close October and draft the update**, the Report page reads €413k, 44, 112%,
      €231k, €3.89M, 17 months.
- [ ] Default alive says break-even in November 2027 with €1.83M left.
- [ ] The header says **1 claim not counted**, and that claim is the 14 clinics one, under
      "Pipeline we are not counting yet".
- [ ] **Download PDF** saves the update.
- [ ] Record `demo-backup.mp4` following [`shotlist.md`](shotlist.md), the version
      rewritten for the week selector.

## 4. What the deck and script promise

The deck and script were updated to match the app at `0926e58`. Four of their promises
depend on the app:

- **"Judges, pick any number."** The close invites the judges to pick any number on the
  report. Have the Report page open after the demo, and check that every KPI and every
  claim opens its source.
- **"The verifier keeps it out."** The 14 clinics claim must not appear in the update. It
  should only be listed under "Pipeline we are not counting yet". The deck's close card
  says NOT COUNTED to match.
- **"Numbers are computed in code."** That holds: the KPI table, default alive, the
  charts and the ARR bridge are all computed from confirmed facts. Keep it that way.
- **The backup slide** hides itself if `demo-backup.mp4` isn't next to `deck.html`.
- **`deck.pdf`** has the same slides, without the backup slide. If you present from the PDF
  and the live demo stalls, switch to the video file itself.

## 5. Two copies of the investor report

| | In the app | `demo/investor-report/` |
| --- | --- | --- |
| How | Report page, **Download PDF** | `python3 demo/investor-report/build.py` |
| Data | Facts confirmed in the run | The mock JSON directly |
| Charts start | September close | October |
| Use it for | The demo, and the PDF to send | A reference sample, no app needed |

The headline numbers are the same in both: default alive, November 2027, €1.83M, an 8.6%
edge, about €356k max burn, and the bridge from €352k to €413k. If you change the mock data,
rerun `build.py` so the sample still matches, or drop the sample and point people to the app.

## 6. What the Reson8 switch changed

A short record. The detail is in the patch and in `6b37f49`.

- **Data:** the mock files in `assets/mock/` are the Reson8 versions, plus `packages.json`.
  That file holds the real SDK download counts, the sixth source.
- **Names:** Thomas, Jarno and Mirte replace Lena, Tom and Anna. Reson8 replaces Shelfwise,
  and Balderton and NP-Hard replace Northstar. The strict tool schemas in `tools.dart` only
  accept the new owner names.
- **Voice:** the Reson8 vocabulary in `reson8_client.dart` is why "Noorderlicht" and "NRR"
  come back spelled right.
- **Scripted fallback:** the hardcoded report cites Reson8 record IDs. Only the 14 clinics
  claim cites a meeting-only fact.
- **Default alive:** computed in code from confirmed ARR, burn and cash. The model never
  writes it.

## 7. Still to do outside `demo/`

**GitHub About section.** Your account has push access but not admin, so it couldn't set
this. Sean (or another admin) can paste these into the repo's About section (the gear icon
next to About):

- **Description:** Agentic Investor Updates: an AI agent that collects your startup's month
  as it happens and drafts the investor update from facts you confirm, with a source behind
  every number. Built with Claude, Reson8 and Jamie.
- **Website:** https://github.com/seanjanke/Agentic-Investor-Updates/blob/main/demo/deck.pdf
- **Topics:** ai-agent, claude, anthropic, flutter, investor-updates, startups, founders,
  llm, hackathon, speech-to-text

**"Ledger" inside the app.** The docs now use Agentic Investor Updates. The app still shows
"Ledger" in these places. Rename them if you want the app to match. This PR changes no app
code.

| File | What says Ledger |
| --- | --- |
| `lib/main.dart:23` | Window title |
| `web/index.html` (lines 26 and 32) | Browser tab title and home-screen name |
| `web/manifest.json` (lines 2 and 3) | Web app name |
| `macos/Runner/Configs/AppInfo.xcconfig:8` | `PRODUCT_NAME`, the macOS app name |
| `lib/ui/report_pdf.dart` (lines 194 and 203) | PDF author and footer ("Generated by Ledger") |

The logo (`assets/brand/logo_*.png`) is an "L" mark, so it fits either name.

## A note on the data

**Public and checkable:**
- **The company:** the €5M pre-seed led by Balderton with NP-Hard (March 2026, Amsterdam),
  Resonate Labs B.V., and the three founders.
- **The product:** 10 supported languages; the Prerecorded, Realtime and Turns endpoints;
  ISO 27001, GDPR, the EU AI Act and zero audio retention.
- **Pricing:** the Free, Pro at €20, Growth at €100 and Enterprise tiers.

**Real, pulled on 24 Oct 2026:** the SDK download counts in `packages.json`.

| Package | September | 1 to 23 October |
| --- | --- | --- |
| PyPI `livekit-plugins-reson8` (pypistats.org, without mirrors) | 4,929 | 3,941 |
| npm `@reson8-labs/agents-plugin-reson8` (api.npmjs.org) | 16,639 | 26,794 |

Downloads include CI installs, so they track developer adoption, not users.

**Invented:**
- every revenue, burn, cash, runway, customer-count and demo figure
- all customer names: Noorderlicht Zorggroep, Van Dijk Advocaten, Contactpunt BV, Helder
  Notarissen and Brugman Verzekeringen
- Mirte
- all release contents

The deck, the sample report and the app's PDF all say so. Leave those notes in.

**Gap:** the Report page in the app has no demo-data note. Only its PDF does. Before
anyone screenshots the Report page or shows it outside the pitch, add the same line from
`report_pdf.dart` to the top of `report_screen.dart`.
