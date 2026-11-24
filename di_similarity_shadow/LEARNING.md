# Learning plan: building the DI comparison prototype

Goal: by the end, have a working prototype that compares today's DI with the new scoring (similarity + impossible combinations + per-dictionary thresholds), and understand **what** each step does, **why**, and **when to use one agent vs several**.

Each run is one sitting. Keep notes at the end of each run in `results/<date>_run-N/notes.md`: what you asked, what happened, what you'd change.

| Run | What you do | What you learn |
|---|---|---|
| 1 | One question, no agents: look at Figma's traffic by DI dictionary, OS, JA4 | How Claude queries data; what "normal" looks like on a key; why you need a baseline before judging anything |
| 2 | First agent: `impossible-combos` tests the JA4 part-a observations from run 1 (C2, C3, N9, N10) on Figma, scored with truth data | What an agent is; turning a hunch into a rule; uplift vs false positives |
| 3 | `whitelist-builder` then `similarity-scorer` → the comparison table; look inside the disagreement cells, tiebreak with truth data | Agents in sequence; comparing doesn't tell you who's right |
| 4 | Improve the agents from what went wrong; re-run | Coaching an agent file is the main skill; how to measure whether a change helped |
| 5 | Run the team together ("use a workflow") on a second key and a second day; measure drift | When several agents pay off; how to measure drift; turning the run into a repeatable prototype |

## One agent or several?

| Use… | When | Example here |
|---|---|---|
| **No agent** (just ask) | A question you can answer in a few queries and want to see as it happens | "How does Figma's traffic split by dictionary?" |
| **One agent** | A focused, repeatable job with its own instructions, where you only need the conclusion back | "Test these impossible-combination rules on this key" |
| **Several agents in sequence** | Step B needs step A's output | `whitelist-builder` → `similarity-scorer` |
| **Several agents in parallel** | Independent jobs on the same data, to save time | `similarity-scorer`, `impossible-combos`, `velocity-thresholds` at once |
| **A reviewer agent** | You want an independent check that isn't anchored on the first answer | `gate-reviewer` |

Signs you need more than one: the instructions for one agent are getting long and cover unrelated jobs; one job's output feeds another; jobs could run at the same time; you want a second opinion.

## Measuring drift (run 5)

"Drift" here means the same real device showing a different value for a field over time (e.g. JA4 changing between QUIC and TCP, a browser update changing the UA).

- **Field drift:** for devices seen more than once (by `stateful_device_id`, offline only), the share whose field value changed within a day. The one-pager measured: full signature unchanged 78.2%; of devices that changed, 86% changed exactly one field, mostly JA4 (66%).
- **Scoring drift:** run the same comparison on two different days. Do the cell sizes stay stable? A cell that swings a lot needs explaining (release day, attack, proxy change).
- **Recovery after a known change:** e.g. Payoneer's JA4 change on 17–18 Nov. Today's DI dropped them to dict 1; the new scoring should keep them in Band A/B.
