# Demo video, shot list

About 2 minutes 15 seconds, recorded in one continuous take. The Short cut in
`script.md` uses a 75 second subset of the same shots live, but record the full take.

There is no video editor on the recording machine. QuickTime trims the start and end and
nothing else, so the demo has to work as a single unbroken click-path. That constraint
shaped this list: every beat flows into the next with no cuts, no window switching and no
backtracking.

Output: `demo-backup.mp4`, saved beside `deck.html`. The deck picks it up automatically.

The founder is **Thomas**. The teammate who owns LinkedIn is **Mirte**. The customer in the
flagged claim is **Noorderlicht Zorggroep**.

---

## Before recording

Screen:

- Resize the app window to 1280 by 800 and centre it.
- Hide the dock with `Option + Command + D` and clear the menu bar of anything noisy.
- Turn on Do Not Disturb. A notification banner mid-take kills the whole run.
- Quit anything that might bounce in the dock.

Capture:

- `Cmd + Shift + 5`, choose Record Selected Portion, drag over the app window only.
- Options: turn **Show Mouse Clicks** on, since the whole demo is about clicking things.
  Set Microphone to off and narrate live over the video instead of baking audio in.
- Save to Desktop, rename to `demo-backup.mp4`, move it next to `deck.html`.
- If it saves as `.mov`, either convert it or change the `<source src="demo-backup.mp4">`
  line in `deck.html` to match the real filename.

Rehearse the click-path three times before recording. The goal is one clean take rather
than a perfect one. Small hesitations are fine. A wrong click that needs undoing is not.

---

## The take

Written from the app code on `main` at `0926e58` (week selector, chat cards, report page).
It has not been checked against a running app. Rehearse it once and fix any label that
differs before you record.

| # | Time | Screen | Do this | What should land |
| --- | --- | --- | --- | --- |
| 1 | 0:00 to 0:10 | Agent | Start on **Week 1** in the week selector, on the "Good morning, Reson8" screen. Click **Run the week 1 check-in**. | The agent starts from the sources, not from a blank prompt box. |
| 2 | 0:10 to 0:22 | Agent | Let the step list run ("Looking up GitHub data for...", "Writing down a fact"), expand it for a second, then confirm two facts on the check-in card. | It really read the sources and wrote facts down. If an amber "Live run failed, finished with the backup run" row appears, stop and fix the key. |
| 3 | 0:22 to 0:30 | Agent | The card **Add NRR to the KPIs?** appears. Click **Add**. | The agent changed what gets reported because of something said out loud on a call. |
| 4 | 0:30 to 0:44 | Composer | Tap the microphone and say: *"Two speech engineers started on the fifth, so net burn for October is about 231k."* Let the transcript appear and become a pending fact. Confirm it. | **Reson8.** Hold on the transcript for two seconds. The vocabulary is the point. |
| 5 | 0:44 to 0:52 | Week selector | Pick **Week 2** and click **Run the week 2 check-in**. Let it flash past and confirm all. | A month compresses into seconds. The agent was working the whole time. |
| 6 | 0:52 to 1:10 | Agent | Pick **Week 3** and run it. Let the anomaly sit for three seconds, then click **Send** on the drafted message to Mirte. | Demos fell from 41 to 11, and the agent already knows who to ask. Give this room, it is the first moment that gets a reaction. |
| 7 | 1:10 to 1:22 | Agent | Click **Simulate reply from Mirte**. Her reply lands and becomes a pending fact. Confirm it. | Gap, question, message, reply, fact. The loop closes on screen. |
| 8 | 1:22 to 1:32 | Week selector | Pick **Week 4**, run it, then click **Close October and draft the update**. | The month is over and the update already exists. |
| 9 | 1:32 to 1:50 | Report | Open **Report**. Scroll steadily through In short, Ask, Key numbers, **Default alive or default dead?** with its three charts, and Customers. Pause on the dead or alive map. | The update answers the investor's real question, and the churn and shorter runway are in it too. |
| 10 | 1:50 to 1:58 | Report | Click **€413k**. The dialog opens, titled "Source for €413k". Close it. | Every number is traceable. This is the product's signature. |
| 11 | 1:58 to 2:10 | Report | Point at the amber **1 claim not counted** badge in the header, scroll to **Pipeline we are not counting yet**, and click the 14 clinics claim. The dialog shows a Jamie meeting note with an amber **Unconfirmed** tag. Hover the tag. | The money shot. Hold three full seconds. The tooltip reads "Only said in a meeting or chat, not backed by a system of record". |
| 12 | 2:10 to 2:16 | Report | Click **Approve & send**. End on "Sent to investors". | The founder stays in control. Clean ending. |

If you are running long, shorten shots 2 and 5. They are the least visual. **Download PDF**
is worth showing live in Q&A, not in the take.

---

## Pacing

- Move slower than feels right. Judges are reading unfamiliar UI, and what feels sluggish
  to you reads as confident to them.
- Don't move the mouse while something is loading. Jitter looks like a bug.
- Let each agent card sit two or three seconds before clicking. The copy is doing
  persuasion work and it is wasted if it flashes past.
- Three beats have to land cleanly: shot 4 (Reson8 spelling the vocabulary), shot 6 (the
  anomaly), shot 11 (the Unconfirmed flag). Everything else can be brisk.

---

## Check before you call it done

- [ ] No amber "Live run failed, finished with the backup run" row in any step list, and
      Settings > Agent has scripted mode off. Otherwise the run never reached Claude: check
      `ANTHROPIC_API_KEY` in `secrets.json` and start the app with
      `--dart-define-from-file=secrets.json`.
- [ ] No "Shelfwise", "Lena", "Anna" or "FreshMart" visible anywhere on screen.
- [ ] The report KPI table reads €413k, 44, 112%, €231k, €3.89M, 17 months.
- [ ] Default alive says break-even in November 2027 with €1.83M left.
- [ ] The header says 1 claim not counted, and it is the 14 clinics claim.

---

## If the app is not ready

Capture stills with Shottr and click through them in place of the video. Minimum set, in
order:

1. Agent view with the week 1 check-in card
2. An expanded step list
3. The week 3 anomaly with the drafted message to Mirte
4. Mirte's reply in the chat
5. The report, scrolled to the KPI table
6. A source dialog, open
7. Pipeline we are not counting yet, with the 14 clinics claim

Seven stills still tell the whole story. If even that is out of reach, present optional
slides 9 to 11 instead. They carry the ledger, the KPI table and the flagged claim as
static artwork.

---

## After recording

- [ ] Trim dead air off both ends in QuickTime: `Cmd + T`, drag the handles, `Cmd + S`.
- [ ] Rename to `demo-backup.mp4` and put it next to `deck.html`.
- [ ] Open the deck, go to the backup slide, confirm it loads and plays.
- [ ] Watch it once fullscreen. If a beat is unreadable, re-record the whole take rather
      than trying to patch it.
