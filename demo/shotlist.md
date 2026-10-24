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

| # | Time | Screen | Do this | What should land |
| --- | --- | --- | --- | --- |
| 1 | 0:00 to 0:12 | Agent | Start with the time bar on **Oct 7**. Let the check-in card sit for two seconds so the line is readable, then confirm two facts. | *"Morning Thomas. I did your homework: 4 things to confirm."* The agent opens with findings, not a prompt box. |
| 2 | 0:12 to 0:22 | Agent | Expand one agent message to show the model and its tool calls, one row each. Scroll it slowly, then collapse. | It really called `fetch_source`, `ledger_search`, `ledger_propose`. Not a canned script. The model row should read `claude-sonnet-5-5`. |
| 3 | 0:22 to 0:32 | Agent, Settings | Show the agent spotting the Jamie note about the lead investor wanting NRR. Open Settings just long enough to show **NRR now in the KPI set**, then close. | The agent changed its own reporting config because of something said out loud on a call. |
| 4 | 0:32 to 0:46 | Composer | Tap the microphone and say: *"Two speech engineers started on the fifth, so net burn for October is about 231k."* Let the transcript appear and become a pending fact. Confirm it. | **Reson8.** Hold on the transcript for two seconds. The vocabulary is the point. |
| 5 | 0:46 to 0:54 | Time bar | Click **Next week** twice. Let each check-in flash past without reading it. | A month compresses into seconds. The agent was working the whole time. |
| 6 | 0:54 to 1:12 | Agent | Land on **week 3**. Let the anomaly card breathe for three seconds, then click **Approve** on the drafted Slack message. | Demos fell from 41 to 11, and the agent already knows who to ask. Give this room, it is the first moment that gets a reaction. |
| 7 | 1:12 to 1:26 | Messages | Open Messages, show the sent message, click **Simulate reply**. Mirte's reply lands. Go back to Agent, where run C has turned it into a pending fact. Confirm it. | Gap, question, message, reply, fact. The loop closes on screen. |
| 8 | 1:26 to 1:34 | Time bar | Click **Next week** to reach the end of October. The report generates. | The month is over and the update already exists. |
| 9 | 1:34 to 1:50 | Report | Scroll steadily through TL;DR, the KPI table, **Default alive?**, highlights, **lowlights**, asks. Pause a beat on default alive and on the lowlights. | The update answers the investor's real question, and the churn and shorter runway are in it too. Neutrality is visible rather than claimed. |
| 10 | 1:50 to 2:00 | Report | Click **€413k**. The dialog opens, titled "Source for €413k". Close it. | Every number is traceable. This is the product's signature. |
| 11 | 2:00 to 2:12 | Report | Scroll to the claim about **all 14 clinics in Q1**, which carries the amber **Unconfirmed** tag. Click it. The source shows a Jamie meeting note and nothing else. Hover the tag so the tooltip shows. | The money shot. Hold three full seconds. The tooltip reads "Only said in a meeting or chat, not backed by a system of record." |
| 12 | 2:12 to 2:16 | Report | Click **Approve**. End on the approved state. | The founder stays in control. Clean ending. |

If you are running long, shots 2 and 3 are the ones to shorten. They are the least visual.

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

- [ ] The model row in shot 2 says `claude-sonnet-5-5`. If it says `scripted`, the app had no
      key or scripted mode is on. If it says `fallback`, the live call failed and the step shows
      the error. Either way the run never reached Claude: check `ANTHROPIC_API_KEY` in
      `secrets.json` and start the app with `--dart-define-from-file=secrets.json`.
- [ ] No "Shelfwise", "Lena", "Anna" or "FreshMart" visible anywhere on screen.
- [ ] The report KPI table reads 413k, 44, 112%, 231k, 3.89M, 17 months.
- [ ] The Default alive section says break-even in 13 months with €1.83M left.
- [ ] The 14 clinics claim carries the amber Unconfirmed tag.

---

## If the app is not ready

Capture stills with Shottr and click through them in place of the video. Minimum set, in
order:

1. Agent view with the week 1 check-in card
2. An expanded message showing the tool calls
3. The week 3 anomaly card with the drafted Slack message
4. Messages, with Mirte's reply
5. The report, scrolled to the KPI table
6. A source dialog, open
7. The flagged claim with its Unconfirmed tag

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
