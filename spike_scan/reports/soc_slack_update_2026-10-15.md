*Update, Oct 15 21:30 UTC* :rotating_light: I re-ran the scan up to now. Most of these attacks are still running, some have reached new keys, and there's 1 new combination. Refreshed action pack attached.

*Still ongoing today (Oct 15), on keys we already flagged*
• *Adobe ARP FF (Key 8):* hit by 3 of the signals. Today: 573k on the live TT `g-pagebio-null-…-rfc-ct-before-cl` (now *64% verified*, up from ~50%), 581k on `…tz-mismatch-grease` and 161k on `…di-dict3` (a new high). This is the biggest one, and more of it is getting through. Can we review the action on this key?
• *Roblox Signup (Key 2):* 133k today on `g-bio-mouse-single-click-device-param-spoofing`, 0% verified, the 4th wave since Oct 2.
• *Uber SMS (Key 1):* new high of 88k on `…single-click…`, 47% verified.
• *gtop100.com:* 3rd day in a row on `…grease` (30k) and `…single-click…` (21k), 75–95% verified.
• *WBD Account Lookup (Key 20):* burst again on the live TT, 4.3k at 0% verified, the 4th time since Sep 28.
• *Quiet today:* AT&T, Airbnb and Roblox Login (they've repeated before, every 6–21 days), and `g-rta-isp-velocity-lt-pagebio-null`.

*Same signals, new keys*
• *Roblox Game Join (Key 6):* a 1-hour burst at 10:00 UTC with 0% verified. It hit `g-cdn-ends-te-device-param-spoofing` (31k, first time on this key), `…di-dict3` (15k, a new high) and `…single-click…` (14k).
• *Microsoft Account Signup:* new highs on `…di-dict3` and `…ends-te…` (6.4k each, 0% verified).
• Because of this I've *upgraded `g-cdn-ends-te-device-param-spoofing` from hold to create (scoped to Roblox Signup + Game Join)*. It fired on 7 keys today, and Roblox Signup has now had 5 bursts.

*NEW combination: `g-di-short-300-pxr1-device-param-spoofing-ja4-dict1`* (draft validated)
`di-short-count-300-fp-pixel-ratio-1` + `g-device-parameter-spoofing` + `ja4-dict-1-challenger`
• *Uber SMS:* 6 bursts since Sep 26 (Sep 26, Sep 28, Oct 4–7, today), mostly verified, so it's getting through.
• *Started today at 15–20h UTC* on *GitLab Sign Up* (17k), *Wells Fargo Login* (7.9k) and *Wells Fargo Password Reset* (4.5k), all at 0–1% verified and all starting within the same few hours.
• :warning: *Pinterest Login + Registration* (~700k/day) have matched since exactly Oct 14 16:00 UTC, steadily, with a normal day/night pattern and *93–98% verified*. That looks like a Pinterest client change, not an attack. Please *exclude Pinterest* (or review it) before activating.

*FYI, not an ask:* `g-ip-residential-proxy-user-ip` jumped ~3.5× on Oct 14 across ~50 keys at once, with no TT edit. That looks like an IP-intel feed or list update rather than an attack. Worth checking with the IP-intel owners.

*Asks, updated:* create `…grease`, `…di-dict3`, `…single-click…` and the new `…ja4-dict1` (excluding Pinterest). Create `…ends-te…` and `…rta…`, each scoped to its keys. Review Adobe ARP on the live TT. Thanks! :pray:
