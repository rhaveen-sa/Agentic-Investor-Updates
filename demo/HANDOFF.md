# Handoff: switch the demo to Reson8

For whoever is running the app. Everything here is a copy-paste edit against
`seanjanke/Agentic-Investor-Updates` at the commit I read on 24 Oct.

---

## 1. Check the demo is really live

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

---

## 2. Drop in the Reson8 data

```bash
cp demo/reson8-mock/*.json assets/mock/
```

Seven files, same schema and same filenames as the originals: `baseline.json`,
`github.json`, `hubspot.json`, `jamie.json`, `linkedin.json`, `stripe.json`,
`slack_replies.json`. All validated as JSON.

The demo arc is unchanged, so the scripted path and the anomaly detector behave exactly as
before. Weekly demo bookings run 29, 41, 11, 34. The week 2 to week 3 drop is 73.2%, which
matches the 73% the old Shelfwise data produced, so nothing that keys off the anomaly
threshold needs retuning.

Numbers, for reference:

| | September | October |
|---|---|---|
| ARR | €352k | €413k (+17.3%) |
| Paying teams | 41 | 44 |
| NRR | 104% | 112% |
| Net burn | €198k | €231k |
| Cash | €4.12M | €3.89M |
| Runway | 21 months | 17 months |

September figures live in `baseline.json`, October in `stripe.json` and `hubspot.json`.

---

## 3. Team directory

`lib/data/connectors.dart:105`

```dart
const teamDirectory = [
  Teammate('Thomas', 'CEO & co-founder', ['sales', 'CRM (HubSpot)', 'finance (Stripe, bank)', 'investor relations'],
      {'slack': '@thomas', 'email': 'thomas@reson8.dev'}),
  Teammate('Jarno', 'CTO & co-founder', ['product', 'engineering', 'GitHub', 'model training', 'uptime', 'hiring engineers'],
      {'slack': '@jarno', 'whatsapp': '+31 6 0000 0001', 'email': 'jarno@reson8.dev'}),
  Teammate('Mirte', 'Head of Growth', ['marketing', 'LinkedIn ads & posts', 'website analytics', 'demo bookings'],
      {'slack': '@mirte', 'whatsapp': '+31 6 0000 0002', 'email': 'mirte@reson8.dev'}),
];
```

Thomas Kluiters and Jarno Verhagen are real co-founders and only ever appear in a good
light. Mirte is invented, and that is deliberate: the week 3 anomaly names a teammate as
the cause of a problem, and that should not land on a real person. Keep it that way.

Raoul Ritter, the third real co-founder, is mentioned once in a Jamie meeting note as an
attendee and nowhere else.

---

## 4. Sidebar

`lib/ui/shell.dart:103` and `:120`

```dart
Text('Reson8', style: tt.large.copyWith(fontSize: 15)),
```

```dart
ShadAvatar('', placeholder: const Text('T'), size: const Size(30, 30)),
const SizedBox(width: 10),
Expanded(child: Text('Thomas', style: tt.small)),
```

---

## 5. Prompts

`lib/agent/prompts.dart:2`

```
You are the investor-update agent of Reson8 (Resonate Labs B.V.), an Amsterdam speech-recognition
company selling a domain-adaptable ASR API for 10 European languages (€5M pre-seed in March 2026
led by Balderton Capital, 11 people). You work for Thomas (CEO, co-founder). Jarno is CTO,
Mirte is Head of Growth.
```

Line 15 uses a Shelfwise example inside the `statement_only` definition. Swap it so the
model is not primed with grocery vocabulary:

```
... e.g. "they want to roll out to all 14 clinics".
```

Lines 36, 37, 45, 52, 53, 72: replace `Lena` with `Thomas`.

Lines 75 and 86: replace `Shelfwise` with `Reson8`, so the subject line reads
`"Reson8 – October 2026 update"`.

---

## 6. Scripted fallback

`lib/agent/scripted.dart`. This is the path that runs with no API key, so it has to match
or the backup demo contradicts the live one.

Line 35:
```dart
['Demo bookings fell from 41 to 11. I\'m checking with Mirte. Do you already know what happened?'],
```

Line 38:
```dart
['Noorderlicht said they want all 14 clinics in Q1. Is there anything in writing yet?'],
```

Lines 101 to 109: `'Anna'` becomes `'Mirte'`, `Lena\'s update agent` becomes
`Thomas\'s update agent`, and the reason becomes
`'Mirte owns LinkedIn and demo bookings. The sources show the drop but not why.'`

Line 124:
```dart
{'text': 'LinkedIn posts paused for two days (Mirte out sick), back on schedule', 'kind': 'context'},
```

Line 131: `Lena estimates` becomes `Thomas estimates`.

