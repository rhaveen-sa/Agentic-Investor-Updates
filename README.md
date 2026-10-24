# Investor Update Agent

A proactive agent that collects a startup's progress across the reporting period and has the investor update ready for approval when the period ends. Instead of waiting for the founder to write, it reads the company's tools every week, proposes facts for the founder to confirm, chases teammates when a number looks off, and writes the update from confirmed facts only, so every number links to its source.

Demo video: _link coming_

**Confirm, don't write. It chases the gaps. Every number has a source.**

## Setup

```bash
cp secrets.example.json secrets.json   # add ANTHROPIC_API_KEY and RESON8_API_KEY
flutter pub get
flutter run -d macos --dart-define-from-file=secrets.json
```

Without an `ANTHROPIC_API_KEY` the app runs in **scripted mode**: the same tools and UI, with decisions taken from the mock data instead of the model. If a live run fails, the agent falls back to the scripted run automatically.

## The demo

The demo follows **Shelfwise**, a fictional seed-stage B2B SaaS (AI demand forecasting for independent grocery stores) through October 2026. Click **Next week** to advance the simulated date. Each click triggers the weekly check-in, and the last one closes the month.

| Week | What happens |
| --- | --- |
| 1 | Check-in: 2 new stores, supplier export shipped, 31 demos. The agent sees in a Jamie meeting that the lead investor asked for NRR and suggests adding it to the KPIs. The founder adds by voice that two engineers started. |
| 2 | Release 2.0, FreshMart Nord pilot (12 stores, +€36k ARR), record 44 demos. |
| 3 | Demos drop to 12. The agent investigates, finds that Anna owns LinkedIn, and drafts a Slack message. The founder approves it, and Anna's reply becomes a fact. |
| 4 | Release 2.1. FreshMart says it wants 40 stores in Q1, but only in a meeting. |
| Close | October numbers come in. The agent drafts the update and a separate verifier flags the "40 stores" claim as unconfirmed. |

## Architecture

```
 GitHub  Jamie  HubSpot  LinkedIn  Stripe        (mocked, assets/mock/*.json)
     \      \      |      /       /
      SourceConnector.fetch(since, until)        (one interface, lib/data/connectors.dart)
                   |
            Agent loop (Claude)  ── tools ──>  Facts · Feed · Outbox · Report
                   ^                              |
   founder chat / voice (Reson8) / documents      └── founder confirms, approves
   teammate replies (Slack, WhatsApp, email)
```

A single Flutter macOS app with a [shadcn_ui](https://pub.dev/packages/shadcn_ui) interface. Everything runs locally except the Claude and Reson8 API calls.

### Four agent runs, one tool set

| Run | Trigger | Ends with |
| --- | --- | --- |
| A. Weekly check-in | Founder-set cadence ("Next week") | Check-in card: facts to confirm, 1 to 3 questions |
| B. Anomaly investigation | A metric drops sharply (demos −73%) | Message draft to the owner, waiting for approval |
| C. Inbound processing | Founder chat, voice, document, or a teammate's reply | Proposed facts in the ledger |
| D. Period report | End of the month | Update built from confirmed facts, checked by a separate verifier call |

Tools: `list_sources`, `fetch_source`, `ledger_search`, `ledger_propose`, `suggest_kpi`, `team_directory`, `ask_founder`, `message_teammate` (needs approval), `submit_report`, `verify_claims`. Tools run locally and deterministically; the model chooses calls and writes text. The KPI table is computed from the ledger, never written by the model.

Code: `lib/agent/` (Claude client with a manual tool-use loop, tools, prompts, runs, scripted fallback), `lib/data/` (connectors), `lib/models/`, `lib/ui/`, `lib/voice/` (Reson8).

## What is mocked, and how real connectors plug in

- **Sources** are timestamped JSON in `assets/mock/`; each connector only returns data up to the simulated date. A real connector implements the same `SourceConnector.fetch(since, until)`: OAuth per source (GitHub, HubSpot, Stripe, LinkedIn), the Jamie API for meetings, and Computer Use for dashboards without an API.
- **Scheduling**: the "Next week" button stands in for a cron job per founder; anomaly checks would run from webhooks.
- **Teammate messages**: drafts are approved in the app and shown as sent. Replies are simulated with the "Simulate reply" button. Slack, WhatsApp and email are channels of the same `message_teammate` tool.

## Partner tech

- **Claude** (`claude-sonnet-5`): the agent loop for all four runs plus the separate verifier.
- **Reson8**: voice input via the prerecorded speech-to-text API, biased with a custom model of startup vocabulary (ARR, NRR, churn, runway, burn, company and people names).
- **Jamie**: meeting notes as a source (mocked).

## Pitch materials

Everything needed to present this lives in [`pitch/`](pitch/).

| File | What it is |
| --- | --- |
| `deck.html` | The slide deck. Open it in a browser, press `F` for fullscreen. Arrows navigate, `S` shows speaker notes, `O` toggles four optional slides so the same deck runs as a 3-minute or an 8-minute talk. Self-contained: no network, no build step, no fonts to install. |
| `script.md` | Word-for-word narration with timings, the demo click-path interleaved, a paragraph to read if the live demo stalls, and prepared Q&A answers. |
| `shotlist.md` | Shot-by-shot plan for the backup demo recording, written as one continuous take because the recording setup has no video editor. |
| `HANDOFF.md` | Every code change needed to run the demo on Reson8 instead of Shelfwise. |
| `reson8-mock/` | A second, drop-in mock dataset. See below. |

### Running the demo on Reson8

`pitch/reson8-mock/` holds the same seven files as `assets/mock/`, with the same schema,
telling the same October story for [Reson8](https://www.reson8.dev/), an Amsterdam
speech-recognition company. Swapping datasets is a copy:

```bash
cp pitch/reson8-mock/*.json assets/mock/
```

The code changes that go with it (team directory, sidebar, prompts, scripted fallback) are
listed in `pitch/HANDOFF.md`.

The weekly demo-booking numbers are 29, 41, 11 and 34, so the week 3 drop is 73%, the same
as the Shelfwise data produced. Nothing keyed to the anomaly threshold needs retuning.

Reson8's funding, founders, supported languages, API surface, certifications and pricing
are public. Every revenue, burn, cash, runway and customer figure in the dataset is
invented for the demo, along with all customer names and the Head of Growth. The deck says
so on screen.

## Tests

```bash
flutter test
```

`test/demo_flow_test.dart` runs the whole October scenario in scripted mode and checks the final report.
