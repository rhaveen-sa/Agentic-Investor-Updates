# Pitch review

The deck and script scored against the 15 Ogilvy principles in
[PITCH_REVIEWER.md](https://github.com/Siddhant-Goswami/100x-LLM/blob/main/prompts/PITCH_REVIEWER.md),
each worth about 6.7 points. "Before" is the deck as first pushed. "After" is this folder.

These are one reviewer's judgment calls, not measurements. The rehearsal checks at the end
of `script.md` are how you find out whether they hold with a real listener.

## Score

**Before: 80/100. After: 89/100.** Filling in the evidence line on slide 2 with real answers
from founders at the event should add about 4 more. No copy edit can earn those points.

| # | Principle | Before | After | Comments |
| --- | --- | --- | --- | --- |
| 1 | Positioning | 5.5 | 6.5 | The offer was clear, but the deck never said who it was for. The title slide now opens with "For founders who owe investors a monthly update." |
| 2 | Unique benefit | 6.0 | 6.0 | "Every number opens its own source" is specific, and no other demo will claim it. Unchanged. |
| 3 | Headline | 6.0 | 6.0 | "The update is already written." is benefit-led and makes people curious. `script.md` now has a second headline to test against it. |
| 4 | Reader-focused | 6.0 | 6.0 | Written to "you" throughout. The problem slide describes the founder's night, not the product. |
| 5 | Clear tone | 6.2 | 6.2 | Plain and dry. The agent's cheeky voice stays inside the app, where it belongs. |
| 6 | Simple language | 5.3 | 6.0 | "ASR" appeared three times on the partner slide. It now says "speech-to-text". "Ledger" stays, because slide 4 shows what it is. |
| 7 | Evidence | 3.5 | 4.5 | The weakest score. The demo proves the product works but nothing proves the problem is real. Slide 2 now has a marked slot for answers you collect at the event. The deck says nothing it can't back up, so the slot stays empty until you fill it. |
| 8 | Emotion and story | 5.8 | 5.8 | The 11pm blank doc and "you remember the wins faster than the churn" carry it. The flagged claim at the end is the payoff. |
| 9 | Structure | 6.2 | 6.2 | One idea per slide, and every slide ends on a kicker line. |
| 10 | Call to action | 2.5 | 5.5 | There was none. The close now gives the repo and says it runs without an API key, and the script says it out loud before the last line. It is still not an ask to judges, because a hackathon pitch rarely needs one. |
| 11 | Visuals and captions | 6.0 | 6.3 | Strong already: decay curve, source card, architecture, the speech-to-text comparison. Fixed: the demo slide listed the voice beat after week 3, while the script and shot list do it in week 1. |
| 12 | Testability | 3.5 | 6.0 | Nothing was measurable. `script.md` now ends with four pass/fail rehearsal checks, including an A/B on the title line and the opener. |
| 13 | Length | 6.0 | 6.0 | Fine, but the stated timings were wrong: the "3 minute" core added up to about 4:40, and the "110 second" recording to 2:16. Now three cuts that add up: 3:00, 5:30, 8:00. |
| 14 | Attention-grabbing | 5.0 | 5.5 | The title slide is calm, and the hook arrives on slide 2. An optional hands-up opener in the script gets the room in the first ten seconds. |
| 15 | Repetition | 6.0 | 6.0 | "Opens its source" appears on the title, product and close slides, and the demo shows it twice. |

## Top three areas to improve

1. **Evidence.** Ask founders at the event when they wrote their last update and how long
   it took. Even three answers beat none. Put the best one in the yellow slot on slide 2,
   or delete the slot.
2. **Call to action.** Done in this pass. The repo line on the close slide is the only
   thing in the deck that tells anyone what to do next. Keep it.
3. **Testability.** Run the rehearsal checks in `script.md` on one person who hasn't seen
   the project, and keep whichever title and opener wins.

## Other fixes made in this pass

- The partner slide said Claude Sonnet 5. The app calls `claude-sonnet-5-5`, so it now
  says Sonnet 5.5.
- The close slide headline said "There is no third option", and the next line offered a
  third option. It now reads "Today investors can believe your update or not. They can't
  check it."
- The first push changed the app's model to `claude-sonnet-5` and called the original a
  bug. That was wrong: `claude-sonnet-5-5` is a valid ID. The change is reverted and
  `HANDOFF.md` corrected.
- The deck and script said a dismissed fact is stored so it isn't proposed again. The
  code doesn't do that: `ledger_propose` only dedupes against facts that aren't dismissed.
  Both now say what is true, which is that a dismissed fact stays on record and never
  reaches the report.

## The pitch, rewritten

A written version for submission forms and the repo description. It follows the deck.

> **Every number in your investor update, with its source.**
>
> If you run a funded startup, you owe your investors an update every month. You write it
> late on the 31st, rebuilding the month from Slack, Stripe and memory, and memory keeps
> the wins and drops the churn. Your investors can't check any of it.
>
> Investor Update Agent collects the month while it happens. Every week it reads GitHub,
> Stripe, HubSpot, LinkedIn and your meeting notes, then shows you what it found. You
> confirm, edit or dismiss each fact. When a number drops, it works out who owns it and
> drafts them a message, which sends only after you approve it.
>
> At month end the update is already written, built only from facts you confirmed. Click
> any figure to see where it came from. A separate verifier flags every claim that has no
> written source, like a customer's "all 14 clinics in Q1" that was only said in a meeting.
>
> Try it on your own month: github.com/seanjanke/Agentic-Investor-Updates. It runs without
> an API key.
