# Recurrence check, Sep 20 → Oct 15 2026 (UTC)

Exact daily counts on each combo's spiking keys, backfilled 2 weeks before the scan window.
A burst day has ≥1k sessions and ≥3× the key's median day; back-to-back days count as one episode.
"Major" means the episode peaked at ≥10k/day. Full day-by-day table: `recurrence_2026-10-15.html`.

| Combo (TT) | Status | Comes back? | Evidence (major episodes) | Recommendation |
|---|---|---|---|---|
| g-pagebio-null-…-rfc-ct-before-cl | live | **Yes** | AT&T Login: Sep 20 (414k) → Oct 11–13 (132k), Sundays 21 days apart. Adobe ARP: Sep 30 (23k) → Oct 4–5 (61k) → Oct 9–now (725k peak, still 133k today, ~50% verified), every 4–5 days and escalating. Airbnb Lookup: Oct 10–12 (565k), first seen. | Keep live. Adobe ARP is ongoing and ~50% gets through. |
| g-cdn-ends-cl-rfc-ct-before-cl-tz-mismatch-grease | candidate | **Yes** | Same actor as above on AT&T (Sep 20–21 → Oct 11–13) and Adobe ARP (Sep 23 79k → Oct 4–5 → Oct 10–now). gtop100 Oct 13–14 (32k, ~76% verified, still on today). | **Create.** Broader than the live TT, and it caught Adobe ARP on Sep 23 before the live TT did. |
| g-rfc-ct-before-cl-device-param-spoofing-di-dict3-st-1x | candidate | **Yes, strongest** | Roblox Login: Sep 20–22 (129k) → Oct 2 (121k) → Oct 8–11 (103k), every 6–12 days, ~0% verified. Roblox Signup: Oct 2 (57k) → Oct 14 (137k). Adobe ARP: Oct 4–5 → Oct 10–13. | **Create.** Most regular repeat cycle of all six combos. |
| g-rta-isp-velocity-lt-pagebio-null | candidate | **Yes, on 2 keys** | Adobe Sign Up: Sep 25–28 (127k) → Oct 7 (19k) → Oct 11–12 (25k), 0% verified. Roblox Game Join: Sep 21–24 (38k). Oct 11 hit 10 keys on the same day, which looks RTA-wide. | **Create, scoped to Adobe Sign Up and Roblox Game Join** (or global with a watch for another one-day all-key event). |
| g-bio-mouse-single-click-device-param-spoofing | candidate | **Yes** | Roblox Game Join: Sep 26, Sep 29 (53k), Oct 11, Oct 14, every 3–12 days, mostly 0% verified. Roblox Signup: Oct 2 → Oct 10–11 → Oct 13–14 → **129k today so far, 0% verified**. Uber SMS has been elevated since Oct 8 (80k peak, 22% verified). | **Create.** Live burst on Roblox Signup right now. |
| g-cdn-ends-te-device-param-spoofing | candidate | **Mostly no** | Mostly one-off episodes (Oct 6–14). Uber SMS was persistent with one 98k day (Oct 11, 76% verified). Roblox Signup repeats only at 1–8k. | Hold; keep tracking. Not enough evidence it comes back. |

Weekday: AT&T is the only weekday pattern (Sunday to Sunday). Everything else repeats on intervals of
3–12 days rather than on a fixed weekday.
