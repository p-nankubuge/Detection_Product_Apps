# Design decisions (and the options not taken)

Choices made while building the shadow evaluator, with the alternatives considered, so they can be revisited when evidence changes. Newest first. Each entry: what was decided, the options, why, and what would make us revisit it.

## 26 Nov 2026 (later): align with the Device Outlier Intelligence design

Context: the runs so far built a **per-account** whitelist (Figma: effectively one key), **binary** pair checks, and **one threshold per dictionary × platform cell**. The design ([Device Outlier Intelligence - Design](https://arkoselabs.atlassian.net/wiki/spaces/FP/pages/895516676)) and the user describe something different. Superseded parts: D-5/D-9 (binary / two-level pairs, as the pair *grading*), D-12 (whitelist scope, now the vertical first), D-13 (per-cell p99 level). Kept: platform groups for seen-before lookups, physical screen size, null fix, per-key thresholds (D-11), Dict 63 exemption removed.

### D-17. Whitelist pooled across the vertical, with eligibility rules

- **Status: deferred to the dictionary clean-up phase** (user, 26 Nov): this phase improves matching (similarity vs strict exact match) and thresholds on the dictionary DI uses today for each key; the clean-up agents (whitelist-builder, impossible-combos, gate-reviewer) build and clean the trusted dictionaries next.
- **Decided (for that phase):** build the whitelist from all keys in the vertical dictionary (e.g. `general_internet`), keeping only signatures that meet the design's eligibility rules (§3.2.2; approximated over the available window and stated). The account dictionary is an optional stricter layer.
- **Options considered:** per key; per account (what layer 1 did); **pooled vertical + eligibility** (chosen); all keys.
- **Why:** pooling gives more diverse device signatures, so something new on one key isn't suspicious if it's normal on others. Figma's account has one live key, so an account-only whitelist judges Figma against its own thin traffic; that is a likely reason for the never-seen and pair-check over-firing.
- **Revisit when:** vertical membership is formally defined (today inferred from `di_dictionary_used`), or a vertical mixes very different clients (e.g. custom apps).

### D-18. Field combinations graded common / rare / never

- **Decided:** for each checked pair (UA × device_params, screen × device_params, screen × WebGL, screen × platform group), measure how often it appears among devices of the same platform group in the pooled whitelist, and grade **common / rare / never**. The cut-off is **measured first** (where High risk starts to rise), then fixed in the spec.
- **Options considered:** exact / coarse yes-or-no (D-9); fixed cut-off of 0.1%; fewer than 3 accounts; **measure first** (chosen by the user).
- **Revisit when:** the measured cut-off differs a lot between platform groups or verticals.

### D-19. Threshold per matched signature: expected × multiplier

- **Decided:** fire when a matched signature's rolling 40-minute count (current + previous 20-minute bucket, DI's own count) > max(floor, expected × multiplier). Expected = the signature's normal share of the key's sessions (7 days) × the key's sessions in the same two buckets. Multiplier by dictionary, small floor; both calibrated on Figma and Blizzard.
- **Options considered:** one p99 per dictionary × platform cell (D-13 runs); the signature's own p99; the design page's defaults literally (absolute 200 / percent 0.08); **expected × multiplier** (chosen by the user).
- **Why:** the design ties the threshold to how common *that* signature normally is; one limit per cell treats a hugely common signature the same as a rare one, which is a likely reason per-cell limits over-fired on Figma's common signatures.
- **Revisit when:** calibration can't find a multiplier that passes G7 and G8 together.

## 26 Nov 2026: threshold gates

### D-15. G8 tests Blizzard registration, not Payoneer; G7 compares the same cell

- **Decided:**
  - **G8:** on Blizzard ROW Registration K2, clean-traffic firing ≤ today and more TD Nonlegit sessions caught than today. Payoneer is dropped from the threshold gates.
  - **G7:** compare each cell's clean-traffic firing with **today's firing in the same cell**, not the dictionary average.
- **Options considered:** keep Payoneer (L1) as G8; replace it with another proxy key; **replace it with a second normal registration key that has labels** (chosen).
- **Why:**
  - Payoneer is a proxy key: every user shares the proxy's JA4, so DI sees huge repeat counts (477–746) at Dict 1. No threshold level fixes that; it's a fingerprint problem for the similarity side (proxy keys get JA4 weight 0). It says nothing about whether thresholds are well set. Not comparable with Figma (user, 26 Nov).
  - Blizzard ROW Registration K2 is a normal registration key with Nonlegit labels, so it measures uplift directly.
  - G7 per dictionary average made two cells "fail" in thresholds v3 that fired no more than today in the same cell (Dict 3 Desktop 27 vs 30; Dict 15 Win RD/VM 4 vs 4).
- **Revisit when:** Payoneer-type proxy keys show up in threshold firing again after the similarity side handles them.

### D-16. No "identical managed fleet" exception for thresholds (for now)

- **Decided:** don't exempt signatures that come from few IPs / one network (the Figma Dict 63 Linux group: one signature, 4 IPs in one /24, two bursts, mostly verified).
- **Options considered:** exempt low IP-diversity signatures; exempt known institutional networks (ISP / ASN allow-list); **no exception** (chosen).
- **Why:** "many identical devices from few IPs" is also what a bot farm on one IP looks like, the classic attack velocity is meant to catch. The fleet group was mostly verified, so a challenge costs them little.
- **Revisit when:** truth data shows real fleets being labelled Legit and losing sign-ups, or an ASN allow-list is available from another team.

## 25 Nov 2026 (night): threshold level (under test)

### D-13. How to stop per-key thresholds over-firing on clean traffic (G7)

- **Status:** tested (`results/2026-11-25_thresholds-v3/variants.md`), not decided. Leading option: p99.9 + floor 5.
- **Result (Figma K2, replay 20 Nov):** clean-traffic fires p99 301 → floor 5: 203 → p99.9: 83 (today 84 effective); total fires 698 / 500 / 218; High% of fires 44 / 48 / 47; G7 failing cells 14 / 11 / 4; K3 (Adobe) firing 91% / 91% / 85% (today 77%; p99.9 loses the Dict 63 Desktop part); G8 (Payoneer) fails in every variant (counts 477–746, a similarity problem, not a threshold one). p99.9 and p99.9 + floor 5 gave identical results on Figma; the floor only protects low-volume cells.
- **Trade-offs of p99.9 + floor 5:** almost no new detection on Figma beyond enforcing Dict 63 (91 fires, 53% High, hidden by today's exemption); loses 40 fires today's flat 11 catches (not profiled); noisier day to day than p99; doesn't remove the Dict 63 Linux fleet group (counts up to 24).
- **Before deciding:** profile the 40 lost fires; test a fleet / IP-diversity exception; re-check on a second key with truth data and a full (non-sampled) Adobe base.
- **Context:** thresholds v2 (`results/2026-11-25_thresholds-v2/`): Figma's own base p99 is 2–9 sessions per signature per 40 min, so thresholds after multipliers are 3–10 vs today's flat 11. Fires on clean traffic rise from 118 to 301 on 20 Nov; G7 fails in 15 cells.
- **Options being tested:**
  1. p99 as now (baseline).
  2. **Floor:** base never below 5 (before multipliers).
  3. **p99.9** instead of p99.
  4. **p99.9 + floor 5.**
- **Not tested yet:** floor at today's threshold (would remove any tightening); a larger minimum volume per cell; a per-signature IP-diversity exception for identical managed fleets (Dict 63 Linux case).
- **Judge by:** G7 (clean-traffic fires vs today), High risk among fires, K3 (Adobe) still firing, G8 (Payoneer), the Dict 63 Linux group.

## 25 Nov 2026 (evening): scope of thresholds and whitelists

Context: the thresholds run (`results/2026-11-25_thresholds/`) fell back to all-keys cells for 15 of 35 Figma cells, which made Dict 1 looser than today (35 vs 11). Clarified: thresholds are per key; the dictionary whitelist is shared across a group of keys (a vertical or an account) so known devices are learned faster.

### D-11. Threshold fallback stays within the key

- **Decided:** key × dict × platform group → key × dict across all platform groups → the key's current threshold. A fallback value never exceeds the key's current threshold. All-keys cells are a cross-check only.
- **Options considered:**
  1. Fall back to the all-keys cell (old spec wording): not per key, and loosened Dict 1.
  2. Key's current threshold for every thin cell: simplest, but throws away the key's own data where a pooled cell is big enough.
  3. Pool within the key, uncapped: per key, but a pooled cell could still exceed today.
  4. **Pool within the key, fallbacks capped at the key's current threshold** (chosen).
- **Why:** keeps every threshold per key, and no thin cell gets looser than today. Real (non-fallback) key cells may still exceed today's threshold where the key's own clean traffic supports it.
- **Revisit when:** a key has so little volume that most cells end at the current threshold (the design then adds nothing for that key), or a key's pooled cell is clearly too tight for one platform group.

### D-12. Whitelist scope = the keys that feed the key's DI dictionary

- **Decided:** find the dictionary a key is matched against (`di_dictionary_used`). Account dictionary (value = account ID) → whitelist from **all keys on the account** (`account_id`). Vertical dictionary (value = a name, e.g. `general_internet`) → all keys in the vertical; proxy = keys whose `di_dictionary_used` is that name, until vertical membership exists.
- **Options considered:** per key (layer 1 so far); keys sharing `di_dictionary_used` (first version of this decision: confuses what a key is *matched against* with what *feeds* the dictionary); all keys; **the dictionary's learning scope** (chosen).
- **Why:** an account dictionary learns from all the account's keys and a vertical groups more keys, so known devices are learned faster; the whitelist should match that. Figma has 2 production keys, Login and Registration. On 19 Nov the account (`23454`) showed Registration Production K2 (on the account dictionary) and two development keys matched against `general_internet` (Login Development 1, Registration Development K2; 315 sessions); the Login Production key (`955D26AF-…`) was live 1 Oct → 1 Nov 10:13 UTC (up to 1.39M sessions/week, more than Registration) and has had ~10 sessions since. So for November windows the account dictionary is effectively Registration only, and the layer-1 and thresholds runs (13–20 Nov) used the right scope. **Any October run must include Login.**
- **Open:** (1) why Figma Login Production stopped on 1 Nov (integration change, removal or outage; if it returns, Figma's account whitelist roughly triples); (2) whether development keys, which are matched against a vertical, also feed the account dictionary. Assumed: production keys feed it; development keys likely shouldn't.
- **Revisit when:** vertical membership is defined, or a dictionary mixes very different traffic (e.g. web and mobile-SDK keys in one account).

## 25 Nov 2026 (later): changes after layer 1 v2

Context: layer 1 v2 (`results/2026-11-25_layer-1-v2/`) halved Band D, but desktop checks still didn't separate risk (G3 1.05x), most remaining desktop Band D came from screen pairs on resized windows, and the v1 Dict 15 group (UA × DP + screen × DP failures, 16 of 51 High risk) left Band D under coarse pairs. Not yet re-run.

### D-8. Screen = physical size only

- **Decided:** compare screens on the physical size (`w,h`, the part after `::`) everywhere: scoring, never-seen values and pair checks. The available size (`avail_w,avail_h`) is ignored.
- **Options considered:** physical size in the checks only, keeping the full string in scoring; **physical size everywhere** (chosen).
- **Why:** the available size changes when a user resizes the browser window or the taskbar moves, so it describes the window, not the device. Using it anywhere makes ordinary resizes look like new screens.
- **Revisit when:** a re-run shows bots varying the available size while copying a common physical size (the available size could then be a signal worth a separate check).

### D-9. Two-level pair checks (supersedes D-5)

- **Decided:** coarse pair never seen together = failed check; coarse pair seen but exact pair never seen = one warning sign. Warning signs count toward the desktop Band D trigger (1 failed check + 1 warning sign = D); on mobile they are reported only.
- **Options considered:**
  1. Exact pairs as failed checks (v1): over-fired on low-risk sessions.
  2. Coarse pairs only (v2): lost the Dict 15 signal.
  3. **Two-level, exact-only mismatch = warning sign** (chosen).
  4. Two-level, and 2+ exact-only mismatches alone = Band D: likely to bring back v1's over-firing.
- **Why:** keeps exact-pair information without letting it demote on its own. Under this rule the Dict 15 group (no coarse failures in v2) still won't reach Band D on desktop unless it also has a failed check; the next run reports High risk by number of warning signs to show whether option 4 is needed.
- **Revisit when:** sessions with 2+ warning signs and no failed check have clearly higher High risk (or TD Nonlegit) than sessions with 0–1.

### D-10. Empty or unparsed values never match

- **Decided:** a field that can't be parsed gets no credit, full or partial, against any whitelist value.
- **Why:** Snowflake `HASH(NULL) = HASH(NULL)` gave 39 sessions ½ UA credit in both layer 1 runs.

## 25 Nov 2026: similarity-scorer "Seen-before rules"

Context: layer 1 on Figma K2 (`results/2026-11-25_layer-1/notes.md`) showed demotions driven by exact-value checks on mostly low-risk sessions, and "seen before" checked per exact OS family.

### D-1. Does an older, unseen OS version count toward Band D?

- **Decided:** no. It is reported as a warning in the output, but it doesn't count toward the Band D trigger and is not a failed check.
- **Options considered:**
  1. Failed check (the earlier standalone wording).
  2. Warning sign that counts toward Band D, like a never-seen desktop screen or device_params (so 1 failed check + old OS version = D).
  3. **Reported only, doesn't count toward Band D** (chosen).
- **Why:** OS version is the least reliable field: frozen for ~100% of Windows, ~92% of Android and ~75% of macOS sessions on Figma through 24 Nov, with a fix rolling out unevenly. iOS showed 73 versions in one week, so older versions are common on real phones. Layer 1's main problem was over-firing demotions; another weak trigger would add to it.
- **Revisit when:** truth data (or known cases) shows old-unseen-version sessions are clearly riskier than others in the same band, or the frozen-version fix is fully rolled out.

### D-2. How to handle frozen OS versions

- **Decided:** decide from the data in each run. If one version covers ≥ 90% of an OS line's whitelist sessions, treat that line as frozen and skip the check (also skip sessions reporting the frozen value).
- **Options considered:** hard-code which OS families are frozen; drop the OS version check entirely; **data-driven threshold** (chosen).
- **Why:** the freeze is being fixed for part of the population (expected some time in November), so a hard-coded list would go stale. On Figma, `os_version_at_session_created`, `LATEST_OS_VERSION` and the DI signature showed no change through 24 Nov; `LATEST_SEC_CH_UA` carries browser version only.
- **Revisit when:** the field carrying the fixed version is identified (the 90% threshold may need tuning), or a run shows a family flipping between frozen and not.

### D-3. OS lines for version comparison

- **Decided:** iOS and iPadOS compared together; Android, Windows, macOS, ChromeOS, Linux each on their own.
- **Why:** iOS and iPadOS share version numbers (26.6.1, 27.0.1, 27.2 lead both); versions aren't comparable across other OSes.

### D-4. Closest-device search anchor

- **Decided:** stays per exact OS family. Only the "seen before" lookups move to platform groups.
- **Options considered:** anchor on platform group too.
- **Why:** the request was about "seen before"; the scoring weights are per OS, and comparing a Windows session's fields with a Mac's for similarity would mix weights.
- **Revisit when:** sessions are seen failing to find any close device only because their OS family is rare on the key (e.g. iPadOS, Ubuntu).

### D-5. Coarse values for pair checks (superseded by D-9)

- **Decided:** pair checks ("never seen together") use UA = browser family + major version, and device_params = platform, CPU cores, colour depth, touch (font hash and storage/cookie flags dropped). Screen and WebGL renderer unchanged. Single-value never-seen checks stay exact.
- **Options considered:** keep exact pairs; coarse values everywhere; **coarse for pairs only** (chosen).
- **Why:** exact device_params and UA rarely repeat within 7 days even on real devices (layer 1: e.g. 31→D screen pairs, 49 sessions, 0 High risk). Keeping single-value checks exact is safe because they are now warning signs, not failed checks.
- **Revisit when:** a re-run shows pair checks no longer separate risk (they fire too rarely), or a known bad case passes because of the coarser match.

### D-6. device_params never seen

- **Decided:** desktop (Desktop, Linux, Windows RD/VM, Other) = one warning sign; mobile = failed check (unchanged).
- **Why:** on desktop it was the largest single cause of demotion (294 of 587 in 7→D) and, counting as both a failed check and the never-seen extra, forced Band D alone. Mobile was not asked about and mobile device_params are more uniform.
- **Revisit when:** mobile demotions from new device_params turn out to be mostly low-risk.

### D-7. Software renderers in standalone mode

- **Decided:** sessions with SwiftShader, llvmpipe, VirtualBox or VMware renderers go to platform group **Other** in standalone mode (where List A/B/C aren't applied). Other uses the desktop Band D rule.
- **Why:** spec §4 says List A/B/C sessions need no group because they're excluded; standalone doesn't exclude them, so they need somewhere to go.
