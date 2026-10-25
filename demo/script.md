# Narration script

Deck: `deck.html`. Arrows navigate, `F` fullscreen, `S` speaker notes, `O` optional slides.

Standard is the default. Switch to Short or Long only if the organisers give you a different slot.

| Cut | Length | What you do |
| --- | --- | --- |
| Short | about 3:00 | Sections 1, 2, 4, 5, 7 and 8. Click past the insight and architecture slides, saying only their bottom line. Demo is the 75 second path below. |
| Standard | about 5:30 | Every unmarked block, with the full demo from `shotlist.md` (about 2:15). Optional slides hidden: the deck starts that way, and `O` toggles them. |
| Long | about 8:00 | Standard plus the **[Long]** blocks and the four optional slides. |

The section timings below are for the Standard cut and assume about 135 words a minute.
Read it against a stopwatch once. If you run over, cut from sections 2 and 3 and never
from the demo.

**75 second demo path (Short cut):** shot 1 (week 1 check-in), shot 4 (voice), shots 5 and 6
(week 2, then week 3 and send the anomaly message), shot 8 (week 4 and close the month),
shot 10 (click €413k), shot 11 (the claim that wasn't counted). Shot numbers refer to
`shotlist.md`.

The founder on screen is **Thomas**, CEO of Reson8. The teammate who owns LinkedIn is
**Mirte**, who is invented. The two real co-founders, Thomas Kluiters and Jarno Verhagen,
only ever appear in a good light.

---

## 1. Title, 15 seconds

Open on the room before you say what the product is:

> Hands up if you've written an investor update after 11pm. Keep it up if you could prove
> every number in it.

Wait for the hands to drop. Say your team name, then read the title:

> Your update is already written, and every number shows its source. We built an agent for
> founders who owe investors a monthly update: Agentic Investor Updates. It collects your
> month while it happens, and you confirm each fact before it reaches your investors.

Name the Reson8 thing once, lightly, then move on:

> We're running it on Reson8's own numbers, because that was more fun than inventing a company.
> The funding and the product are real. The revenue figures are not.

Then stop. Slide 2 explains the product.

**A/B for rehearsal.** The other opener to test is a cold start on slide 1: *"It's the 31st.
The update is due."* Keep whichever gets the faster nod from your test listener.

---

## 2. Problem, 30 seconds

> It's the 31st. The update is due.
>
> You open a blank doc at eleven at night and you start scrolling. Slack, Stripe, GitHub,
> your own calendar, rebuilding a month you already lived.

Beat.

> And nobody writes this part down: **you remember the wins faster than the churn.**

Pause. Let it sit. This is the line founders in the room recognise.

> Investors get it three days late, and they cannot check a single number in it.

Point at the footnote:

> Visible, who sell investor-update software, say 60% of investors don't hear from their
> companies regularly. They also say startups that do send updates are three times as likely
> to raise follow-on money. They haven't published the data, so treat it as their figure.

**Better, if you can get it:** ask three founders at the event when they wrote their last
update and how long it took. If you have a good answer, say it here in place of the Visible line.

---

## 3. Insight, 25 seconds

> The hard part is remembering, so that's the part we fixed.

Gesture at the curve.

> Ebbinghaus measured this in 1885. Most new detail fades within days, and after a month
> about a fifth is left. A month is exactly when you sit down to write.
>
> So you rebuild the month from memory, and memory keeps the good parts.
>
> Capture it in week one, while you still remember it.

---

## 4. Product, 35 seconds

> So the agent works all month, and at month end you only approve.
> Three rules.
>
> **One, confirm rather than write.** Every week it shows you what it already found. You
> confirm, edit or dismiss. There's no blank page.
>
> **Two, it chases the gaps.** When a number looks wrong it doesn't guess. It works out who
> owns that number and drafts them a message. Nothing sends until you approve it.
>
> **Three, every number opens its source.**

Point at the card.

> The update is assembled only from facts you confirmed. Click any figure and you get this:
> the fact, where it came from, when, and who owns it.

---

## 5. Demo, about 2:15 (75 seconds in the Short cut)

Switch windows now. The full click-path is in `shotlist.md`. Narrate lightly and let the
app's own copy do the work.

**Week 1.** Pick **Oct 7** in the week selector and click *Run the week 1 check-in*.

> It has already read GitHub, Stripe, HubSpot, LinkedIn and the meeting notes. It tells me
> what happened and asks me to sign off.

Expand the step list to show what it did.

> Those are the steps it took: read the source, check the ledger, propose a fact.

**[Long]** add: *"Ten tools, strict JSON, and they all run on this laptop."*

**The NRR beat.**

> Jamie picked up our lead investor asking for net revenue retention, NRR, in the next
> update. That was said out loud on a call and written down nowhere. The agent suggests
> adding NRR to the KPIs, and I click Add.

**The voice beat.** Tap the mic and dictate the burn note.

> And I can just talk to it. That's Reson8 transcribing Reson8's CEO, which I'm aware is a
> little recursive. The point is the vocabulary: it writes NRR and Noorderlicht, where a
> generic engine gives you "an are are".

**Week 3.** Let the anomaly card breathe.

> Demos fell from 41 to 11. It found the gap, worked out who owns LinkedIn, and drafted the
> message. I send it, Mirte replies, and her answer becomes a fact in the ledger.

**The report.**

> Every figure is clickable.

Click ARR.

> Source. Stripe, month close, 31 October.

**The flag.** Slow down here.

> And this is the one I care about. Noorderlicht want all fourteen clinics in Q1. It's the
> best line in the whole update, and the verifier took it out. It sits under **Pipeline we
> are not counting yet**, because it was said in a meeting and nobody has put it in writing.
>
> It won't let me state it as a fact.

### If the demo stalls

Count to four, then say this without apologising:

> I'll show you the recording, it's the same run.

Press the right arrow and play the backup. Do not debug on stage. Keep narrating over the
video with the same beats.

---

## 6. Under the hood, 30 seconds

> Here's why it can't make up a number.
>
> Six sources feed one agent. Everything it learns goes on a list of facts, which we call the
> ledger, and you confirm or dismiss each one. The report is drafted from the confirmed facts only, and the
> numbers in it are computed in code, so the model only writes the sentences around them.

Tap the verifier box.

> Then a second Claude call checks the draft. It sees the ledger and nothing else, not the
> reasoning behind the report, so it can't be talked into agreeing with it.

**[Long]** add:

> The agent runs four jobs on the same ten tools: the weekly check-in, chasing anomalies,
> taking input from chat, voice or documents, and writing the report.

---

## 7. Partners, 30 seconds

> Three pieces we didn't build.
>
> **Claude** runs the loop and then checks its own work.
>
> **Jamie** is the one I'd point at. Two of the most important facts this month were spoken
> out loud in a room and never typed anywhere: our lead investor asking for NRR, and the
> fourteen clinics. No API has those, but Jamie does. Take Jamie out and the story stops working.
>
> And **Reson8** is why the founder can just talk.

Point at the comparison.

> Same sentence, two engines. A generic model gives you "an are are". Hand Reson8 the
> vocabulary a founder actually uses and you get NRR, Noorderlicht, Q1.

**[Long]** add:

> All three are EU hosted. In the demo month, EU-only processing is what cleared Noorderlicht's privacy review.

---

## 8. Close, 25 seconds

> An investor update is the main thing your investors have to go on. Right now they either
> believe it or they don't, because there's no way to check it.
>
> With this, every fact comes in weekly from its source, and nothing reaches the update
> without one. A confirmed lowlight goes in the same way a win does.

Beat.

> You confirm facts each week instead of losing an evening on the 31st, and your investors
> get numbers they can check.
>
> Judges, pick any number on the report and we'll open its source for you right now.
>
> If you owe investors an update this month, run it on yours tonight. It's on GitHub, it
> needs no API key, and we'd love to hear which number it got wrong.

Beat. Then the last line:

> The best line in our update, the fourteen clinics, is the one the agent wouldn't let us claim.

Stop. Don't add anything after that.

---

## Optional slides, press `O`

| Slide | Reach for it when |
| --- | --- |
| The ledger | "How does a fact become a number?" Shows the proposed, pending, confirmed, dismissed lifecycle. |
| October at Reson8 | "What does the output actually look like?" The KPI table, the lowlights, the flagged claim. |
| What is real | "How much of this is mocked?" Answer it straight, the honesty buys credibility. |
| The business | A business-minded judge, or an investor on the panel. |

---

## Q&A

**Isn't this just summarisation?**

> A summariser reads the month at the end. We capture facts weekly at the source and the
> founder confirms each one, so the update is built from a ledger rather than from recall.
> That gives you an audit trail.

**What if the agent gets a fact wrong?**

> You dismiss it. It stays on record as dismissed and never reaches the report. Nothing
> reaches the update without a human confirming it.

**What stops it inventing a number?**

> Two things. The report writer only sees confirmed ledger facts. And the KPI table isn't
> written by the model at all, it's computed from the ledger in code. On top of that the
> verifier re-checks every claim and flags whatever it can't support, which is how the
> fourteen clinics got caught.

**Why would a founder trust it with investor comms?**

> They don't have to. They approve everything. No message sends and no update goes out
> without a click.

**How is this different from Jamie, or any notetaker?**

> Jamie captures a meeting. This captures a month across six systems and turns it into a
> document where every number is traceable. Jamie is one of our six sources.

**Is Reson8 going to make it?**

> The update answers that itself. It runs Paul Graham's default alive test on the confirmed
> numbers, which asks whether you reach profit on current growth before the cash runs out.
> At October's growth, revenue covers costs in 13 months with €1.83M left. It also
> says where that flips, at about 8.6% a month. The test is computed in code, so the model
> can't make it sound better than it is.

**What happens without an API key?**

> It runs. There's a scripted mode that replays the same decisions from the mock data
> through the same tools and the same interface, and a failed live run falls back to it
> automatically. That's also why this demo doesn't depend on conference wifi.

**Who pays for this?**

> Every funded startup owes investors an update monthly or quarterly, for the life of the
> company. The deadline is set by someone else, so the habit already exists and we attach
> to it rather than trying to create one.

**Are those Reson8's real numbers?**

> Mostly no, and the deck says so on screen. The funding, the founders, the ten languages,
> the API surface, the pricing and the SDK download counts are public. Revenue, burn, runway and the customer names are
> invented for the demo.

---

## Rehearsal checks

Run these on one test listener who hasn't seen the project. Each one is a pass or a fail,
so you can compare two versions of a slide or an opener.

| Check | Pass |
| --- | --- |
| Stopwatch on the chosen cut | Within 10 seconds of the target length |
| "What does it do?", asked right after slide 4 | They say some version of "it writes the investor update from facts you confirmed" |
| "What did you remember?", asked at the end | They mention the flagged claim or clicking a number to see its source |
| Title line A vs B | A, on the deck now: "Your update is already written. Every number shows its source." B: "Every number in your investor update, with its source." Swap only if B wins the check above. |
