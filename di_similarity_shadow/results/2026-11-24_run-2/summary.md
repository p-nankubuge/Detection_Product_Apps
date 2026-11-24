# Impossible combinations C2, C3, N9, N10, N11: Figma Registration K2, October 2026

## Scope

| Item | Value |
|---|---|
| Mode | **Single key** |
| Key | `A207F8A1-ED09-4325-ACE6-C8E26A458FBA` (Figma - Registration - Production - Key 2) |
| Rule window | Sessions created 2026-10-01 00:00 to 2026-11-01 00:00 UTC (`session_ts`), 3,076,846 sessions |
| Sampling (rule measures) | **None.** Full month |
| Source | Snowflake `ARK_PROD.STARFLEET.PROD_INT_SESSION_SUMMARY` (`*_at_session_created` = session_setup values). A month of `vw_events` was not tried because it would time out. Cross-check on 15 Oct: `vw_events` session_setup has 116,428 sessions and the summary has 116,429 (`vw_events_crosscheck.sql`) |
| Previous-period baseline | September 2026 (same key, full month, 3,166,300 sessions) |
| Proxy-key check | Not a proxy key. On 15 Oct the top JA4 was 40.9% of 116,429 sessions, with 652 distinct JA4s. List C and N8 to N11 apply |
| TD window | Same October sessions. TD ingest partitions `year=2026, month IN (10,11)` (to 24 Nov, 3.5 weeks after the window). **TD scoring is sampled: 976 labelled sessions (2.0% of the 48,096 October labels).** See "Truth data" |
| N10 baseline | Built first: `n10_browser_baseline.csv` / `.sql` (all keys, Dict 63, 15 Oct 2026, 24h) |

## Results

Key baselines for October: **all sessions** 6.91% High risk, 99.04% verified of those that reached verify, 394,651 with no verify attempt (12.8%). **Dict 63** 4.68% High risk, 99.58% verified.

TD columns: **uplift** = flagged / TD Nonlegit with `is_verified = 1`; **FP rate** = flagged / TD Legit. Both come from the 976-label sample (401 Nonlegit verified, 575 Legit). Every TD count is below 30 except N9 Legit (78) and ANY Legit (105). Read the rates as rough guides only.

| Rule | Hits (Oct) | Share of key | High risk % | Verified % (of verify attempted) | Unverified hits (no verify) | Hits at Dict 63 | TD uplift | TD FP rate | TD-sample hits: Legit / Nonlegit / unlabelled (verify attempted + none) | Known cases caught | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|
| C2 | 18,887 | 0.61% | 4.74% | 99.31% | 1,685 | 3,487 | 0.5% (2 / 401) | 3.5% (20 / 575) | 20 / 2 / 362 (335 + 27) | K1 Uber `t13d1516h1_…` 377 / 382 (99%) on 28 Oct | **Needs refinement** |
| C3 | 7,353 | 0.24% | 4.39% | 99.16% | 1,007 | 289 | 0.2% (1 / 401) | 1.2% (7 / 575) | 7 / 1 / 146 (124 + 22) | K1 Uber `t12d1209h2_…` 1,494 / 1,494 (100%) | **Needs refinement** |
| N9 | 62,128 | 2.02% | 5.12% | 99.50% | 10,314 | 15,296 | 0.5% (2 / 401) | **13.6% (78 / 575)** | 78 / 2 / 1,137 (937 + 200) | none on K1. Run-1 example `t12d520500_…` matches by construction (not measured: it is in Nov) | **Reject** |
| N10 | 28,949 | 0.94% | 8.59% | 98.57% | 5,051 | 1,168 | 1.0% (4 / 401) | 3.1% (18 / 575) | 18 / 4 / 549 (444 + 105) | K1 Uber `t12d1209h2_…` 972 / 1,494 (65%). Run-1 example `t13d3213h1_…` (32 ciphers) outside the Chrome/Edge range by construction (not measured) | **Needs refinement** |
| N11 | 7,738 | 0.25% | 4.67% | 99.21% | 1,047 | 289 | 0.2% (1 / 401) | 1.2% (7 / 575) | 7 / 1 / 154 (132 + 22) | K1 Uber `t12d1209h2_…` 1,494 / 1,494 (100%) | **Needs refinement** (adds little over C3 here) |
| ANY of the five | 96,837 | 3.15% | 5.84% | 99.25% | 14,928 | 19,489 | 1.7% (7 / 401) | **18.3% (105 / 575)** | 105 / 7 / 1,803 (1,516 + 287) | — | — |

In the TD sample, flagged labelled sessions are **15:1 Legit:Nonlegit** (105:7), against 1.4:1 for all labelled sessions (575:401). On this key the rules point at legitimate traffic more often than at fraud. Rough 95% intervals: ANY uplift 0.7–3.6%, ANY FP 15–22%, N9 FP 11–17%.

