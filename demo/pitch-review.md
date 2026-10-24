# Pitch review

The deck and script together, scored against the 15 Ogilvy principles in
[PITCH_REVIEWER.md](https://github.com/Siddhant-Goswami/100x-LLM/blob/main/prompts/PITCH_REVIEWER.md),
each worth about 6.7 points.

## How it was scored

An earlier version of this file gave the deck 89/100, but the same model that wrote the
edits had marked its own work. This time each version was scored by two separate judges that
had not seen the earlier review. They had only the rubric, `deck.html` and `script.md`.
The judges were told to be strict: placeholders, unsupported claims, jargon and weak hooks
all cost points. They also rated how human the copy sounds, from 1 to 10, and quoted the
lines that sounded AI-written. Every round got the same judge prompt.

These are still model judgments, not measurements. The rehearsal checks at the end of
`script.md` are how you find out whether they hold with a real listener.

| Version | Judge 1 | Judge 2 | Average | Sounds human |
| --- | --- | --- | --- | --- |
| Before (the deck on `main` after PR #2) | 76 | 77 | **76.5** | 7, 7 |
| Round 1: evidence, placeholders, hook, jargon, humanizer pass | 81 | 85 | **83** | 7, 8 |
| Round 2: title, timings, judges' ask, second humanizer pass | 82 | 84 | **83** | 7, 7 |
| Round 3: headline with a verb, last flagged lines | 86 | 83 | **84.5** | 8, 7 |

## Score by principle

Averages of the two judges, before and after round 3.

| # | Principle | Before | After | What changed |
| --- | --- | --- | --- | --- |
| 1 | Positioning | 5.7 | 6.1 | Title slide says who it's for and what they get, before anything else. |
| 2 | Unique benefit | 5.6 | 5.9 | "Every number shows its source" now sits in the headline, not just the subtitle. |
| 3 | Headline | 5.1 | 5.8 | "Your update is already written. Every number shows its source." Benefit and proof in one line. |
| 4 | Reader-focused | 5.3 | 5.7 | Architecture slide is now "Why it can't make up a number", so it answers a founder's worry. |
| 5 | Clear tone | 5.6 | 5.9 | Slogans such as "That is the product" and "memory flatters" replaced with plain sentences. |
| 6 | Simple language | 4.5 | 5.2 | NRR and default alive defined, tool names and "strict JSON" moved to the Long cut. |
| 7 | Evidence | 2.7 | 4.1 | Empty yellow placeholder replaced with a named, caveated source (Visible). The memory curve now follows Ebbinghaus, with its limits stated. |
| 8 | Emotion and story | 5.6 | 5.8 | Close ends on the fourteen clinics by name. |
| 9 | Structure | 5.3 | 6.0 | No visible placeholders. The "not found" backup slide removes itself when there's no recording. |
| 10 | Call to action | 4.7 | 5.6 | "Owe investors an update this month? Run it on yours tonight." The judges get an ask too: pick any number and we open its source. |
| 11 | Visuals and captions | 4.9 | 5.8 | Evidence stat card on slide 2, the curve is redrawn, and the label collisions are fixed. |
| 12 | Testability | 6.0 | 6.1 | A/B opener and title kept, with the current choice marked. |
| 13 | Length | 5.1 | 5.5 | Demo timing now agrees everywhere (2:15, 75s in the Short cut). Standard is the default cut. |
| 14 | Attention-grabbing | 4.9 | 5.8 | The hands-up opener is the default now, not an alternative. |
| 15 | Repetition | 5.9 | 6.0 | "Source" and the fourteen clinics come back at the right moments. |

## What's left, and why no copy edit fixes it

Every judge in every round put **evidence** first. The score stopped climbing at about
84 because the remaining points need things only you can collect:

1. **Founder answers.** Ask three to five founders at the event when they last wrote an
   update and how long it took. Say the best answer on slide 2 in place of the Visible line.
   My estimate is that this lifts evidence from about 4 to 5.5, roughly +1.5 overall.
2. **A team name.** Most judges marked it as missing. Say it on slide 1 and put it on the slide.
3. **One measured result,** if you have time: how long the demo month took to confirm, or
   how many facts the agent proposed against how many you kept.

The judges also kept naming the partners slide and the dense architecture diagram as the
weakest part of the middle. Cutting the partners section to one line per partner in the
Short cut would help with length and reader focus.

## The humanizer passes

The copy went through the humanizer skill twice, then the round 3 judges' flagged lines were
fixed by hand. Lines that went:

| Before | After |
| --- | --- |
| We did not make the update quicker to write. We made it possible to check. | You confirm facts each week instead of losing an evening on the 31st, and your investors get numbers they can check. |
| The fix is not a better writer in week four. It is capturing in week one. | So capture it in week one, while you still remember it. |
| So the report is not reporting. It is reconstruction from memory, and memory flatters. | By then you are rebuilding the month from memory, and memory keeps the good parts. |
| The best line in the update is the one we refused to state as fact. That is the product. | The best line in our update, the fourteen clinics, is the one the agent wouldn't let us claim. |
| Each partner carries a piece we could not have built. | Three parts we didn't build ourselves. |
| Start at the monthly update. End as the record of everything a founder has to prove. | The monthly update comes first. The same facts can fill a board pack or a diligence request later. |
| That's an audit trail, not a summary. | That gives you an audit trail. |

The final judges still flagged "Confirm, don't write", "Take Jamie out and the story stops
working" and the PULL / MOAT / WEDGE labels on the optional business slide. Those were left
in on purpose: the first is the product's rule, the second is the honest reason Jamie is in
the stack, and the third is on an optional slide.

## The pitch, rewritten

A written version for submission forms and the repo description. It follows the deck.

> **Your investor update is already written, and every number shows its source.**
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
> At month end the update is built only from facts you confirmed, and the numbers are
> computed in code. Click any figure to see where it came from. A second check flags every
> claim with no written source, like a customer's "all 14 clinics in Q1" that was only said
> in a meeting.
>
> Owe investors an update this month? Run it on yours tonight:
> github.com/seanjanke/Agentic-Investor-Updates. No API key needed.
