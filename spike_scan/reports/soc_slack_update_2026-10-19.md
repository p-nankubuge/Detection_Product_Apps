*Weekend update, Oct 16–18 (data to Oct 19 00:00 UTC)* :rotating_light: I re-ran everything up to now. The refreshed action pack (per-key hourly charts from Oct 15) is attached.

*Not mitigated, top ask*
• *Adobe ARP FF (Key 8):* it grew over the weekend: 959k (Fri), *1.42M (Sat)*, 902k (Sun) per day on the live TT `g-pagebio-null-…-rfc-ct-before-cl`. *59–75% is verified*, so the TT fires but doesn't stop it. It peaked at 168k/h on Sun at 12:00 UTC. It's also on `…grease` (same volume) and `…di-dict3` (251k on Sun, a new high). *Can we change the action on this key?*

*Same signals, new keys*
• *WBD Account Lookup (Key 20):* 435k on Sun on the live TT, 23% verified, with a 188k/h peak at 19h UTC.
• *WBD Login (Key 8):* 203k on Sun on the live TT (39% verified) and 103k on `…grease` (77% verified).
• *AT&T Consumer SDK Android (Key 4):* 30k on `…di-dict3`, 0% verified (a 2-hour burst on Sun).
• *Adobe Commerce (Key 3):* 35–39k/day on the new `…ja4-dict1` since Fri, 0% verified, still running.
• *WBD Multi-Tenant Login (Key 18):* 120k on `…ja4-dict1` in 1 hour on Fri, 84% verified.
• *Tinder PreSMS (Key 3):* 19k on `…ends-te…` on Sat, 0% verified.
• *Olo Payments (Key 3):* on `…di-dict3` and the live TT since Sat, ~10k/day, still running.

*Recurring keys came back*
• *Roblox Signup (Key 2):* its biggest wave yet, *209k on Sun* on `g-cdn-ends-te-device-param-spoofing` (19% verified), its 6th burst since Sep 29.
• *Uber SMS:* a 7th `…ja4-dict1` burst (45k in 1 hour on Sun, 92% verified).

*Mitigated or stopped*
• *GitLab Sign Up:* peaked at 361k on Fri (0% verified), stopped Sat at 10:00 UTC.
• *Pinterest:* stopped matching `…ja4-dict1` on Fri morning, which confirms it was a client change. Still exclude it.
• *Uber:* `…grease` (~90k/day) is now only 4% verified. *Roblox Game Join:* quiet since Oct 15.

*New discovery:* no new combination to create. One to watch on Uber only: `g-spoofing-user-agent` + `g-di-bad-signature-list-match` + `g-device-parameter-spoofing` (~30–55k on Sun, ~30–50% verified).

*Asks, unchanged plus Adobe ARP:* change the action on Adobe ARP. Create `…grease`, `…di-dict3`, `…single-click…` and `…ja4-dict1` (excluding Pinterest). Create `…ends-te…` scoped to Roblox Signup + Game Join. Thanks! :pray:
