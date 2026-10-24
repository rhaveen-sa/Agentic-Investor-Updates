# Investor Update Agent

**Every number in your investor update, with its source.**

Founders owe their investors an update every month, and most write it late on the 31st
from memory, which keeps the wins and drops the churn. This agent collects the month while
it happens: each week it reads the company's tools, proposes facts for the founder to
confirm, and chases teammates when a number looks off. At month end the update is already
written from confirmed facts only, and every number in it opens its source.

<p align="center"><img src="demo/img/slide-product.png" width="760" alt="Three rules: confirm, don't write; it chases the gaps; numbers open sources. A source card shows ARR €413,000 from Stripe month close, owner Thomas."></p>

<p align="center">
  <a href="#run-it">Run it</a> ·
  <a href="#the-demo">The demo</a> ·
  <a href="#how-it-works">How it works</a> ·
  <a href="demo/">Demo kit and slides</a>
</p>

Demo video: _link coming_

## Run it

```bash
cp secrets.example.json secrets.json   # add ANTHROPIC_API_KEY and RESON8_API_KEY
flutter pub get
flutter run -d macos --dart-define-from-file=secrets.json
```

You don't need any keys to try it. Without an `ANTHROPIC_API_KEY` the app runs in
**scripted mode**, with the same tools and UI, and with decisions taken from the mock data
instead of the model. If a live run fails, the app falls back to the scripted run
automatically. Expand any agent message to see which happened: the model row reads
`claude-sonnet-5-5` for a live run, and `scripted` or `fallback` otherwise.

`SLACK_WEBHOOK_URL` is optional. If it is set, approved Slack messages are also posted
there.

## The demo

The app follows **Shelfwise**, a fictional seed-stage B2B SaaS (AI demand forecasting for
independent grocery stores), through October 2026. Click **Next week** to move the
simulated date forward. Each click runs the weekly check-in, and the last one closes the
month.

| Week | What happens |
| --- | --- |
| 1 | Check-in: 2 new stores, supplier export shipped, 31 demos. The agent sees in a Jamie meeting note that the lead investor asked for NRR, and suggests adding it to the KPIs. The founder adds by voice that two engineers started. |
| 2 | Release 2.0, FreshMart Nord pilot (12 stores, +€36k ARR), a record 44 demos. |
| 3 | Demos drop to 12. The agent investigates, finds that Anna owns LinkedIn, and drafts a Slack message. The founder approves it, and Anna's reply becomes a fact. |
| 4 | Release 2.1. FreshMart says it wants 40 stores in Q1, but only in a meeting. |
| Close | October numbers come in. The agent drafts the update, and a separate verifier flags the "40 stores" claim as unconfirmed. |

The week 3 chase, step by step:

```mermaid
sequenceDiagram
    participant S as Sources
    participant A as Agent
    participant F as Founder
    participant T as Anna, Head of Growth
    S->>A: LinkedIn: demos 44 → 12
    A->>A: Anomaly. Look for the cause in other sources
    A->>A: team_directory: LinkedIn belongs to Anna
    A->>F: Draft Slack message, waiting for approval
    F->>A: Approve
    A->>T: Message sent
    T->>A: "Our LinkedIn ad account got suspended on Oct 14 because the company card expired."
    A->>F: New pending fact from the reply
    F->>A: Confirm
```

For the hackathon pitch the same story runs on the speech-to-text partner
[Reson8](https://www.reson8.dev/), using the dataset and code changes in
[`demo/`](demo/).

## How it works

```mermaid
flowchart LR
    subgraph Sources["Sources (mocked)"]
        GH[GitHub]
        JM[Jamie meetings]
        HS[HubSpot]
        LI[LinkedIn]
        ST[Stripe]
    end
    IN["Founder: chat, voice (Reson8),<br/>documents · teammate replies"]
    Sources -->|"SourceConnector.fetch(since, until)"| AG
    IN --> AG
    AG["Claude agent loop<br/>4 runs · 10 tools"] -->|ledger_propose| LG[("Facts ledger")]
    AG -->|message_teammate| OUT["Message drafts"]
    OUT -->|founder approves| SENT["Sent"]
    LG -->|confirmed facts only| RP["Report"]
    RP --> VF{{"Verifier<br/>separate Claude call"}}
    LG --> VF
    VF -->|unsupported claim| FL["Flagged: Unconfirmed"]
```

It is one Flutter macOS app with a [shadcn_ui](https://pub.dev/packages/shadcn_ui)
interface. Everything runs locally except the Claude and Reson8 API calls.

### Four agent runs, one tool set

| Run | Trigger | Ends with |
| --- | --- | --- |
| A. Weekly check-in | Founder-set cadence ("Next week") | Check-in card: facts to confirm, 1 to 3 questions |
| B. Anomaly investigation | A metric drops sharply (demos −73%) | A message draft to the owner, waiting for approval |
| C. Inbound processing | Founder chat, voice, document, or a teammate's reply | Proposed facts in the ledger |
| D. Period report | End of the month | An update built from confirmed facts, checked by a separate verifier call |

Tools: `list_sources`, `fetch_source`, `ledger_search`, `ledger_propose`, `suggest_kpi`,
`team_directory`, `ask_founder`, `message_teammate` (needs approval), `submit_report`,
`verify_claims`. The tools run locally and deterministically. The model chooses which to
call and writes the text. The KPI table is computed from the ledger in code, and the model
never writes it.

### How a fact gets into the update

```mermaid
stateDiagram-v2
    direction LR
    [*] --> Pending: agent proposes from a source
    Pending --> Confirmed: founder confirms or edits
    Pending --> Dismissed: founder dismisses
    Confirmed --> Report: report writer sees only these
    Dismissed --> [*]: kept on record, never reported
```

The verifier gets each claim in the draft together with the ledger facts it cites, and
nothing else. It never sees the reasoning that produced the report, so it can't be talked
into agreeing with it.

## What is mocked, and how real connectors plug in

- **Sources** are timestamped JSON in `assets/mock/`. Each connector only returns data up
  to the simulated date. A real connector implements the same
  `SourceConnector.fetch(since, until)`: OAuth for GitHub, HubSpot, Stripe and LinkedIn,
  the Jamie API for meetings, and Computer Use for dashboards without an API.
- **Scheduling.** The "Next week" button stands in for a cron job per founder. Anomaly
  checks would run from webhooks.
- **Teammate messages.** Drafts are approved in the app and shown as sent. Replies come
  from the "Simulate reply" button. Slack, WhatsApp and email are all channels of the same
  `message_teammate` tool.

## Partner tech

| | Role |
| --- | --- |
| **Claude** (`claude-sonnet-5-5`) | The agent loop for all four runs, plus the separate verifier. |
| **Reson8** | Voice input through the prerecorded speech-to-text API, biased with a custom model of startup vocabulary (ARR, NRR, churn, runway, company and people names). |
| **Jamie** | Meeting notes as a source (mocked). Two of the month's most important facts were only ever said out loud. |

## Repo layout

```
lib/
  agent/     Claude client (manual tool-use loop), tools, prompts, the four runs, scripted fallback
  data/      source connectors and the team directory
  models/    facts, feed items, messages, report, agent runs
  ui/        shell, feed, facts, messages, report, sources, settings
  voice/     Reson8 client
assets/mock/ the October dataset, one JSON file per source
test/        demo_flow_test.dart runs the whole October scenario in scripted mode
demo/        pitch deck, script, shot list, Reson8 dataset, investor report, handoff notes, work log
```

## Tests

```bash
flutter test
```

`test/demo_flow_test.dart` runs the whole October scenario in scripted mode and checks the
final report. It asserts the Shelfwise numbers, so update it if you swap in the Reson8 data
(see [`demo/HANDOFF.md`](demo/HANDOFF.md)).

## Presenting it

Everything for the pitch is in [`demo/`](demo/):

- **Deck:** HTML that runs offline in Chrome.
- **Script:** narration in 3, 5½ and 8 minute cuts.
- **Shot list:** for the backup recording.
- **Pitch review:** independent judges scored the pitch against Ogilvy's 15 principles, 84.5/100 after three rounds of edits.
- **Investor report:** a sample October investor update (PDF), with a default alive map,
  new customers and challenges.

Start with [`demo/README.md`](demo/README.md). [`demo/HANDOFF.md`](demo/HANDOFF.md) says
what whoever drives the app needs to do, and [`demo/WORKLOG.md`](demo/WORKLOG.md) records every
change to the kit, PR by PR.

<p align="center"><img src="demo/img/report-default-alive.png" width="560" alt="Investor report: default alive verdict, revenue against expenses, cash curve and the dead or alive map"></p>

<p align="center"><img src="demo/img/slide-architecture.png" width="760" alt="Architecture slide, 'Why it can't make up a number': six sources feed a Claude agent with four jobs; facts go to a fact list; the report computes its numbers in code and a second Claude check reads only the confirmed facts."></p>
