# Known cases (ground truth for replays)

Each case has a key, a time window (UTC) and a signature, so it can be replayed. "Expected" is what a correct rule set should do. Verify rates are indicators only: several of these attacks verified at high rates.

## Bad traffic (should NOT reach Band A/B; impossible-combo rules should catch where applicable)

### K1. Uber SMS Key 1: Safari / HTTP-library TLS on Windows claims
- **Key:** `30000F36-CADF-490C-929A-C6A7DD8B33C4`
- **Window:** 25 Oct–2 Nov 2026 (exact counts on the thresholds one-pager)
- **Signatures:**
  - `t13d2613h2_2802a3db6c62_845d286b0d67` claiming Windows Firefox 159 / Chrome 156 / Edge 156 (~1.35M) → **C1**
  - `t13d2014h2_a09f3c656075_14788d8d241b` claiming Windows Chrome 156 / Opera 137 (~300K) → **C1**
  - `t13d1516h1_8daaf6152771_e5627efa2ab1` with Chrome 152/153 (~1.27M) → **C2**
  - `t12d1209h2_d34a8e72043a_e08eabe7240f` claiming Chrome 156/158 on Windows (~30K) → **C3**
- **Expected:** List C catches all; similarity gives no score.

### K2. AT&T Consumer SDK Android K4: WebView Chrome 120 attack
- **Key:** `4DD22AF2-94A7-4F86-8A2B-C91DEB011C24`
- **Window:** 17 Nov ~08:00 → 18 Nov 01:28 UTC
- **Signature:** `location = session_setup`, JA4 IN (`t13d1516h2_8daaf6152771_02713d6af862`, `t13d1517h2_8daaf6152771_b1ff8ab2d16f`), UA matches `; wv\).*Chrome/120\.`
- **Facts:** ~31k sessions, 26k residential IPs, 68 signatures, 4–17% verified (vs 98% normal), mostly dict 3.
- **Expected:** not Band A/B. Old WebView version vs current Android may be an N3/N7-type check.

### K3. Adobe ARP FF K8: solver farm on one hosting IPv6
- **Keys:** `BBCC314C-4937-4CCD-B0A3-FDF0F0F7603C` (ARP FF K8), also `430FF2C3-1AB1-40B7-8BE7-44FC683FE02C` (Sign-in K5)
- **Window:** ramped 12 Nov; active through at least 18 Nov 07:00
- **Signature:** `user_ip LIKE '2a03:4000:6:cc79:%'` (netcup, DE), UA Chrome/146 Windows, JA4 `q13d0311h3_55b375c5d22e_653d80c3fe9d`, ~91% dict 31 at ~3x ST/LT
- **Facts:** 6–9k sessions/day; 29% reach verify, 100% of those verified; ~9 concurrent sessions; fastest solve 1.1s.
- **Expected:** velocity (Dict 31 cell) fires; similarity alone may score it high (real Chrome), so this tests that velocity, not similarity, catches it.

### K4. Adobe Sign Up K2: solver farm
- **Key:** Adobe Sign Up K2 (look up key; IP `38.147.104.247`)
- **Window:** until 15 Nov 15:10 UTC
- **Facts:** ~13k sessions from one IP.

### K5. gtop100.com: UA-randomised vote-bot fleet
- **Key:** `FDED3FA5-1764-490F-8BA3-7CE7B0553BC9`
- **Window:** any day 14–18 Nov
- **Signature:** UA contains `BingSapphire/` and `Chrome/1(0|1|2|3)[0-9].`; ~1 IP and 1 UA per session; some TLS 1.2 no-h2 JA4s (`t12d2010s2_0bf03fa604e3_736b2a1ed4d3`)
- **Facts:** 40–70k sessions/day, 5.4% verified. Real BingSapphire users elsewhere: 97% on Chrome ≥ 140.
- **Expected:** N7 catches; C2/C3-style checks catch the TLS 1.2 subset.

### K6. Headless / software-GPU traffic
- **Signature:** List A renderers; per the thresholds one-pager, Linux + SwiftShader/llvmpipe reaches Dict 63 59% of the time at 75% High risk; iOS/macOS + SwiftShader is 98% High risk.
- **Top keys:** DoorDash Website, Adobe Sign-in, Wells Fargo Login (Detect), Adobe Commerce.
- **Expected:** List A caps; List B no-match.

## Legitimate traffic (should NOT be pushed down)

### L1. Payoneer proxy JA4 change (ESM-7158)
- **Keys:** `EE844FC3-499D-4A4D-A643-D7400F0FD4DE`, `E3EFEFBF-8DE4-42ED-9E7F-92F35B1FD3CF`, `7CC24C4A-611B-41C7-9808-B95722C7861C`
- **Window:** 17 Nov 21:00 → 18 Nov ~20:00 UTC (peak 18 Nov 10:00–14:00)
- **What happened:** proxy JA4 changed `t13d1312h1_…e381dae6da6b` → `t13d1311h1_…485d6013ba69`; every session went to dict 1 (99% at peak), then promoted signatures breached velocity at dict 3/15. ~96% verified.
- **Expected:** similarity with JA4 weight 0 on proxy keys keeps them Band A/B; List C must not fire (proxy key exclusion); thresholds don't fire en masse (G8).

### L2. Googlebot on DoorDash Website K1
- **Key:** `DE24F792-2F8A-4CDC-BF2D-70F94BF1660A`, IPs 66.249.x / 192.178.x, Googlebot UA, JA4 `t13d181200_e8a523a41297_*`
- **Expected:** identify, don't treat as attack (good-bot handling is separate).

### L3. Windows remote desktop / VDI
- **Signature:** Windows + Microsoft Basic Render Driver; ~13% High risk, ~50% solve.
- **Expected:** stays eligible, capped at Band B, own threshold group.

### L4. Android 17 / os_version release (ESM-7076, 3 Nov)
- **Window:** 3 Nov 05:35 UTC onward (Device Detection API 1.4.0)
- **Expected:** a newer OS version is neutral under similarity (no mass demotion).

### L5. Chrome major release / iOS release day
- **Expected:** never-seen UA / OS version is neutral; single-field drift stays Band A/B.
