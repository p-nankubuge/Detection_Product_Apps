# Design decisions (and the options not taken)

Choices made while building the shadow evaluator, with the alternatives considered, so they can be revisited when evidence changes. Newest first. Each entry: what was decided, the options, why, and what would make us revisit it.

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
