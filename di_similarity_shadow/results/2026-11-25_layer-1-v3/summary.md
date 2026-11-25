# Layer 1 v3 (Seen-before rules, items 5, 6, 9): summary

- **Scope:** identical to v2: Figma Registration K2, sessions created 2026-11-20 12:00-14:00 UTC, all 9,156 sessions, standalone,
  no truth data. Whitelist (D-12): uncleaned Dict 63, 13-20 Nov, Figma account production keys: Registration K2 364,042 sessions /
  65,959 signatures; Login Production 1 session / 1 signature. Development keys excluded.
- **Sanity test: pass.** All 14 `spec.md` examples and both v2 extra rows reproduce unchanged; 6 new rows (resized window, two-level
  pairs, unparsed UAs, empty screen) move exactly at the intended step (`sanity_test_v3_result.md`). Recomputed v2 matches published v2
  cell by cell.
- **Result:** Band A 73.2%, B 18.4%, C 3.3%, D 5.1% (v2 69.4 / 20.7 / 4.6 / 5.3). Same bucket / up / down **64.6 / 27.7 / 7.7**
  (v1 63.9 / 22.1 / 14.0; v2 65.6 / 25.6 / 8.8). Promoted 333, demoted 176.
- **Flow v2 -> v3:** 716 sessions changed band (20 High, 2.8%). Physical screen in scoring 392 (387 up; 10 High); physical screen in
  checks 198 (151 out of D, 47 into D; 7 High); two-level pairs 88 into D (3 High); null fix 34 one band down (0 High); 4 at two steps.
- **Main findings:** (1) Physical-size screens remove most window-resize noise: 984 scores rise or fall, 151 sessions leave Band D.
  (2) Desktop checks now point the wrong way (G3 0.70x): Band D by trigger is mostly screen x WebGL and Low risk. (3) Highest-risk desktop
  pockets are outside D: coarse UA x DP failure alone (163 sessions, 23% High) and two exact-only pair warnings with no failed check
  (64, 27% High; it holds all 16 High of the v1 Dict 15 group). That meets the D-9 revisit condition. (4) Mobile G3 3.4x on 95 sessions.
- Details: `compare_v2_v3.md`, `disagreement.md`, `crosstab.md`, `gates.md`, `caveats.md`.

## Proposed spec rows ("Confirmed field names"; not edited, per instructions)

| Concept | Column | Confirmed by / date |
|---|---|---|
| Screen, physical size | 2nd `::` part of the 3rd `\|\|` field of `DI_HIGHEST_SIGNATURE_AT_SESSION_CREATED` (`w,h`, e.g. `1920,1080`); the 1st part is the available size and changes with window resizing; an empty screen appears as `::` (31 of 364,042 Figma K2 Dict 63 sessions, 13-20 Nov) | similarity-scorer layer 1 v3, 2026-11-25 |
| Whitelist scope, Figma account (`23454`), 13-20 Nov | Dict 63 sessions: Registration Production K2 364,042; Login Production 1 (`955D26AF-...`): 1 | similarity-scorer layer 1 v3, 2026-11-25 |