### Stability (previous period)

| Rule | Sep share | Oct share | Oct daily share, min to max |
|---|---|---|---|
| C2 | 0.39% | 0.61% | 0.12% – 0.96% |
| C3 | 0.25% | 0.24% | 0.04% – 0.34% |
| N9 | 2.32% | 2.02% | 0.29% – 2.82% |
| N10 | 0.97% | 0.94% | 0.28% – 1.14% |
| N11 | 0.26% | 0.25% | (not split by day) |

Hits are steady month to month and drop at weekends. That fits office or enterprise traffic, not attack bursts.

### What the hits are (false-positive check)

From `rules_top_signatures.sql`: top hit signatures, October.

- **C2:** `t13d6912h1_8b2139ff7677_*` (69 ciphers, HTTP/1.1, three extension hashes). About 10.6k sessions on Windows Chrome/Edge, 1–2% High risk, 95–97% verified, spread over thousands of IPs, and 25–40% at Dict 63. This is a TLS-inspecting middlebox, not a bot. Next is `t13d1612h1_1711a4c0508c_…` (1,002 sessions, 12% High risk, 14% no verify), a better target.
- **C3 / N11:** almost the same sessions. The top signatures are `t12d520600_26e41e4f9c7e_8587f467d9ea` (Edge+Chrome 1,543), `t12d1106h2_8256d93fd366_151c0a07749b` (1,277) and `t12d600600_51f219a9f90c_…` (708). All are Windows with 0.4–9% High risk and 85–95% verified, typical of corporate TLS-1.2 proxies. One macOS signature, `t12d260400_c69ecbaecc6c_…`, has 355 sessions from **8 IPs** (0.6% High risk). N11 adds only 385 sessions over C3, from Firefox, Safari and Samsung.
- **N9:** dominated by `t13d260900_6d1bcf7a4624_188c7f576dcd` (23.3k sessions, Windows Edge/Chrome, 16k IPs, 1.3% High risk, 10.1k at Dict 63) and `t13d140900_f98f5dc5c741_…` (4.0k). In `vw_events` on 15 Oct, **37% of sessions from `vpn_proxy_description = 'cloud-security'` IPs were N9 hits** (1,624 of 4,389), plus 394 C2 hits. N9 mainly catches cloud security proxies (Zscaler-type).
- **N10:** mixed. Its most suspicious signature, and the one clear lead from this run, is `t13d2416h2_d95c37398e29_806a8c22fdea` claiming Windows Chrome: 1,213 sessions, **28% High risk**, 31% no verify, 0 at Dict 63, 862 IPs. Also `t13d5212h1_b262b3658495_…` (609 sessions, 14% High risk, 31% no verify, 0 at Dict 63) and `t13d7514h2_479067518aa3_…` (695 sessions, 24% no verify). The rest is the same t12 proxies as C3, plus Brave `t13d1514h2_8daaf6152771_…` (725 sessions, a normal Chrome cipher list with 14 extensions; the Brave extension range from Dict 63 is too strict) and Safari `t13d260900_…` on macOS (also an N9 proxy).

### Verdict reasoning (one line each)

- **C2, needs refinement:** catches the K1 Uber h1 attack (99%), but on Figma it is mostly middlebox traffic: 4.7% High risk (key 6.9%), 20 Legit vs 2 Nonlegit in TD. It needs a middlebox exclusion (e.g. JA4s seen at Dict 63 on many keys, or `cloud-security` IPs) before it can be proposed. Evidence: TD sample, top signatures, K1.
- **C3, needs refinement:** catches K1 100%, but Figma hits are corporate TLS-1.2 proxies: 4.4% High risk, 7 Legit vs 1 Nonlegit. Same exclusion needed. Evidence: TD sample (small counts), top signatures, K1.
- **N9, reject:** 2% of the key, 25% of hits at Dict 63, 13.6% of Legit labels flagged vs 0.5% of Nonlegit verified, and concentrated on cloud-security proxies. Evidence: TD sample (78 Legit hits), IP intel, signatures.
- **N10, needs refinement:** the only rule whose hits are riskier than the key (8.6% vs 6.9%), driven by a few non-browser JA4s (the 28% High-risk `t13d2416h2`). The Dict 63 baseline it rests on is polluted by proxy counts: Chrome/Edge ranges include 26, 69 and 75 ciphers. TD: 18 Legit vs 4 Nonlegit. Evidence: High-risk split, signatures, TD sample.
- **N11, needs refinement:** on this key it is C3 plus 385 sessions, with the same proxy false positives. Evidence: same as C3.

No rule is ready to propose, so `validate_telltale` was not run.

## N10 browser baseline (derived first)

