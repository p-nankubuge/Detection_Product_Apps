# Caveats: what was sampled, approximated, timed out or not done (thresholds run, 25 Nov)

## Scope
- Single-key mode, as the caller asked: main key Figma Registration K2. Base period 13-20 Nov (7 days, no sampling). Replay 20 Nov (no sampling), plus the 12:00-14:00 slice.
- The top-20-keys matrix was **not done**. Only Figma has a key-level matrix.
- No truth data was used. High risk (`latest_risk_band = 'High'`) and verified are indicators only.

## Definitions settled (verified where stated)
- **Signature counted:** `DI_MATCHED_SIGNATURE_AT_SESSION_CREATED`, the matched prefix at the session's dictionary level. Recounting same-key sessions with the same matched signature reproduces DI's recorded ST count best over a 30-40 min trailing window (corr 0.94, exact on 73% at 40 min; `00_verify_counting.sql` (b)). In `vw_events`, `DI_SHORT_TERM_COUNT` = current bucket + previous bucket on 851 of 851 checked events, and the same holds for LT ((c)). So today's count is a **two-bucket count**. The bucket length is **not confirmed**; the fit suggests 20 minutes. LT fits ~12-24 h.
- **Today's thresholds on Figma:** ST 11 and LT 660 for every dict and session on 20 Nov (count / ratio). `breached` is equivalent to count > 11 on all 88,608 sessions. Dict 63 breaches are recorded (202) but exempt.
- **40-minute windows:** fixed, epoch-aligned buckets (`TIME_SLICE(session_ts, 40, 'MINUTE')`; each day starts on a bucket edge, and 12:00 and 14:00 are edges too). I chose fixed buckets because the spec defines the base as sessions per signature per 40 minutes. Buckets give one observation per signature-window, and they are cheap on 7 days. Sliding windows would need a self-join per session. **Not like-for-like:** the replay compares these 40-minute bucket p99s against DI's own two-bucket count, which spans 20-40 min if buckets are 20 min. A burst split across two fixed buckets also gives a lower bucket count than a sliding count would.
- **Clean:** a signature-window with under 20% High sessions. The same rule labels clean traffic on the replay day.
- **Minimum volume:** 500 clean signature-windows per cell, for both key and global cells. Fallback chain: key cell → global cell → global dict pooled → global Dict -1 + 1 pooled. Dict 1 Desktop just missed the minimum (413 key / 496 global). With a minimum of 400 its threshold would be 8 instead of 35.3. That changes no replay result, because Figma Dict 1 never exceeded 8 on 20 Nov.
- **LT threshold = base x LT multiplier x 60** (today's LT/ST ratio on Figma, 660/11). This is my **assumption**; the spec gives only a 40-minute base. No LT fires happened either way on Figma, but LT matters on K3 and L1.
- **Breach rule:** count > threshold (strictly greater), matching today's flag.

## Platform groups
- These use the table in `.claude/agents/similarity-scorer.md` "Seen-before rules" item 1, from `os_at_session_created` and `webgl_unmasked_renderer_at_session_created`. Basic Render Driver on Windows → Win RD/VM. Windows / OS X / Chrome OS → Desktop. iOS / iPadOS / Android → Mobile. GNU/Linux / Ubuntu → Linux. Everything else → Other, including Fedora, UOS, HyperOS, Android TV, Fire OS, HarmonyOS, OpenHarmony, Meta Horizon and NULL OS. Fedora and UOS are Linux distributions, but the table lists only "Linux (incl. Ubuntu)": 2 sessions.
- **Empty renderer** is grouped by OS, as the layer-1 scorer code does ("hardware GPU" is not checked beyond excluding software and Basic Render renderers): 2,427 base-period sessions. "Mobile with a mobile GPU" is not checked either; Android with a desktop GPU stays Mobile.
- **List A/B/C skipped:** base 8,536 of 655,839 (A 1,815 / B 387 / C 6,334); replay 1,459 of 88,608 (A 567 / B 9 / C 883). List C is my implementation of C1-C3 in spec §3 (C2: UA containing `Chrome/` and JA4 ALPN `h1`; C3: Chrome major 70+ and JA4 `t12`). It is not applied on proxy keys (L1).
- **Group mixing in counts:** below Dict 63 the matched signature doesn't contain the renderer, so one matched signature can span Desktop and Win RD/VM (for example Windows at Dict 1-31). The base counts per matched signature x group. The replay uses DI's count, which counts per matched signature across groups and includes List A/B/C sessions. How often this happens was not measured.

## Global cells
- **Sampled:** one weekday, 19 Nov, 1-in-16 **by signature**, `MOD(ABS(HASH(public_key, di_matched_signature_at_session_created)), 16) = 0`. I sampled by signature rather than by session, because sampling sessions would cut every count to ~1/16 and bias p99 down. 5.50M sessions, 342 keys. This is one day, not a rolling 7 days. Large single signatures decide the result depending on whether they land in the sample (for example a Mobile Dict 63 signature-window of 19,659 sessions). Dict -1 and Dict 1 have few signatures, so those cells are noisy.
- **Excluded:** the synthetics key `2EAD3543` and 13 keys with one JA4 on ≥ 98% of 24 h sessions (≥ 500 sessions): the 3 Payoneer keys, six keys with ~1,737 sessions each on one QUIC JA4 (identical volumes, possibly monitoring traffic; not checked), and four keys on no-ALPN JA4s. Two keys with **NULL JA4 on 100%** (8A1EAD4C 624k/day, F75933C8) were **kept**, because they have no JA4 at all rather than a proxy JA4.
- The spec §4 table's own method is unknown, so the comparison is indicative.

## Known cases
- **K3:** replay only, 18 Nov 00:00-07:00, using **global cells**. The query that built the key's own 7-day base (11-18 Nov, ~1.5M sessions per 7 h on this key) **timed out** and was not retried. Within this window, 75% of the attack sessions are Dict 31, against "~91%" in `known_cases.md`.
- **L1:** replay only, 18 Nov 10:00-14:00 (the peak), using **global cells**. The Payoneer keys' own cells were **not computed**. ST counts on EE844FC3 top out at 1,052-1,054, which may be a cap in DI (not checked).
- Neither case used a whole day.

## Not done
- No example sessions were pulled. In particular, the Dict 63 Linux cell (25 fires, 0% High) is not explained.
- No sensitivity runs: other minimum volumes, sliding windows, or replaying with my own recounts instead of DI's counts.
- I did not check whether the Dict 63 exemption works through `di_is_suspicious`; that reading comes from `spec.md` §1.
- Run timings: base 22 s, global 9 s / 7 s, replay 9.5 s / 3.9 s, K3 4.9 s, L1 5.1 s; one timeout (K3 key base).
- Queries were sent wrapped as `EXECUTE IMMEDIATE $$<SELECT>$$`, so the echoed SQL is not reformatted. Read-only throughout.
