# Disagreement report: today's DI dictionary vs layer 1 v3

**Key:** Figma Registration K2 (`A207F8A1-ED09-4325-ACE6-C8E26A458FBA`). **Window:** sessions created 2026-11-20 12:00-14:00 UTC,
**all 9,156 sessions, no sampling**. **Whitelist:** uncleaned Dict 63 signatures, 13-20 Nov, Figma account production keys
(Registration K2: 364,042 sessions / 65,959 signatures; Login Production: 1 session / 1 signature). **Mode:** standalone (layer 1):
no List A/B/C, N-rules or bad/suspicious lists, so the Impossible column is empty. **Truth data:** not used (as instructed), so no
Legit/Nonlegit split. Rules: `spec.md` §2 + agent file "Seen-before rules" (25 Nov, incl. items 5, 6, 9). Queries: `q1`-`q3b`, `examples_e*.sql`.

**How to read this.** Today's DI checks six fields in a fixed chain (OS -> JA4 -> screen -> device_params -> UA -> WebGL) and reports
how far it got (Dict 1 ... 63). The new scoring instead finds the closest whitelisted device of the same OS family, adds up the
weights of the fields that match (score 0-1), and bands it (A >= 0.85, B >= 0.65, C >= 0.40, else D), with consistency checks that
can force Band D. "Agree" means the same bucket: 63->A, 31/15->B, 7->C, 3/1/-1->D. "Moved up" = a better band than that, "moved down"
= worse. "Promoted" = today 1/3 -> A/B; "demoted" = today 63/31/15 -> D or Impossible.

**Summary: same bucket 64.6% (5,914), moved up 27.7% (2,535), moved down 7.7% (707). Promoted 333, demoted 176.**

## 1. Comparison table (sessions, row %)

| Today | A | B | C | D | Impossible | Total |
|---|---:|---:|---:|---:|---:|---:|
| 63 | 4,816 (95.9%) agree | 192 (3.8%) down | 2 (0.0%) down | 13 (0.3%) down, demoted | 0 | 5,023 |
| 31 | 874 (59.5%) up | 481 (32.7%) agree | 59 (4.0%) down | 56 (3.8%) down, demoted | 0 | 1,470 |
| 15 | 461 (43.7%) up | 406 (38.5%) agree | 81 (7.7%) down | 107 (10.1%) down, demoted | 0 | 1,055 |
| 7 | 337 (29.6%) up | 486 (42.7%) up | 118 (10.4%) agree | 197 (17.3%) down | 0 | 1,138 |
| 3 | 206 (46.2%) up, promoted | 110 (24.7%) up, promoted | 41 (9.2%) up | 89 (20.0%) agree | 0 | 446 |
| 1 | 11 (47.8%) up, promoted | 6 (26.1%) up, promoted | 2 (8.7%) up | 4 (17.4%) agree | 0 | 23 |
| -1 | 0 | 1 (100.0%) up | 0 | 0 agree | 0 | 1 |

Keys: one key in the window, so every cell's top key is Figma Registration K2 (100%).

## 2. Moved cells

Per cell: count, verified, High risk, challenged, challenged-not-solved; top 5 v3 reasons (count, High). Reason codes: `diff:` + fields that differ from the closest device (`JA4qt` = QUIC/TCP variant of the same browser, `UAmaj` = same browser+major, empty = exact match, B-cap for Windows RD/VM); `chk:` = Band D by the check trigger: failed checks, then `+` warning signs (`UAxDPx`/`SCRxDPx` = exact-only pair mismatch, `SCRnew`/`DPnew` = never-seen value). Examples: up to 5 per cell (see section 3 for which cells have none).

### 63 -> B (moved down): 192 sessions

Dict 63 today (exact match on all six fields) but below 0.85 in v3, or capped at B (Windows Basic Render). The largest group (87) are exact matches capped at B because they are Windows RD/VM (Basic Render Driver); the rest differ in one heavy field (DP 32, UA 30).

Verified 94.3% · High 6 (3.1%) · challenged 20.3% · challenged-not-solved 5.7% · mean v3 score 0.861

| Reason | n | High |
|---|---:|---:|
| `diff:DP` | 32 | 1 (3%) |
| `diff:JA4+UA` | 16 | 1 (6%) |
| `diff:SCR` | 9 | 0 (0%) |
| `diff:UA` | 30 | 0 (0%) |
| `diff:` | 87 | 4 (5%) |

