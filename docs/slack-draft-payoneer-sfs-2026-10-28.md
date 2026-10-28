@Gonzalo Fuente @Veronika Petrenko follow-up on the two `dp-invalid-resolution-spoofing-browser-values` flags from last week. I went back over CLM, Login and Registration for the last 45 days, looking for spikes we missed and for low-and-slow traffic. I've created 6 new suspicion flags (DETCORE-4466). None carry pressure yet; charts attached (created vs verified per key).

*1. The 1050x1000 actor switched builds after our flags went in*
The invalid-resolution pair only catches the *Firefox* build of this kit. The same kit also runs as *Chrome 151-156*, which reports a consistent available resolution, so `g-dp-invalid-resolution` never fires on it. After the pair went live on Oct 21 the Firefox traffic dropped to ~0, but total volume hit its highest on Oct 26-27 (CLM 103 → 136/day). It's the same actor on the Chrome build.
1050x1000 isn't a real screen size, and 408 of the 411 sessions with it across all of Arkose in the last 3 days were Payoneer. It rotates between "Windows/Mac × Chrome/Firefox" profiles, but the browser viewport is identical across all of them.
• `payoneere3ef-h-dp-resolution-1050x1000`: CLM ~2.3k / 45d, 93% verified
• `payoneeree84-h-dp-resolution-1050x1000`: Login ~1.5k / 45d, 96% verified
These cover both builds, so they supersede the invalid-resolution pair.

*2. New actor: 830x800 screen with no taskbar, Windows, hotmail*
• `payoneer-h-dp-resolution-830x800-windows`: ~6.6k / 45d, 98-99% verified, rarely challenged
• Screen = available resolution, i.e. no taskbar, which a real Windows machine can't produce. 830x800 appears on no other Arkose key.
• 95% hotmail (baseline 5%), fake `en-EN` locale, CO/KR/JP residential IPs. On Login it's 66 fingerprints across ~1.5k IPs.
• This was the Oct 15-17 `reversed-navigator-languages-priority` surge. Quiet on CLM since Oct 23 and *active on Login now*, matching what @Saul Rincon saw about them moving keys.

*3. Tencent Cloud + templated outlook handles*
• `payoneer-h-tencent-cloud-4l4d-outlook`: hosting IPs + outlook handles of 4 letters + 4 digits (narrows the existing `payoneer-email-pattern-4-lowercase-letters-4-digits-outlook`)
• CLM burst Oct 7-19 (peak 355/day, 98% verified), still trickling on Login and Registration

*4. Watch only (alerting, no pressure)*
• `payoneer-h-watch-us-outlook-3440x1440-chrome150`: new Oct 22 on CLM, ~170-220/day, 97% verified, never challenged; starting on Login
• `payoneer-h-watch-cn-hotmail-1280x960-chrome109`: Oct 19-26, ~510 sessions, 100% verified; quiet now, kept as an alerter

*Pattern across the missed waves:* under ~400/day, ≥96% verified, each tied to one fixed device value (usually a screen resolution) plus outlook/hotmail. They change browser and UA between waves but keep that device value, so it's a more durable anchor than the fingerprint.

*Asks*
• SOC: can you review pressure for #1 and #2? Both are clean on Payoneer (≥99% one email provider, the resolution is unique to Payoneer). #1 also replaces the invalid-resolution pair.
• Product: an alert for "a rare resolution suddenly carrying volume" would have caught #1, #2 and the 3440x1440 cluster on day one.
