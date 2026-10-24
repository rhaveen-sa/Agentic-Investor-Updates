# Demo kit

Everything needed to present Investor Update Agent: the deck, what to say, how to record
the backup video, and the Reson8 dataset the demo runs on.

<p align="center"><img src="img/slide-close.png" width="720" alt="Closing slide: the claim 'All 14 clinics in Q1' marked Unconfirmed because it was only said in a meeting"></p>

## What's in here

| File | Use it for |
| --- | --- |
| [`deck.html`](deck.html) | The slides. Open in Chrome, press `F` for fullscreen. Self-contained, so it needs no network, fonts or build step. |
| [`script.md`](script.md) | Word-for-word narration in three cuts (3, 5½ and 8 minutes), the demo click-path, what to say if the demo stalls, Q&A answers, rehearsal checks. |
| [`shotlist.md`](shotlist.md) | Shot-by-shot plan for the backup recording, done as one continuous take. |
| [`HANDOFF.md`](HANDOFF.md) | How to switch the app to Reson8, and what to check before presenting. For whoever drives the app. |
| [`reson8-switch.patch`](reson8-switch.patch) | The code and data changes behind `HANDOFF.md`, as one patch to review and `git apply`. |
| [`reson8-mock/`](reson8-mock/) | The Reson8 dataset on its own, including real PyPI and npm download counts. |
| [`investor-report/`](investor-report/) | A full October investor update for Reson8, as PDF and HTML, with the default alive map, new customers and challenges. Generated from `reson8-mock/`. |
| [`pitch-review.md`](pitch-review.md) | The pitch scored by independent judges against 15 Ogilvy principles over three rounds of edits, plus a written version for submission forms. |
| [`img/`](img/) | Slide renders used in the READMEs. |

## Deck keys

| Key | Does |
| --- | --- |
| `→` `←` or click | Next and previous slide |
| `F` | Fullscreen |
| `S` | Speaker notes, with the target time for each slide |
| `O` | Show or hide the four optional slides (ledger, October report, what is real, the business) |
| `#5` in the URL | Jump straight to slide 5, handy in Q&A |

The deck opens with the optional slides hidden.

## Before you present

Do these in order. The first four take five minutes. The rest depend on the app.

- [ ] Find out the slot length and pick a cut in `script.md`.
- [ ] Decide what to call the team. Say it on slide 1 (the script marks the spot), and
      consider adding it to the title slide.
- [ ] Ask a few founders at the event when they last wrote an investor update and how long
      it took. Say the best answer on slide 2 in place of the Visible line. This is the
      biggest score gain left (see `pitch-review.md`).
- [ ] Run the rehearsal checks at the end of `script.md` on someone who hasn't seen it.
- [ ] Apply `reson8-switch.patch` as described in `HANDOFF.md`, and tick its checklist.
- [ ] Do a live run and confirm the model row reads `claude-sonnet-5-5`, not `scripted` or
      `fallback`.
- [ ] Record `demo-backup.mp4` following `shotlist.md` and save it next to `deck.html`.
      Slide 6 plays it. Without the file, the deck drops that slide and the slides after it
      move up by one.
- [ ] Turn on Do Not Disturb on the presenting laptop.

## Run order on the day

```mermaid
flowchart LR
    A[Slides 1-4<br/>problem and product] --> B{Live demo}
    B -->|works| D[Slide 7<br/>architecture]
    B -->|"stalls 4+ seconds"| C[Slide 6<br/>backup video]
    C --> D
    D --> E[Slide 8<br/>partners] --> F[Slide 9<br/>close and repo link]
    F -.->|Q&A| G[Optional slides<br/>press O]
```

If the demo stalls, say "I'll show you the recording, it's the same run", press `→`, and
keep narrating the same beats over the video. Don't debug on stage.

## The demo company

The app ships with Shelfwise, a fictional grocery SaaS. For the pitch we run the same
October story on [Reson8](https://www.reson8.dev/), the speech-to-text partner, because
their own numbers make a better demo than an invented company. `HANDOFF.md` and
`reson8-switch.patch` make the switch. The patch also adds two things to the report:
SDK downloads as a sixth source, and a default-alive check under the KPI table.

Reson8's funding, founders, languages, API surface, certifications and pricing are public,
and so are the PyPI and npm download counts. Every revenue, burn, cash, runway and
customer figure is invented for the demo, along with all customer names and the Head of
Growth, Mirte. The title slide says so.

| | September | October |
| --- | --- | --- |
| ARR | €352k | €413k (+17.3%) |
| Paying teams | 41 | 44 |
| NRR | 104% | 112% |
| Net burn | €198k | €231k |
| Runway | 21 months | 17 months |
| SDK downloads (PyPI + npm, real) | 21,568 | 30,735 (1 to 23 Oct) |

Weekly demo bookings run 29, 41, 11, 34. The week 3 drop is 73%, the same as the Shelfwise
data, so the anomaly detector fires without retuning.

Default alive at October's growth (17.3% a month): break-even in 13 months with €1.83M
left. Below about 8.6% monthly growth the answer flips to default dead.

## Slides

| | |
| --- | --- |
| ![Title](img/slide-title.png) | ![Problem](img/slide-problem.png) |
| ![Insight](img/slide-insight.png) | ![Product](img/slide-product.png) |
| ![Architecture](img/slide-architecture.png) | ![Partners](img/slide-partners.png) |
| ![Optional: the ledger](img/slide-ledger.png) | ![Optional: October report](img/slide-october.png) |
