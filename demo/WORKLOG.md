# Work log

What changed in the demo kit, when and why. Newest first. Every entry is also a PR on
GitHub, so this file and the PR list should always agree. If you change anything in `demo/`,
add an entry here and update `HANDOFF.md` (top of the repo) and the READMEs in the same PR.

## 25 Oct 2026 · After the hackathon: deck and handoff move to the top of the repo

- **Deck:** `demo/deck.pdf` and `demo/deck.html` are now **`pitch-deck.pdf`** and
  **`pitch-deck.html`** at the top of the repo. The HTML loads its screenshot from `demo/img/`
  and the backup video from `demo/demo-backup.mp4`.
- **Handoff:** `demo/HANDOFF.md` is now **`HANDOFF.md`** at the top of the repo, rewritten for
  after the hackathon. It covers what exists, how to run it, the pending-facts trap, the open
  items in order, the data notes and a map of the repo. The stage checklist is replaced by a
  pointer to `demo/`.
- **Links:** all links in the READMEs, script and shot list are updated. Older entries in this
  log keep the old paths, because they describe what was true then.

## 25 Oct 2026 · Name, a real run of the app, README rewrite

**Name.** The project is called **Agentic Investor Updates**, after the repo, in the
README, deck, script, sample report and the suggested GitHub description. The app still
says "Ledger" in five files. `HANDOFF.md` section 7 lists them, and this PR changes no app
code.

**Ran the app.** On a machine without Flutter or Xcode, we installed Flutter 3.47.8 in a
temp folder, ran `flutter test` (2 passed, live test skipped without a key) and built the
web version. Then we clicked through October in Chrome from the week 1 check-in to an
approved update. What that changed:

- **Week selector:** it shows dates (Oct 7, 14, 21, 28), not week numbers. The shot list,
  script and README now use the real labels.
- **Two confirm cards:** a week can have two **Confirm all** cards. Missing the second one
  leaves 6 facts pending, and the report then shows "6 claims not counted" and an ARR bridge
  that doesn't add up. The shot list, handoff and README now say to clear Facts before
  closing the month.
- **Month close:** after closing the month, the button is **Confirm & draft the update**.
- **Screenshots:** five real ones are in `img/app-*.png`. The README uses four, and the deck's
  demo slide uses one.

**README.** Rewritten for founders first:
- **Opening:** benefits, a two-minute quickstart that needs no keys, and the click path.
- **The month:** the demo month with screenshots.
- **Trust:** why it can't make up a number, and how we know it works.
- **Housekeeping:** the internals and the presenting notes are collapsed.

Two independent judges scored the Ogilvy rubric at 72.5 before and 84 after (see
`pitch-review.md`).

**Final humanizer pass.** The README, deck and script lines the last judges flagged were
rewritten. The README rewrite scored lower (82 against 84), so the README stays at the
round 2 version. Two more judges then scored the committed README straight from GitHub (82
and 79). Across four judges that file averages 82.25, against 72.5 before. In the deck, the "It checks its own work"
hook became "A second call checks the draft". The script lost "a month you already lived"
and "attach to it rather than create one". Fresh judges scored the final deck and script at 85 and 85,
up from 83.5. All scores are in `pitch-review.md`.

**GitHub About.** Not set. Your account doesn't have admin rights on the repo. The text is
in `HANDOFF.md` section 7 for Sean to paste.

## 24 Oct 2026 · Docs synced with the app at `0926e58`

Sean's commits `6b37f49`, `333f32c` and `0926e58` applied the Reson8 switch, renamed the
product to **Ledger**, replaced "Next week" with a week selector, moved messages into the
chat, and built the investor report into the app with charts and **Download PDF**. They
didn't touch `demo/`, so this update brings it in line:

- **`shotlist.md`:** the take is rewritten for the week selector, the chat cards
  (**Add**, **Send**, **Simulate reply from Mirte**), the "1 claim not counted" badge and
  **Approve & send**.
- **`script.md` and `deck.html`:** the product is called Ledger. The verifier now keeps the
  14 clinics claim out (shown as NOT COUNTED), and the "Morning Thomas" line is gone.
- **`HANDOFF.md`:** rewritten for the current app: the switch is done, the live check uses the
  amber backup-run row, and it explains the two copies of the report.
  - **Gap flagged:** the Report page has no demo-data note. Only its PDF does.
- **READMEs, `pitch-review.md` and the sample report:** renamed to Ledger and updated.

- **`deck.pdf` (new):** the deck as a 12-page 16:9 PDF, 8 talk slides plus 4 optional
  ones. It's exported from `deck.html` with headless Chrome.
- **`pitch-review.md`:** records the re-score of the synced pitch by two fresh judges, 81
  and 83 (average 82, against 76.5 before PR #3).

The shot list was written from the code and hasn't been checked against a running app.

## 24 Oct 2026 · PR #3 · Pitch score and investor report

**Pitch.** Three rounds of edits to `deck.html` and `script.md`. Two independent judges
scored each version against the PITCH_REVIEWER rubric, using the same prompt every round.
The average went from 76.5 to 84.5 (details in `pitch-review.md`).

- **Slide 2:** the empty yellow placeholder became a stat card citing Visible's figures. The
  card says Visible hasn't published the data behind them.
- **Insight curve:** redrawn to follow Ebbinghaus's forgetting curve, with its limits in the caption.
- **Placeholders:** removed `[TEAM NAME]` and `[PRESENTER]`. The backup slide now hides
  itself when `demo-backup.mp4` is missing.
- **Headline:** "Your update is already written. Every number shows its source."
- **Opening:** the script now starts with the hands-up line.
- **Plainer wording:** NRR and default alive are defined, and tool names moved to the Long cut.
- **Close:** the call to action speaks to founders, and there's a line for the judges ("pick
  any number").
- **Humanizer:** two passes, then the lines the judges still flagged were fixed by hand.
- **Slide images:** re-rendered in `img/`.

**Investor report.** New folder `investor-report/` with a full October update for Reson8
as PDF and HTML, generated from `reson8-mock/` by `build.py`.

- **Sections:** In short, Ask, Key numbers, Default alive, Customers, Pipeline not counted,
  Challenges, Product, Growth, Team, Next month, Sources.
- **Default alive:** the verdict, revenue against expenses, the cash curve, and a dead or
  alive map. It uses the same model as `buildDefaultAlive()` in the patch: break-even in
  November 2027 with €1.83M left, and an edge of 8.6% monthly growth.
- **Real VC name:** the source list leaves out the investor firm's name, because the meeting
  notes that mention it are invented.

**Handoff.** `HANDOFF.md` gained two sections:
- **5:** deck changes that affect the demo.
- **6:** the investor report, plus a section-by-section plan for building it into the app.
  That plan is new app work and is not in the patch.

**Still open:**
- **Evidence:** real answers from founders at the event, the biggest score gain left.
- **Team name.**
- **Backup video:** `demo-backup.mp4`.
- **Patch:** applying `reson8-switch.patch` and running `flutter test`.

## 24 Oct 2026 · PR #2 · Reson8 handoff (merged)

- **The patch:** `reson8-switch.patch` switches the app from Shelfwise to Reson8, and the
  PR changes no app code directly. The patch covers:
  - mock data and names
  - a sixth source (real PyPI and npm downloads)
  - the scripted report moved to Reson8 record IDs
  - the default alive section under the KPI table
  - test updates
- **`HANDOFF.md`:** explains how to apply it and what to check.
- **Model ID:** a wrong change to `claude-sonnet-5` was reverted. `claude-sonnet-5-5` is valid.
- **Deck, script and shot list:** updated for SDK downloads and default alive.

## 24 Oct 2026 · PR #1 · Demo kit (merged)

- **What it added:** the first version of `demo/`: the deck, the narration script in three
  cuts, the shot list for the backup recording, the Reson8 dataset, slide renders, and a
  first pitch review.
- **README visuals:** the root README got its slide images.