Examples: not fetched (see section 3).

### 63 -> C (moved down): 2 sessions

Dict 63 today, but its closest whitelisted device differs in two heavy fields.

Verified 100.0% · High 0 (0.0%) · challenged 50.0% · challenged-not-solved 0.0% · mean v3 score 0.486

| Reason | n | High |
|---|---:|---:|
| `diff:DP` | 1 | 0 (0%) |
| `diff:UA+GL` | 1 | 0 (0%) |

Examples: not fetched (see section 3).

### 63 -> D (moved down (demoted)): 13 sessions

Dict 63 today, but the v3 check trigger fires (screen x WebGL / screen x platform group).

Verified 92.3% · High 1 (7.7%) · challenged 23.1% · challenged-not-solved 7.7% · mean v3 score 0.730

| Reason | n | High |
|---|---:|---:|
| `chk:SCRxDP SCRxGL` | 2 | 0 (0%) |
| `chk:SCRxGL` | 5 | 1 (20%) |
| `chk:SCRxPG +SCRnew` | 5 | 0 (0%) |
| `chk:UAxDP` | 1 | 0 (0%) |

Examples: not fetched (see section 3).

### 31 -> A (moved up): 874 sessions

Dict 31 today (all but WebGL matched). In v3 the closest device matches well enough (typically only JA4 variant or UA differs).

Verified 92.7% · High 42 (4.8%) · challenged 26.0% · challenged-not-solved 5.5% · mean v3 score 0.915

| Reason | n | High |
|---|---:|---:|
| `diff:GL` | 14 | 0 (0%) |
| `diff:JA4qt` | 294 | 11 (4%) |
| `diff:SCR` | 119 | 1 (1%) |
| `diff:UA` | 272 | 24 (9%) |
| `diff:` | 142 | 6 (4%) |

Examples (session | OS | group | OS ver | risk | score | reason | warnings | UA | JA4 | screen | device_params | renderer):
```
39118e9c38f67e135.4784606005|Windows|Desktop|10|Low|0.97|diff:JA4qt||Windows NT 10.0; Win64; x64) Chrome/157.0.0.0 Safari/53|t13d1517h2_8daaf6152771_a323378790d4|1920,1032::1920,1080|Win32::0::1::24::16::1::1::0::1::0::0::0::7EC6D|Intel, Intel(R) Graphics (0x0000
68618e9c3c4414794.1131631704|Windows|Desktop|10|Medium|1.00|diff:||Windows NT 10.0; Win64; x64) Chrome/157.0.0.0 Safari/53|q13d0312h3_55b375c5d22e_178839b6cec1|1920,1080::1920,1080|Win32::0::1::24::12::1::1::0::1::0::0::0::9A244|NVIDIA, NVIDIA GeForce GTX 1650
25518e9c262156c07.0581401105|Windows|Desktop|10|Medium|0.85|diff:UA|UAxDPx|Windows NT 10.0; Win64; x64) Chrome/152.0.0.0 Safari/53|q13d0312h3_55b375c5d22e_178839b6cec1|1536,816::1536,864|Win32::0::1::24::4::1::1::0::1::0::0::0::69398|Intel, Intel(R) UHD Graphics (0x
25918e9c45b49aca9.6618829104|Windows|Desktop|10|Low|0.97|diff:JA4qt||Windows NT 10.0; Win64; x64) Chrome/157.0.0.0 Safari/53|t13d1516h2_8daaf6152771_2f874e5dbbd9|1440,852::1440,900|Win32::0::1::24::12::1::1::0::1::0::0::0::7EC6D|AMD, AMD Radeon(TM) Graphics (0x
28418e9c29439c094.5359225305|GNU/Linux|Linux||Low|0.85|diff:UA||X11; Linux x86_64) Chrome/158.0.0.0 Safari/537.36|q13d0312h3_55b375c5d22e_178839b6cec1|1920,1080::1920,1080|Linux x86_64::0::1::24::12::1::1::0::1::0::0::0::BF471|Intel, Mesa Intel(R) Iris(R) Xe
```

### 31 -> C (moved down): 59 sessions

Dict 31 today, but the closest device differs in two fields.

Verified 91.5% · High 5 (8.5%) · challenged 16.9% · challenged-not-solved 5.1% · mean v3 score 0.542