**Assumption: Dict 63 = real devices.** This is not proven; another agent is checking it. The baseline itself suggests Dict 63 includes corporate TLS-inspection proxies (e.g. 69 / 26 / 75-cipher JA4s on Chrome and Edge across 60–120 keys).

Build: all keys except synthetics, the three Payoneer proxy keys and any key with one JA4 on ≥ 98% of its Dict 63 sessions (≥ 200 sessions); TCP JA4s only; List A, B and C removed; Dict 63; sessions created 15 Oct 2026 00:00 to 16 Oct 00:00 UTC; no sampling. Range = values that cover 99.9% of the family's sessions, **minus values with < 50 sessions**, which are listed separately and kept out of the range.

| Family (sessions) | Cipher counts in range | Extension counts in range | In 99.9% but < 50 sessions (excluded) |
|---|---|---|---|
| Chrome (2,466,629) | 10, 12–20, 26–31, 34, 69 | 9–18 | none |
| Edge (346,860) | 8, 10, 12–16, 19, 20, 24, 26, 27, 29–31, 33, 34, 37, 40, 41, 57, 68, 69, 75, 87 | 7, 9–14, 16, 17 | none |
| Firefox (156,086) | 15–18, 26–28, 30, 31, 52 | 9–17 | none |
| Safari, incl. all iOS browsers (3,823,214) | 13, 15, 17, 18, 20, 21, 26 | 7, 13–17 | none |
| Samsung (396,865) | 15 | 16, 17 | none |
| Brave (11,727) | 15 | 10, 12, 16 | ciphers 17, 27, 16, 30; ext 14, 15, 13, 11 |
| Opera (751) | 15 | 16, 17, 18 | ciphers 13, 30, 27; ext 12, 10, 14, 13 |
| other (198,829) | not used by the rule | | |

Caveats: Chrome and Edge ranges are wide and full of gaps, so N10 cannot catch proxy-like counts on them. Brave and Opera ranges are very narrow because of the < 50 rule. Firefox 28 and 52 come from single keys (1,729 and 801 sessions from 1 key each).

## Truth data

### Label completeness, October 2026 (labelled / verified sessions on the key)

| Date (Oct) | Weekday | Verified sessions | Labelled | Legit | Nonlegit | Labelled / verified | Flag |
|---|---|---|---|---|---|---|---|
| 01 | Thu | 97,754 | 2,024 | 1,466 | 558 | 2.07% |  |
| 02 | Fri | 81,058 | 1,565 | 1,097 | 468 | 1.93% |  |
| 03 | Sat | 53,710 | 790 | 296 | 494 | 1.47% | weekend: few Legit labels |
| 04 | Sun | 52,609 | 779 | 347 | 432 | 1.48% | weekend: few Legit labels |
| 05 | Mon | 98,944 | 2,213 | 1,642 | 571 | 2.24% |  |
| 06 | Tue | 91,741 | 1,991 | 1,393 | 598 | 2.17% |  |
| 07 | Wed | 100,474 | 2,089 | 1,494 | 595 | 2.08% |  |
| 08 | Thu | 103,522 | 2,111 | 1,518 | 593 | 2.04% |  |
| 09 | Fri | 87,977 | 1,898 | 1,156 | 742 | 2.16% |  |
| 10 | Sat | 58,378 | 920 | 320 | 600 | 1.58% | weekend: few Legit labels |
| 11 | Sun | 53,952 | 743 | 300 | 443 | 1.38% | weekend: few Legit labels |
| 12 | Mon | 100,235 | 2,022 | 1,300 | 722 | 2.02% |  |
| 13 | Tue | 108,145 | 2,364 | 1,595 | 769 | 2.19% |  |
| 14 | Wed | 105,467 | 2,252 | 1,544 | 708 | 2.14% |  |
| 15 | Thu | 101,191 | 1,980 | 1,361 | 619 | 1.96% |  |
| 16 | Fri | 85,551 | 1,724 | 1,062 | 662 | 2.02% |  |
| 17 | Sat | 53,820 | 772 | 192 | 580 | 1.43% | weekend: few Legit labels |
| 18 | Sun | 53,830 | 654 | 212 | 442 | 1.21% | weekend: few Legit labels |
| 19 | Mon | 103,554 | 2,128 | 1,440 | 688 | 2.05% |  |
| 20 | Tue | 107,727 | 1,966 | 1,260 | 706 | 1.82% |  |
| 21 | Wed | 107,361 | 2,030 | 1,389 | 641 | 1.89% |  |
| 22 | Thu | 106,784 | 1,888 | 1,221 | 667 | 1.77% |  |
| 23 | Fri | 89,269 | 1,578 | 947 | 631 | 1.77% |  |
| 24 | Sat | 56,537 | 561 | 42 | 519 | 0.99% | Legit labels almost absent |
| 25 | Sun | 54,577 | 453 | 42 | 411 | 0.83% | Legit labels almost absent |
| 26 | Mon | 104,306 | 1,708 | 1,042 | 666 | 1.64% |  |
| 27 | Tue | 107,639 | 1,796 | 1,114 | 682 | 1.67% |  |
| 28 | Wed | 104,763 | 1,651 | 1,004 | 647 | 1.58% |  |
| 29 | Thu | 97,137 | 1,641 | 941 | 700 | 1.69% |  |
| 30 | Fri | 80,098 | 1,278 | 697 | 581 | 1.60% |  |
| 31 | Sat | 48,358 | 527 | 22 | 505 | 1.09% | Legit labels almost absent |

