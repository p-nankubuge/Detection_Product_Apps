Hi all, quick follow-up to Will's update, with a status check as of 7 Oct ~05:30 UTC.

**Status: the underlying issue is still present, but there have been no new false positives since 3 Oct.**

* `os_version` for the iOS app is still the app build (e.g. `12.40.10312`), so the user-agent parsing fix isn't live yet.
* iOS 12.40 behaved as Will described: 100% dict -1 on 1–2 Oct, 1,497 sessions tagged by the dict -1 telltale and returned with `risk_band = High` on 3 Oct, then normal matching from 4 Oct. It's been 0% dict -1 since 5 Oct.
* No iOS app session on the key has had a dict -1 telltale from 4 Oct to today.
* iOS 12.41 (`12.41.10404`) has only 1 session so far (6 Oct, dict -1), so its rollout hasn't started yet. Unless the parsing fix or the guarded telltale lands first, we expect the same pattern when it ramps up.

**This is specific to Compare the Market's iOS user agent**

I checked every key over the last 24 hours, comparing the parsed `os_version` with the real iOS version in the user agent. The only real mismatches are CTM's `mobile.meerkat.ios/…` app:

| Key | iOS app sessions (24h) | Wrong `os_version` |
| --- | --- | --- |
| CTMUK - Prod - Start Quote - Key 1 (`F8A9F272-CC12-410D-8030-4172C0935409`) | 14,220 | 14,215 |
| CTMUK - Prod - Start Quote - WhiteLabel - Key 2 (`7BD3F690-B6A5-46AE-93D8-55E04EEA2C64`) | 446 | 445 |

Example: `mobile.meerkat.ios/12.39.10300 (release) CFNetwork/1.0 iOS/17.7.11` is read as `12.39.10300` instead of `17.7.11`.

Other apps with "iOS" in their name (e.g. `ServeAppServeiOS/…`, `RabbitiOS/…`) parse correctly. They either use a standard WebView user agent with the app name at the end, or don't start with `<name>.ios/<build>`. CTM's format is the only one we see that has all three of these:

1. it starts with an app name ending in `.ios`, followed directly by `/<build>`;
2. it has no standard Safari/WebView part (`iPhone OS 18_7 like Mac OS X`);
3. the real iOS version only appears at the very end, as `iOS/x.y.z`.

**Two additions to the plan**

1. **The WhiteLabel key (`7BD3F690…`) has the same misparse.** Its volume is small (~450 sessions/day), so it's unlikely to reach the dict -1 threshold, but the DETCORE-4379 fix and the proposed guarded telltale should cover both CTM keys.
2. **This supports the CX ask.** If CTM's iOS app switches to the same user agent style as their Android app (a standard WebView user agent with the app name at the end), the problem goes away on their side, as it did for Android from 12.38.

Queries used, for re-checking when 12.41 ramps up:

* `queries/esm6772_ctm_ios_dict_neg1_monitor.sql`: per-day, per-app-version dict -1 %, empty `di_matched_signature`, dict -1 telltale hits, `risk_band = High`, and the peak short-term threshold ratio for the CTM key.
* `queries/esm6772_ios_os_version_misparse_all_keys.sql`: the cross-key check above.

(Both are in the Detection_Product_Apps repo, branch `claude/happy-clarke-6oe5j4`.)