| Reason | n | High |
|---|---:|---:|
| `diff:DP+GL` | 5 | 0 (0%) |
| `diff:GL` | 4 | 0 (0%) |
| `diff:SCR+GL` | 6 | 4 (67%) |
| `diff:UA+DP` | 12 | 0 (0%) |
| `diff:UA+GL` | 6 | 1 (17%) |

Examples: not fetched (see section 3).

### 31 -> D (moved down (demoted)): 56 sessions

Dict 31 today, but the v3 check trigger fires (desktop: 1 failed check + a warning sign, or 2 failed checks).

Verified 98.2% · High 3 (5.4%) · challenged 19.6% · challenged-not-solved 1.8% · mean v3 score 0.742

| Reason | n | High |
|---|---:|---:|
| `chk:SCRxDP SCRxGL` | 16 | 0 (0%) |
| `chk:SCRxDP` | 3 | 0 (0%) |
| `chk:SCRxGL +SCRxDPx` | 18 | 1 (6%) |
| `chk:SCRxGL` | 10 | 2 (20%) |
| `chk:SCRxPG +SCRnew` | 4 | 0 (0%) |

Examples (session | OS | group | OS ver | risk | score | reason | warnings | UA | JA4 | screen | device_params | renderer):
```
65818e9c3221859e2.7727914404|Windows|Desktop|10|Low|0.70|chk:SCRxDP SCRxGL||Windows NT 10.0; Win64; x64) Chrome/158.0.0.0 Safari/53|q13d0312h3_55b375c5d22e_178839b6cec1|1152,680::1152,720|Win32::0::1::24::4::1::1::0::1::0::0::0::CA17D|Intel, Intel(R) HD Graphics 4000
32318e9c16371e0c6.7255337305|GNU/Linux|Linux||Low|0.45|chk:UAxDP +SCRxDPx|SCRxDPx|X11; Linux x86_64) Chrome/157.0.0.0 Safari/537.36 Edg/1|q13d0311h3_55b375c5d22e_653d80c3fe9d|2560,1440::2560,1440|Linux x86_64::0::1::24::16::1::1::0::1::0::0::0::BF471|AMD, REMBRANDT (rembrandt LLVM 1
51018e9c2647b3e54.5700362705|Windows|Desktop|10|Low|0.85|chk:SCRxGL +SCRxDPx|SCRxDPx|Windows NT 10.0; Win64; x64) Chrome/157.0.0.0 Safari/53|q13d0312h3_55b375c5d22e_178839b6cec1|1280,976::1280,1024|Win32::0::1::24::12::1::1::0::1::0::0::0::9A244|Intel, Intel(R) UHD Graphics (0x
93018e9bfc72ede77.2167141305|Windows|Desktop|10|Low|0.85|chk:SCRxGL +SCRxDPx|SCRxDPx|Windows NT 10.0; Win64; x64) Chrome/157.0.0.0 Safari/53|q13d0312h3_55b375c5d22e_178839b6cec1|2560,1032::2560,1080|Win32::0::1::24::4::1::1::0::1::0::0::0::CA17D|Intel, Intel(R) HD Graphics 6000
32618e9c03c791485.0173117604|Android|Mobile|10|Low|0.70|chk:SCRxGL||Linux; Android 10; K) Chrome/138.0.0.0 Mobile Safari/53|q13d0311h3_55b375c5d22e_653d80c3fe9d|676,320::676,320|Linux armv81::1::1::24::8::1::1::0::1::5::1::1::786DE|Mali-T830
```

### 15 -> A (moved up): 461 sessions

Dict 15 today (UA and WebGL not matched in the chain). In v3 a close device exists; one field differs.

Verified 93.5% · High 25 (5.4%) · challenged 32.5% · challenged-not-solved 6.3% · mean v3 score 0.915

| Reason | n | High |
|---|---:|---:|
| `diff:DP` | 23 | 0 (0%) |
| `diff:JA4qt` | 127 | 9 (7%) |
| `diff:UAmaj` | 54 | 4 (7%) |
| `diff:UA` | 124 | 9 (7%) |
| `diff:` | 77 | 2 (3%) |

Examples (session | OS | group | OS ver | risk | score | reason | warnings | UA | JA4 | screen | device_params | renderer):
```
46618e9c036e32a66.8943399201|Windows|Desktop|10|Low|0.93|diff:UAmaj||Windows NT 10.0; Win64; x64) Chrome/157.0.8103.39 Safar|q13d0312h3_55b375c5d22e_178839b6cec1|1366,720::1366,768|Win32::0::1::24::8::1::1::0::1::0::0::0::7EC6D|Intel, Intel(R) UHD Graphics 620
10218e9c3a6439bc2.5936448405|Windows|Desktop|10|Medium|0.85|diff:UA||Windows NT 10.0; Win64; x64) Chrome/154.0.0.0 Safari/53|q13d0312h3_55b375c5d22e_178839b6cec1|1707,1019::1707,1067|Win32::0::1::24::16::1::1::0::1::0::0::0::5F5BD|AMD, AMD Radeon 780M Graphics (0
15718e9bf72a60917.8754269805|OS X|Desktop|10.15.7|Low|0.95|diff:JA4qt||Macintosh; Intel Mac OS X 10_15_7) Chrome/157.0.0.0 Saf|t13d1517h2_8daaf6152771_5cd47779f5c5|1512,863::1512,982|MacIntel::0::1::30::12::1::1::0::1::0::0::0::4D4F4|Apple, ANGLE Metal Renderer: App
67018e9bf2f29f504.2786927804|Windows|Desktop|10|Medium|1.00|diff:||Windows NT 10.0; Win64; x64) Chrome/158.0.0.0 Safari/53|q13d0312h3_55b375c5d22e_178839b6cec1|1280,690::1280,720|Win32::0::1::24::8::1::1::0::1::0::0::0::7EC6D|Intel, Intel(R) UHD Graphics 620
44918e9c21dd712c3.7077881105|Windows|Desktop|10|High|1.00|diff:||Windows NT 10.0; Win64; x64) Chrome/154.0.0.0 Safari/53|q13d0312h3_55b375c5d22e_178839b6cec1|1536,920::1536,960|Win32::0::1::24::16::1::1::0::1::0::0::0::7EC6D|Intel, Intel(R) Iris(R) Xe Graph
```

### 15 -> C (moved down): 81 sessions

Dict 15 today; closest device differs in UA and DP. Highest-risk moved cell with more than 10 sessions (19.8% High).

Verified 77.8% · High 16 (19.8%) · challenged 49.4% · challenged-not-solved 13.6% · mean v3 score 0.547

| Reason | n | High |
|---|---:|---:|
| `diff:JA4qt+UA+DP` | 10 | 0 (0%) |
| `diff:JA4qt+UA+GL` | 3 | 0 (0%) |
| `diff:SCR+DP` | 4 | 0 (0%) |
| `diff:UA+DP` | 42 | 13 (31%) |
| `diff:UA+GL` | 5 | 1 (20%) |

Examples (session | OS | group | OS ver | risk | score | reason | warnings | UA | JA4 | screen | device_params | renderer):
```
10518e9bf44451334.1106921505|Windows|Desktop|10|Low|0.55|diff:UA+DP|UAxDPx|Windows NT 10.0; Win64; x64) Chrome/155.0.8059.85 Safar|q13d0312h3_55b375c5d22e_178839b6cec1|2560,1392::2560,1440|Win32::0::1::24::28::1::1::0::1::0::0::0::5F5BD|AMD, AMD Radeon RX 7900 XT (0x00
23218e9c52457b589.6236393701|Windows|Desktop|10|Medium|0.55|diff:UA+DP|UAxDPx SCRxDPx|Windows NT 10.0; Win64; x64) Chrome/158.0.0.0 Safari/53|q13d0312h3_55b375c5d22e_178839b6cec1|2560,1400::2560,1440|Win32::0::1::24::16::1::1::0::1::0::0::0::31526|NVIDIA, NVIDIA GeForce RTX 2070
24918e9bf1226c1f7.5333070701|Windows|Desktop|10|Medium|0.55|diff:UA+DP|UAxDPx|Windows NT 10.0; Win64; x64) Chrome/158.0.0.0 Safari/53|q13d0312h3_55b375c5d22e_178839b6cec1|1920,1040::1920,1080|Win32::0::1::24::4::1::1::0::1::10::0::0::5F5BD|NVIDIA, NVIDIA GeForce GTX 750 T
93818e9bf7139e0c7.7597070005|Windows|Desktop|10|Medium|0.52|diff:JA4qt+UA+GL||Windows NT 10.0; Win64; x64) Chrome/158.0.0.0 Safari/53|t13d1517h2_8daaf6152771_ff1e8fc497ec|1920,1040::1920,1080|Win32::0::1::24::8::1::1::0::1::0::0::0::CFAB1|AMD, Radeon(TM) RX 460 Graphics
81518e9c44b295868.5807150305|Windows|Desktop|10|Medium|0.52|diff:JA4qt+UA+DP|UAxDPx|Windows NT 10.0; Win64; x64) Chrome/152.0.0.0 Safari/53|t13d1517h2_8daaf6152771_43736b97bd57|1536,816::1536,864|Win32::0::1::24::12::1::1::0::1::0::0::0::AB3EE|AMD, AMD Radeon(TM) 660M (0x0000
```