Labels cover about 2% of verified sessions on weekdays and 1–1.5% at weekends. **24, 25 and 31 Oct have almost no Legit labels** (42, 42 and 22), so they look incomplete on the Legit side. Other days look steady. Total: 48,096 labelled (29,456 Legit, 18,640 Nonlegit, of which 18,627 verified); 48,082 of 48,096 are `is_verified = 1`. No session had conflicting labels.

### How TD was scored (workaround)

- Athena `starfleet_production.prod_session_summary` has **no year/month/day partitions**. Only `session_ts` prunes. A key-filtered count(*) took ~27 s for 1 hour and **timed out for 6 hours and for 1 day**, and the full rule query timed out even for one hour (`td_scoring_athena.sql`, kept but not used). TD is not in Snowflake (checked both Snowflake connections).
- Workaround: deterministic sample of TD labels exported from Athena as 12-character session keys (`td_sample_export_athena.sql`), pasted into a Snowflake query and joined to the session summary (`td_sample_scoring_snowflake.sql`). Sample: `substr(id,2,1) = '0'` and the first of 5 ID-ordered chunks, giving 976 labels (575 Legit, 401 Nonlegit verified). The sample spans 1 to 31 Oct and has the same Legit:Nonlegit mix as the month (59:41 vs 61:39). **976 of 976 matched.** Chunks 2–5 (another 3,902 labels) were not run, to limit the manual key transfer. Running them would give about 5× the TD counts.
- Unlabelled is never counted as Legit. Unlabelled hits are reported separately (verify attempted / no verify).

## Assumptions and what was not done

- **Dict 63 = real devices** (N10 baseline): an assumption, not proven.
- **Rule definitions used**, where spec.md left room:
  - Chromium = Chrome, Edge, Opera and Brave UA families. Samsung and iOS browsers are excluded from C2 and C3 (Samsung is covered by N9–N11).
  - iOS browsers (CriOS, FxiOS, EdgiOS) count as Safari, because all iOS browsers use WebKit TLS.
  - Brave comes from `latest_browser_detection_brave`.
  - "Modern" for N11 = Chrome ≥ 70, Firefox ≥ 63, Safari `Version/` ≥ 13 or iOS ≥ 13.
  - N11 fires on any TCP max-TLS that is not `13`.
  - QUIC JA4s are excluded from C2, C3, N10 and N11. N9 can't fire on QUIC because QUIC is always h3.
- Rules were run on the session summary, not `vw_events` (they hold the same values; checked for one day). `vpn_proxy_description` exists only in `vw_events`, so the IP-intel breakdown covers one day (15 Oct) with a simpler rule approximation (`vw_events_crosscheck.sql`).
- TD scoring is a **2% sample** (above). Most TD counts are < 30.
- Known cases: K1 Uber was replayed for **one day** (28 Oct) only. K5 gtop100 (14–18 Nov) and the Figma run-1 examples (20 Nov) fall outside the October window and were not replayed.
- Single-key per-dict baseline: only Dict 63 and all-sessions were compared. Dict 1/3 baselines per rule were not computed separately (hits at Dict ≤ 3 are counted in `rules_all_summary.sql`).
- No telltale was proposed and `validate_telltale` was not run. Nothing was written to Dataswan.
- spec.md "Confirmed field names" was updated with the session-summary fields used here.

## Files

- `rule_C2.sql`, `rule_C3.sql`, `rule_N9.sql`, `rule_N10.sql`, `rule_N11.sql`: one per rule (Snowflake)
- `_flags_cte.sql`: shared rule logic. `rules_all_summary.sql`, `rules_top_signatures.sql`, `rules_sep_vs_oct.sql`: the queries behind the tables above
- `n10_browser_baseline.sql`, `n10_browser_baseline.csv`
- `proxy_key_check.sql`, `vw_events_crosscheck.sql`, `known_case_K1_uber.sql`
- `td_label_completeness_athena.sql`, `td_sample_export_athena.sql` (Athena), `td_sample_scoring_snowflake.sql` (Snowflake), `td_scoring_athena.sql` (Athena, timed out, not used)