Line 167: `subject: 'Reson8 – October 2026 update',`

The five `_summaries` entries, lines 41 to 48:

```dart
const _summaries = [
  'Good first week: 2 new teams (+€19k ARR), barge-in tuning shipped for the Turns API, and 29 demos from the new LinkedIn campaign. '
      'Balderton asked for NRR in the next update, so I suggest adding it to the KPIs.',
  'Big week: Release 1.8 takes us to 10 GA languages, and Noorderlicht Zorggroep signed a paid pilot for 9 clinics (+€41k ARR). '
      'The WER benchmark post drove a record 41 demos.',
  'Mixed week: realtime p95 latency is down 38%, but one team churned (−€7k ARR) and demo bookings dropped to 11 with no LinkedIn activity.',
  'Release 1.9 shipped diarization v2, 1 new team (+€8k ARR) and demos recovered to 34. Noorderlicht wants all 14 clinics in Q1, but that was only said in the pilot review.',
  'October closed at €413k ARR (+17.3%) and 44 paying teams. Net burn rose to €231k, runway is now 17 months.',
];
```

---

## 7. Names hardcoded elsewhere

Sections 3 to 6 cover the big ones. These are the rest. The first two break the demo if
you skip them.

`lib/agent/tools.dart:58` and `:101`. The tool schemas are strict, so the model can only
name owners from these enums. The Reson8 data uses Thomas, Jarno and Mirte.

```dart
'owner': {'type': 'string', 'enum': ['Thomas', 'Jarno', 'Mirte']},
```

```dart
'person': {'type': 'string', 'enum': ['Jarno', 'Mirte']},
```

`lib/voice/reson8_client.dart:16`. This is the vocabulary Reson8 is biased with, and it is
the whole point of the voice beat. Replace the Shelfwise line with:

```dart
  'Reson8', 'Resonate Labs', 'Noorderlicht', 'Noorderlicht Zorggroep', 'Balderton', 'Thomas', 'Jarno', 'Mirte',
  'Turns API', 'diarization', 'speech engineers', 'Release 1.8', 'Release 1.9',
```

On line 19, swap `'171k', '668k'` for `'231k', '413k'`. On lines 73 and 74, rename the
custom model to `reson8-investor-updates` and the description to `... for Reson8`.

The remaining spots are display text. Replace `Lena` with `Thomas`, `Shelfwise` with
`Reson8`, and `Northstar Ventures` with `Balderton Capital`:

| File | Lines |
| --- | --- |
| `lib/main.dart` | 18 (window title) |
| `lib/app_state.dart` | 127, 139, 141, 291 (Slack webhook text), 342, 360 |
| `lib/agent/runs.dart` | 233, 242, 249, 343 (`'Reson8 – October 2026 update'`) |
| `lib/agent/tools.dart` | 246 (default owner) |
| `lib/agent/scripted.dart` | 83: the reason becomes `'Lead investor (Balderton) asked for NRR in the next update (Jamie, Oct 3).'` |
| `lib/ui/report_screen.dart` | 69 (the To line), 81 and 318 (the sign-off) |

---

## 8. Tests

`test/demo_flow_test.dart` asserts the old October numbers, so it will fail after the swap.
Update the expected ARR to 413000, customers to 44 and runway to 17, or mark it skipped
before the demo. Do not leave it failing and unexplained if a judge looks at CI.

---

## 9. Before you present

- [ ] A live run shows `claude-sonnet-5-5` in the model row of an expanded message, not `scripted` or `fallback`
- [ ] No Shelfwise names left. This should print nothing: `grep -rniwE "shelfwise|lena|anna|tom|mara|northstar|freshmart" lib/ assets/mock/`
- [ ] The week 3 anomaly still fires and drafts a message to Mirte
- [ ] Dictate a sentence with "Noorderlicht" and "NRR" in it. Both come back spelled right
- [ ] The verifier still flags the 14 clinics claim
- [ ] `flutter test` passes or is knowingly skipped

---

## A note on the data

Everything in `reson8-mock/` that is not public is invented. Public and checkable: the
€5M pre-seed led by Balderton with NP-Hard, March 2026, Amsterdam, Resonate Labs B.V., the
three founders, 10 supported languages, the Prerecorded, Realtime and Turns endpoints, ISO
27001, GDPR, EU AI Act, zero audio retention, and the Free, Pro at €20, Growth at €100 and
Enterprise pricing tiers.

Invented: every revenue, burn, cash, runway, customer-count and demo figure, all customer
names (Noorderlicht Zorggroep, Van Dijk Advocaten, Contactpunt BV, Helder Notarissen,
Brugman Verzekeringen), Mirte, and all release contents.

The deck carries a visible line saying so. Leave it on screen.