### 15 -> D (moved down (demoted)): 107 sessions

Dict 15 today; v3 check trigger fires.

Verified 95.3% · High 4 (3.7%) · challenged 19.6% · challenged-not-solved 3.7% · mean v3 score 0.576

| Reason | n | High |
|---|---:|---:|
| `chk:SCRxDP SCRxGL` | 17 | 0 (0%) |
| `chk:SCRxGL +UAxDPx` | 16 | 0 (0%) |
| `chk:SCRxGL` | 9 | 0 (0%) |
| `chk:UAxDP SCRxDP` | 9 | 0 (0%) |
| `chk:UAxDP` | 17 | 3 (18%) |

Examples (session | OS | group | OS ver | risk | score | reason | warnings | UA | JA4 | screen | device_params | renderer):
```
27218e9c039807ae7.4676215104|Windows|Desktop|10|Low|0.70|chk:SCRxDP SCRxGL||Windows NT 10.0; Win64; x64) Chrome/151.0.0.0 Safari/53|q13d0311h3_55b375c5d22e_653d80c3fe9d|1477,794::1477,831|Win32::0::1::24::8::1::1::0::1::0::0::0::7EC6D|Intel, Intel(R) UHD Graphics 620
76918e9c1c43a9b78.0133200205|Android|Mobile|13|High|0.85|chk:UAxDP||Linux; arm_64; Android 13; TECNO CH6i) Chrome/154.0.803|q13d0312h3_55b375c5d22e_178839b6cec1|820,360::820,360|Linux aarch64::1::1::24::8::1::1::0::1::5::1::1::786DE|ARM, Mali-G52 MC2, OpenGL ES 3.2
47718e9c28356eae5.0294610605|OS X|Desktop|10.15.7|Low|0.50|chk:UAxDP SCRxDP SCRxGL||Macintosh; Intel Mac OS X 10_15_7) Chrome/158.0.0.0 Saf|q13d0311h3_55b375c5d22e_653d80c3fe9d|3840,2160::3840,2160|MacIntel::0::1::24::5::1::1::0::1::0::0::0::6899D|Brave
73518e9c084416bf2.0812109104|Windows|Desktop|10|Low|0.55|chk:SCRxGL +UAxDPx|UAxDPx|Windows NT 10.0; Win64; x64) Chrome/135.0.0.0 Safari/53|q13d0311h3_55b375c5d22e_653d80c3fe9d|1366,720::1366,768|Win32::0::1::24::8::1::1::0::1::0::0::0::5F5BD|AMD, Radeon RX550/550 Series (0x
39518e9c2a3528b42.6778133304|Windows|Desktop|10|Low|0.45|chk:SCRxGL +UAxDPx|UAxDPx|Windows NT 10.0; Win64; x64) Chrome/151.0.0.0 Safari/53|q13d0311h3_55b375c5d22e_653d80c3fe9d|1536,816::1536,864|Win32::0::1::24::6::1::1::0::1::0::0::0::9A244|NVIDIA, NVIDIA GeForce RTX 2070
```

### 7 -> A (moved up): 337 sessions

Dict 7 today (device_params broke the chain). In v3 a close device exists; one field differs.

Verified 92.6% · High 11 (3.3%) · challenged 23.7% · challenged-not-solved 5.9% · mean v3 score 0.923

| Reason | n | High |
|---|---:|---:|
| `diff:DP` | 65 | 1 (2%) |
| `diff:JA4qt` | 143 | 7 (5%) |
| `diff:JA4` | 29 | 1 (3%) |
| `diff:SCR` | 45 | 0 (0%) |
| `diff:` | 48 | 2 (4%) |

