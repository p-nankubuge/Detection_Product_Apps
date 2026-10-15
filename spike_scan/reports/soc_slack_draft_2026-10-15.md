Hi team :wave: — from the daily spike scan, we have 5 signal combinations that keep coming back on the same accounts. I backfilled to *Sep 20* and checked each key day by day: the same keys get hit again every *3–12 days* (AT&T is Sunday to Sunday, 3 weeks apart). Could you please review and *create these as custom telltales*, so we're covered when the next wave lands? Drafts are already validated and the full defs are in the attached action pack.

_"Bursts" = separate attack episodes since Sep 20 (a day ≥1k sessions and ≥3× that key's normal day; back-to-back days = one episode). Peak = biggest single day._

*1. `g-pagebio-null-cdn-ends-content-length-tz-mismatch-no-vpn-rfc-ct-before-cl` — already LIVE, FYI*
`ct-before-cl` + `pagebio-null` + `ends-with-content-length` + `tz-mismatch-no-vpn`
8 of 9 keys recurring · 28 bursts
• Adobe ARP FF (Key 8): 3 bursts (Sep 30, Oct 4, Oct 9 → *still ongoing*), peak 725k/day, ~50% verified :warning:
• Airbnb Account Lookup (Key 6): 3 bursts (Oct 7, Oct 10, Oct 14), peak 565k
• AT&T Consumer Login (Key 3): 3 bursts (Sep 20, Oct 9, Oct 11), peak 414k
• + WBD Account Lookup, WBD Login, Adobe Sign Up, Olo Payments (6 bursts), Amazon Client: smaller (5–11k peaks)
→ Ask: Adobe ARP is still getting ~half through. Can we review the action on that key?

*2. `g-cdn-ends-cl-rfc-ct-before-cl-tz-mismatch-grease` — CREATE*
`ct-before-cl` + `ends-with-content-length` + `country-timezone-mismatch` + `client-hints-not-a-brand-grease`
8 of 10 keys recurring · 23 bursts
• Adobe ARP FF (Key 8): 3 bursts (Sep 23, Oct 4, Oct 10 → *ongoing*), peak 737k. It caught Sep 23 before the live TT did.
• Airbnb Account Lookup (Key 6): 2 bursts (Oct 8, Oct 14), peak 599k
• AT&T Consumer Login (Key 3): 3 bursts (Sep 20, Oct 9, Oct 11), peak 427k
• gtop100.com: 2 bursts (Oct 11, Oct 13 → *ongoing*), peak 32k, ~76% verified
• + Amazon IDS, WBD Login (4 bursts), Olo Payments, Tinder PreSMS: smaller

*3. `g-rfc-ct-before-cl-device-param-spoofing-di-dict3-st-1x` — CREATE (most regular cycle)*
`ct-before-cl` + `device-parameter-spoofing` + `di-dict-3-match-short-term-1x`
7 of 11 keys recurring · 19 bursts
• Roblox Login (Key 1): 3 bursts (Sep 20, Oct 2, Oct 8), each 100–130k/day, ~0% verified. Every 6–12 days, so expect the next one soon.
• Roblox Signup (Key 2): 2 bursts (Oct 2, Oct 14), peak 137k
• Airbnb Account Lookup (Key 6): 2 bursts (Oct 8, Oct 10), peak 599k
• Adobe ARP FF (Key 8): 2 bursts (Oct 4, Oct 10), peak 141k
• + Microsoft Account Signup (25k), Roblox Game Join, Chime Registration: smaller

*4. `g-bio-mouse-single-click-device-param-spoofing` — CREATE (live burst right now)* :rotating_light:
`mouse-moves-but-only-a-single-click` + `device-parameter-spoofing` (CHECK_ANSWER)
5 of 7 keys recurring · 18 bursts
• Roblox Signup (Key 2): 3 bursts (Oct 2, Oct 10, Oct 13) + *today 129k so far, 0% verified*
• Roblox Game Join (Key 6): 4 bursts (Sep 26, Sep 29, Oct 11, Oct 14), peak 53k
• gtop100.com: 2 bursts (Oct 11, Oct 13 → *ongoing*), peak 23k
• Adobe Sign Up (Key 2): 4 bursts · Meta Login (Key 2): 3 bursts: smaller (5–8k)
• Uber SMS (Key 1): elevated since Oct 8, peak 80k, 22% verified

*5. `g-rta-isp-velocity-lt-pagebio-null` — CREATE, scoped to 2 keys*
`rta-isp-velocity-long-term-abuse` + `page-level-biometrics-empty-or-null`
3 of 10 keys recurring · 16 bursts
• Adobe Sign Up (Key 2): 3 bursts (Sep 25, Oct 7, Oct 11), peak 127k, 0% verified
• Roblox Game Join (Key 6): 4 bursts (Sep 21, Sep 27, Oct 4, Oct 11), peak 38k
• Meta Login (Key 2): 2 bursts (Sep 27, Oct 11), peak 11k
• On Oct 11 it hit 10 keys on the same day, which looks RTA-wide. So I'd scope it to Adobe Sign Up + Roblox Game Join rather than go global.

*On hold, not asking to create yet:* `g-cdn-ends-te-device-param-spoofing`. Mostly one-off bursts (only Roblox Signup repeats, at 1–8k). I'll keep tracking it.

The attached action pack has, per signal, the TT definition JSON, the day-by-day recurrence table, and created vs verified charts per key (D-4 → now). Happy to walk through any of it. Thanks! :pray:
