# Replay suspicion flags review (DETCORE-4468), 14–29 Oct 2026

Overdue "Mon 19 Oct review" for the Confluence proposal *Post-Solve Deny on In-Game Mouse Replay Signals*.
Source: ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY, `ARRAY_CONTAINS(name, SUSPICION_FLAGS)` (these flags are not in
TELLTALE_LIST_AT_GAME_VERIFY). Production keys, QA synthetic key 2EAD3543-36DC-4A77-90E1-F3AE6B16CF16 excluded
(~132.8k hits/day on all three flags, 0 solved).

| Flag | Hits | Solved | Verified | NO-THREAT | Per hour (expected) | Verdict |
|---|---|---|---|---|---|---|
| f4 `g-biometric-mouse-4axis-replay-above-10-events-4plus` (14665638) | 24,513 | 100% | 98.7% | 0 | 65 (44); 19 w/o gtop100 (5); median w/o gtop100 4–18 | Ready for deny; confirm gtop100 (17.3k) and Amazon Client Key 1 (5.2k) first |
| f3 `g-biometric-mouse-3axis-replay-above-20-events-10plus` (14665696) | 172,433 | ~100% | 88.7% | 200 (199 Tinder PreSMS) | 457 (230); 277 w/o gtop100 (107) | Tweak: Tinder PreSMS NO-THREAT; Adobe Sign Up surge from 24 Oct; Amazon IDS 14.9k at ~100% verified |
| fe `g-biometric-mouse-exact-replay-events-4plus` (14665714) | 164,146 | 68.5% | 34.4% | 58 (all after 19 Oct) | 435 (65) | Moved to check_answer on 19 Oct 00:57 UTC on purpose (no double counting; check_answer allows adaptive reset as well as deny). Judge it on check_answer from 19 Oct: 513/h, 58 NO-THREAT of 135k (0.04%: gtop100 16, Roblox Other 15, Meta Login 9). Fine for adaptive reset; review the 58 before using it for deny. Amazon IDS did not grow (~50/day -> ~42/day) |

Overlap: 99.9% of f4 sessions also carry fe; 25.9% carry f3.

## NO-THREAT hits investigated (30 Oct)

NO-THREAT here = no risk-setting telltale fired (risk score 0, LATEST_TELLTALE_USER null at every event). It is not a reliable FP proxy.

**f3 on Tinder PreSMS – Key 3 (199): missed bot.** 21–22 Oct: Cambodia, one UA (Chrome 152 Win), all 71 on 21 Oct replay the same two 3-axis tracks as 175 BOT-STD/CUSTOM sessions; share IPs (16), device ids (32), fingerprints (50), JA4 (71). 29 Oct: 92/94 replay tracks used by bot-classified sessions, same JA4, randomised device/fingerprint. All solved+verified on the easiest challenge (sec level 10). Challenge came from `user_credits` (IP/fingerprint credits exhausted), which sets no telltale. Missed because they send a valid dx blob and lack g-device-parameter-spoofing / tinder3-alerter. Also carry g-biometric-no-mouse-movement, has-fast-click, bba-signature-for-sony-attack-211223, fraud-farm-country.
Suggested: f3 as a risk-setting telltale on this key (punish at verify); early proxy: fraud-farm country + no-mouse-movement + fast click.

**fe (58): 51 real users from a flag artifact, 7 bots.** 51 match only themselves (same track submitted twice in one session, exact_match_cnt = 2, long varied tracks, 50 distinct IPs). 7 real cross-session replays: AT&T SDK Android (track shared with 1,535 bot sessions), Outlook (2 pairs), Blizzard ROW Login (HK IP, Battle.net launcher, ~30 check_answers, 0 verified). Challenge source: always-challenge keys (37: gtop100, Roblox Other, Amazon IDS, Outlook) or `user_credits` (19).
Suggested: require the exact track in >= 2 distinct sessions (exclude self-match).

Better FP proxy: no cross-session track reuse, no shared IP/device/JA4 with bot-classified sessions, no lowsec error.