Examples (session | OS | group | OS ver | risk | score | reason | warnings | UA | JA4 | screen | device_params | renderer):
```
83118e9bf22433ad2.8058831205|Windows|Desktop|10|Medium|1.00|diff:||Windows NT 10.0; Win64; x64) Chrome/157.0.0.0 Safari/53|q13d0312h3_55b375c5d22e_178839b6cec1|1536,804::1536,864|Win32::0::1::24::12::1::1::0::1::0::0::0::9A244|AMD, AMD Radeon(TM) Graphics (0x
90418e9c4531c0a73.9238004105|OS X|Desktop|10.15.7|Medium|0.85|diff:DP|UAxDPx|Macintosh; Intel Mac OS X 10_15_7) Chrome/154.0.0.0 Saf|q13d0312h3_55b375c5d22e_178839b6cec1|2560,1350::2560,1440|MacIntel::0::1::24::12::1::1::0::1::0::0::0::9BC18|Apple, ANGLE Metal Renderer: App
41018e9c33f167412.1374318302|Windows|Desktop|10|Medium|0.97|diff:JA4qt||Windows NT 10.0; Win64; x64) Chrome/157.0.0.0 Safari/53|t13d1516h2_8daaf6152771_3b583109fb37|2048,1104::2048,1152|Win32::0::1::24::20::1::1::0::1::0::0::0::7EC6D|NVIDIA, NVIDIA GeForce RTX 4060
33718e9c4ff68cd12.2959736805|Windows|Desktop|10|Low|0.90|diff:JA4||Windows NT 10.0; Win64; x64) Chrome/157.0.0.0 Safari/53|t13d3012h2_1d37bd780c83_8e6e362c5eac|1366,720::1366,768|Win32::0::1::24::4::1::1::0::1::0::0::0::5F5BD|Intel, Intel(R) HD Graphics 3000
29218e9c51877a7e5.7558517205|Windows|Desktop|10|Low|0.97|diff:JA4qt||Windows NT 10.0; Win64; x64) Chrome/157.0.0.0 Safari/53|t13d6912h1_8b2139ff7677_63b9908f8f0e|2560,1392::2560,1440|Win32::0::1::24::12::1::1::0::1::0::0::0::CA17D|Intel, Intel(R) Iris(R) Xe Graph
```

### 7 -> B (moved up): 486 sessions

Dict 7 today; one heavy field (usually DP) or two light fields differ.

Verified 87.2% · High 23 (4.7%) · challenged 30.9% · challenged-not-solved 10.3% · mean v3 score 0.725

| Reason | n | High |
|---|---:|---:|
| `diff:DP` | 172 | 11 (6%) |
| `diff:JA4+UA` | 28 | 3 (11%) |
| `diff:JA4qt+DP` | 119 | 2 (2%) |
| `diff:JA4qt+SCR` | 38 | 0 (0%) |
| `diff:JA4qt+UA` | 51 | 4 (8%) |

Examples (session | OS | group | OS ver | risk | score | reason | warnings | UA | JA4 | screen | device_params | renderer):
```
37818e9bf4e7301b6.8933278501|Windows|Desktop|10|High|0.82|diff:JA4qt+UA||Windows NT 10.0; Win64; x64) Chrome/158.0.0.0 Safari/53|t13d1518h2_8daaf6152771_039c54192a81|1366,720::1366,768|Win32::0::1::24::8::1::1::0::1::0::0::0::CA17D|AMD, AMD Radeon(TM) Vega 8 Graph
32518e9c03c3e9f58.0107206005|Windows|Desktop|10|Low|0.82|diff:JA4qt+SCR||Windows NT 10.0; Win64; x64) Chrome/157.0.0.0 Safari/53|t13d1516h2_8daaf6152771_7876f607db57|1440,852::1440,900|Win32::0::1::24::20::1::1::0::1::0::0::0::69398|Intel, Intel(R) Iris(R) Xe Graph
25118e9c44923dad4.2746675301|Windows|Desktop|10|Low|0.82|diff:JA4qt+UA||Windows NT 10.0; Win64; x64) Chrome/139.0.0.0 Safari/53|t13d1516h2_8daaf6152771_d8a2da3f94cd|3440,1392::3440,1440|Win32::0::1::24::12::1::1::0::1::0::0::0::7EC6D|Intel, Intel(R) Iris(R) Xe Graph
55118e9c4592cc114.4683078304|Windows|Desktop|10|Low|0.70|diff:DP||Windows NT 10.0; Win64; x64) Chrome/157.0.0.0 Safari/53|q13d0311h3_55b375c5d22e_653d80c3fe9d|1366,768::1366,768|Win32::0::1::24::6::1::1::0::1::0::0::0::69398|AMD, AMD Radeon(TM) Graphics (0x
87618e9c0a564ede6.3452484405|Windows|Desktop|10|Low|0.82|diff:JA4qt+UA|UAxDPx|Windows NT 10.0; Win64; x64) Chrome/158.0.0.0 Safari/53|t13d1517h2_8daaf6152771_92a4fdd66f79|1920,1040::1920,1080|Win32::0::1::24::16::1::1::0::1::0::0::0::69398|AMD, AMD Radeon(TM) Graphics (0x
```

### 7 -> D (moved down): 197 sessions

Dict 7 today; v3 check trigger fires (mostly screen x WebGL with a second signal).

Verified 93.9% · High 11 (5.6%) · challenged 17.3% · challenged-not-solved 6.1% · mean v3 score 0.537

| Reason | n | High |
|---|---:|---:|
| `chk:SCRxDP SCRxGL` | 33 | 1 (3%) |
| `chk:SCRxGL +DPnew` | 34 | 0 (0%) |
| `chk:SCRxGL +SCRxDPx` | 26 | 0 (0%) |
| `chk:SCRxPG +SCRnew +DPnew` | 18 | 1 (6%) |
| `diff:JA4qt+DP+GL` | 23 | 4 (17%) |

Examples (session | OS | group | OS ver | risk | score | reason | warnings | UA | JA4 | screen | device_params | renderer):
```
83018e9c2c0590645.2722828301|Windows|Other|10|Medium|0.37|chk:SCRxPG +SCRnew +DPnew|SCRnew DPnew|Windows NT 10.0; Win64; x64) Chrome/152.0.0.0 Safari/53|t13d1517h2_8daaf6152771_0d789d2519e1|1600,852::1600,900|Win32::0::1::24::20::1::1::0::1::0::0::0::AEC4E|Mesa, llvmpipe (LLVM 20.1.2 256
50318e9bfb6b91129.9516093705|Windows|Desktop|10|Low|0.52|chk:UAxDP SCRxDP||Windows NT 10.0; Win64; x64) Chrome/158.0.0.0 Safari/53|t13d1517h2_8daaf6152771_61307d0e143d|2560,1392::2560,1440|Win32::0::1::24::20::1::1::0::1::2::0::0::7EC6D|NVIDIA, NVIDIA RTX A1000 (0x0000
92518e9bf7a316768.6920242305|Windows|Windows RD/VM|10|Medium|0.64|chk:UAxDP +SCRxDPx|SCRxDPx|Windows NT 10.0; Win64; x64) Chrome/155.0.0.0 Safari/53|t13d241100_df98b6d6dfe4_ecbbeb3a4960|1536,824::1536,864|Win32::0::1::24::6::1::1::0::1::0::0::0::69398|Microsoft, Microsoft Basic Rende
98118e9c398e2d2f3.7483051901|Windows|Desktop|10|Low|0.55|chk:SCRxGL +SCRxDPx|SCRxDPx|Windows NT 10.0; Win64; x64) Chrome/157.0.0.0 Safari/53|q13d0312h3_55b375c5d22e_178839b6cec1|2560,1032::2560,1080|Win32::0::1::24::8::1::1::0::1::0::0::0::67865|NVIDIA, NVIDIA GeForce GTX 750 (
99018e9bf253e83d4.6751272405|Windows|Desktop|10|Low|0.52|chk:SCRxGL +SCRxDPx|SCRxDPx|Windows NT 10.0; Win64; x64) Chrome/157.0.0.0 Safari/53|t13d1517h2_8daaf6152771_e1144aa4d245|3440,1392::3440,1440|Win32::0::1::24::16::1::1::0::1::0::0::0::9A244|NVIDIA, NVIDIA T1000 8GB (0x0000
```

### 3 -> A (moved up (promoted)): 206 sessions

Dict 3 today (screen broke the chain). In v3 near-identical to a whitelisted device: drift recovered (mostly JA4 QUIC/TCP variant or available-size).

Verified 92.2% · High 16 (7.8%) · challenged 33.5% · challenged-not-solved 6.8% · mean v3 score 0.942

| Reason | n | High |
|---|---:|---:|
| `diff:JA4qt` | 70 | 10 (14%) |
| `diff:JA4` | 21 | 0 (0%) |
| `diff:SCR` | 25 | 1 (4%) |
| `diff:UAmaj` | 13 | 3 (23%) |
| `diff:` | 67 | 2 (3%) |

Examples: not fetched (see section 3).

### 3 -> B (moved up (promoted)): 110 sessions

Dict 3 today; closest device differs in one or two fields.

Verified 90.9% · High 5 (4.5%) · challenged 33.6% · challenged-not-solved 8.2% · mean v3 score 0.738

| Reason | n | High |
|---|---:|---:|
| `diff:JA4+UA` | 9 | 0 (0%) |
| `diff:JA4qt+SCR` | 16 | 1 (6%) |
| `diff:JA4qt+UA+SCR` | 7 | 0 (0%) |
| `diff:JA4qt+UA` | 22 | 2 (9%) |
| `diff:SCR` | 27 | 2 (7%) |

Examples: not fetched (see section 3).

### 3 -> C (moved up): 41 sessions

Dict 3 today; two or three fields differ.

Verified 87.8% · High 5 (12.2%) · challenged 39.0% · challenged-not-solved 9.8% · mean v3 score 0.528

| Reason | n | High |
|---|---:|---:|
| `diff:JA4+DP` | 3 | 0 (0%) |
| `diff:JA4+UA+DP` | 3 | 2 (67%) |
| `diff:JA4+UA+SCR` | 3 | 1 (33%) |
| `diff:JA4qt+UA+SCR` | 3 | 0 (0%) |
| `diff:SCR+DP` | 8 | 1 (12%) |

Examples: not fetched (see section 3).

### 1 -> A (moved up (promoted)): 11 sessions

Dict 1 today (JA4 broke the chain). In v3 only the JA4 differs.

Verified 90.9% · High 1 (9.1%) · challenged 27.3% · challenged-not-solved 9.1% · mean v3 score 0.877

| Reason | n | High |
|---|---:|---:|
| `diff:JA4` | 11 | 1 (9%) |

Examples: not fetched (see section 3).

### 1 -> B (moved up (promoted)): 6 sessions

Dict 1 today; JA4 plus another field differ.

Verified 66.7% · High 1 (16.7%) · challenged 50.0% · challenged-not-solved 33.3% · mean v3 score 0.743

| Reason | n | High |
|---|---:|---:|
| `diff:JA4+SCR` | 1 | 0 (0%) |
| `diff:JA4+UA+DP` | 1 | 0 (0%) |
| `diff:JA4qt+SCR` | 1 | 0 (0%) |
| `diff:JA4` | 3 | 1 (33%) |

Examples: not fetched (see section 3).

### 1 -> C (moved up): 2 sessions

Dict 1 today; JA4 plus another field differ.

Verified 100.0% · High 0 (0.0%) · challenged 50.0% · challenged-not-solved 0.0% · mean v3 score 0.621

| Reason | n | High |
|---|---:|---:|
| `diff:JA4+GL` | 1 | 0 (0%) |
| `diff:JA4+SCR` | 1 | 0 (0%) |

Examples: not fetched (see section 3).

### -1 -> B (moved up): 1 sessions

No dictionary match today; in v3 one device differs only in UA (0.70).

Verified 100.0% · High 0 (0.0%) · challenged 0.0% · challenged-not-solved 0.0% · mean v3 score 0.700

| Reason | n | High |
|---|---:|---:|
| `diff:UA` | 1 | 0 (0%) |

Examples: not fetched (see section 3).

## 3. What was not done

- **Examples: 5 per cell, not 20.** Each example row costs about 550 tokens of Superset response (rows are returned twice), so calls
  with 40 and then 30 rows exceeded the 25k cap. Fetched: 31->A, 15->A, 7->A, 7->B, 31->D, 15->C, 15->D, 7->D (5 each).
  **Not fetched** (queries saved, not run, to stay within budget): 3->A, 3->B, 3->C, 1->A, 1->B (`examples_e2.sql`); 1->C, -1->B,
  63->B, 63->C, 63->D, 31->C (`examples_e3.sql`).
- **Top reasons are top 5 per cell**, so the per-field counts are lower bounds.
- **No truth data**, so no Legit/Nonlegit split.
