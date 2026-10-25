# Handoff

Where Agentic Investor Updates stands after the hackathon, and what to pick up next. Checked
against `main` on 25 Oct 2026: `flutter test` passes, and the web build was clicked through
from the first check-in to an approved update (Flutter 3.47.8, scripted mode).

The history, PR by PR, is in [`demo/WORKLOG.md`](demo/WORKLOG.md).

## What exists

- **A working app.** It's a Flutter app for macOS and the web. An agent runs the four
  October weeks for the demo company Reson8. It proposes facts, you confirm them, it chases a
  dropped number, and it drafts a full investor update. Every figure links to its source.
- **Numbers computed in code.** The update has charts, a default alive test and a PDF export,
  and all the numbers come from confirmed facts. A second Claude call keeps unbacked claims out.
- **Tests:**
  - `test/demo_flow_test.dart` runs the whole month in scripted mode.
  - `test/live_smoke_test.dart` runs week 1 against the real Claude API when a key is set.
- **Pitch material:**
  - [`pitch-deck.pdf`](pitch-deck.pdf) and [`pitch-deck.html`](pitch-deck.html) at the top
    of the repo.
  - The script, shot list, sample investor report and judge scores in [`demo/`](demo/).

## Run it

```bash
flutter pub get
flutter test
flutter run -d chrome                                     # no Xcode needed
flutter run -d macos --dart-define-from-file=secrets.json # needs Xcode
```

**Keys:**
- **No keys:** the app runs in scripted mode, replaying the agent's decisions from the mock
  data through the same tools and screens.
- **Live runs:** copy `secrets.example.json` to `secrets.json` and fill in:
  - `ANTHROPIC_API_KEY`: Claude
  - `RESON8_API_KEY`: voice
  - `SLACK_WEBHOOK_URL`: optional. Approved messages are also posted to Slack.

**Is it live?** Settings > Agent has a scripted-mode switch. If a live call fails, the app
finishes with the scripted run and shows an amber **"Live run failed, finished with the
backup run"** row in the step list.

**Model:** `claude-sonnet-5-5` (`lib/agent/claude_client.dart:8`). Don't add `temperature`,
`top_p`, `top_k` or `thinking: {budget_tokens}`, because Sonnet 5.5 rejects them with a 400.

## The one thing that trips people up

**Pending facts don't reach the update.** A week can show two cards with **Confirm all**:
the check-in, and later Mirte's reply. The second is easy to miss. If anything is still
pending when you draft, the report says "6 claims not counted" and "The bridge does not add up
to October ARR".

**Fix:** before closing the month, open **Facts**. The badge next to it should show no
number, and **Confirm N** clears whatever is left. A clean run ends with "1 claim not
counted" (the 14 clinics) and "4 new paying teams and 1 loss".

A product fix would be for **Close October** to warn when facts are still pending (see the
list below).

## Open items, in order

1. **GitHub About section.** It needs admin or maintain rights on the repo. Paste this into
   the About settings (the gear icon next to About):
   - **Description:** Agentic Investor Updates: an AI agent that collects your startup's
     month as it happens and drafts the investor update from facts you confirm, with a
     source behind every number. Built with Claude, Reson8 and Jamie.
   - **Website:** https://github.com/seanjanke/Agentic-Investor-Updates/blob/main/pitch-deck.pdf
   - **Topics:** ai-agent, claude, anthropic, flutter, investor-updates, startups, founders,
     llm, hackathon, speech-to-text
2. **Decide the name inside the app.** The docs say Agentic Investor Updates, but the app
   still says "Ledger" in:

   | File | What says Ledger |
   | --- | --- |
   | `lib/main.dart:23` | Window title |
   | `web/index.html` (lines 26 and 32) | Browser tab title and home-screen name |
   | `web/manifest.json` (lines 2 and 3) | Web app name |
   | `macos/Runner/Configs/AppInfo.xcconfig:8` | macOS app name |
   | `lib/ui/report_pdf.dart` (lines 194 and 203) | PDF author and footer |

   The logo is an "L" mark, so it fits either name.
3. **Add a demo-data note to the Report page.** The PDF says the figures are invented, but
   the on-screen Report page doesn't. Copy the line from `report_pdf.dart` into
   `report_screen.dart` before anyone screenshots it.
4. **Warn about pending facts at month close.** Disable **Close October** or show a warning
   while the Facts badge is above zero. That prevents the "6 claims not counted" report.
5. **One real connector.** Every source implements `SourceConnector.fetch(since, until)` in
   `lib/data/connectors.dart`. Stripe or HubSpot would turn the demo into something a founder
   can use on their own month. Next on the list after those:
   - Granola, Salesforce, Linear, Notion and Google Analytics
   - Claude Computer Use, for dashboards without an API
6. **Real proof.** Every judge of the pitch and README asked for evidence from a real founder:
   a pilot on a real month, a quote, or the time saved. That's the biggest score gain left
   (see [`demo/pitch-review.md`](demo/pitch-review.md)).
7. **Clean-up.** `demo/reson8-switch.patch` is already applied (`6b37f49`) and can be deleted.

## The data

**Public:**
- **The company:** Reson8's €5M pre-seed led by Balderton with NP-Hard (March 2026,
  Amsterdam), Resonate Labs B.V. and the founders.
- **The product:** 10 languages; the Prerecorded, Realtime and Turns endpoints; ISO 27001,
  GDPR and zero audio retention.
- **Pricing:** the Free, Pro (€20), Growth (€100) and Enterprise tiers.

**Real, pulled on 24 Oct 2026:** the SDK downloads in `assets/mock/packages.json`, for
`livekit-plugins-reson8` on PyPI and `@reson8-labs/agents-plugin-reson8` on npm.

| | September | 1 to 23 October |
| --- | --- | --- |
| PyPI | 4,929 | 3,941 |
| npm | 16,639 | 26,794 |

They include CI installs.

**Invented:**
- every revenue, burn, cash, runway, customer and demo figure
- all customer names
- Mirte
- the release contents

The deck, the sample report and the app's PDF all say so. Keep those notes.

## Where things are

| Path | What |
| --- | --- |
| `lib/agent/` | Claude client, tools, prompts, the four runs, scripted fallback |
| `lib/data/` | Source connectors and the team directory |
| `lib/ui/` | Week selector, chat, facts, sources, report, charts, PDF, settings |
| `assets/mock/` | The October data, one JSON file per source |
| `test/` | The scripted month and the live smoke test |
| `pitch-deck.pdf`, `pitch-deck.html` | The pitch deck |
| `demo/` | Script, shot list, sample investor report, judge scores, work log, screenshots |

**If you present it again:** start with [`demo/README.md`](demo/README.md). The shot list
in `demo/shotlist.md` was checked against the real app. Save a backup recording as
`demo/demo-backup.mp4`, and `pitch-deck.html` plays it.
