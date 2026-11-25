# Roblox Signup (Key 2, A2A14B1D) - "Direct3D renderer with a non-Windows UA": confirmed attack

Checked 2026-11-25. All counts exact unless marked (est. = 25% block sample x4).

## Verdict: attack (UA-spoofing bot on a residential proxy network), mostly blocked, now gone with the key

Checks, all from data available at session start (none rely on the verified outcome):

1. **The UA lies about the OS.** On every day Nov 10-23, 97-99.9% of the cohort reports `navigator.platform = Win32` while the UA
   says Linux/Ubuntu/Debian/Fedora/Chrome OS, and the WebGL renderer is Direct3D (Windows-only). The browser runs on Windows; only the
   UA string is fake.
2. **The fake UAs are generated, not real users.** Nov 23: 166,150 sessions; top claims are "Whale Browser 4" split almost evenly over
   Ubuntu 38.2k / Debian 35.7k / GNU/Linux 34.2k / Fedora 34.1k / Chrome OS 16.7k (Naver Whale on Linux is a tiny real-world
   population), plus Baidu Spark, Cheetah, Headless Chrome. 4,316 distinct browser+version claims and 335 renderers on 33 JA4s.
3. **It exists only on this key.** Nov 23 14:00-15:00 UTC, every Production key with >=20k sessions: Whale-on-Linux = 27,473 on Roblox
   Signup and 0 on every other key. Linux-UA + Win32-platform = 26.9% of Roblox Signup traffic vs 0.00-0.18% on every other big key
   (that small background is real users with UA-switcher extensions).
4. **On/off like a job.** Nov 23 per hour: ~300-480/h overnight, then 27-31k/h from 13:00 to 18:59 UTC, then stop.
5. **Residential proxy rotation.** 10,187 IPs (~16 sessions per IP), 77,545 stateless device ids; top ASNs are consumer ISPs in DE/ES
   (3320 Deutsche Telekom, 3209 Vodafone DE, 12479 Orange ES, 3352 Telefonica ES, 15704, 57269) - only ~1% hosting/proxy flagged,
   which is what residential proxies look like.
6. **Recurring.** Burst days (est.): Nov 12 ~169k (23% verified), Nov 14 ~43k (26%), Nov 18 ~52k (26%), Nov 21 ~41k (**58% verified**),
   Nov 23 ~160k-166k (2%). Between bursts a background of ~8-35k/day "Linux Chrome" at 0-3% verified.

Pass rate: 2% on Nov 23, but 23-58% on earlier burst days - it got through on Nov 12, 14, 18 and 21.

## Status
Roblox Signup Key 2 went dark at 19:00 UTC Nov 23 (whole key ~0 sessions since; 2 other Roblox keys went to 0 on Nov 19 too) -
looks like a Roblox key migration. The Whale-on-Linux tool was not seen on any Production key Nov 24 12:00-18:00. If Roblox moved
signup to a new key, the tool will follow: re-check once the new key is known.

## Side finding (same check, Nov 24 12:00-18:00)
- Uber SMS: 1.21M Linux-UA + Win32-platform sessions in 6h, 0% verified (the TR operation in the Uber SMS ticket).
- **E191DADD (Coinbase)**: 19,187 of 31,106 sessions (62%) are Linux-UA + Win32-platform, 17% verified - worth its own look.

## Telltale idea (key-agnostic, no pressure)
"Linux/Chrome OS UA but navigator.platform Win*" (+ optionally Direct3D renderer) - background on normal keys is <=0.2% of traffic,
so a per-key share >2% is a strong attack signal. Not drafted yet.
