# Sanity test (confirm run, 2026-11-26)

Executed: `sanity_test_confirm_executed.sql` (built by `_scripts/gen_sanity.py` from the v4 executed sanity text: the 14 `spec.md` worked
examples and the v3 toy whitelist, n = 1 each), with the **main v4 cut-offs used in this run** (desktop: exact pair never seen; mobile
SCRxDP coarse and SCRxPG < 1e-4) instead of v4's artificial 0.5. `_core_template_v4.sql` in this folder is byte-identical to v4's.

Columns: example | score | v3 band, T0 band | failed checks | warnings v3/v4 | warnings | pair counts | what-ifs fired (a, b, c, X = T1) | T1 band

```
Windows 1|1.000|AA|0|0/0||9:3,1,1,1,1,3||A
Windows 2|0.925|AA|0|0/0||9:3,1,1,1,1,3||A
Windows 3|0.967|AA|0|0/0||9:3,1,1,1,1,3||A
Windows 4|0.900|AA|0|0/0||9:3,1,1,1,1,3||A
Windows 5|0.700|BB|0|0/0||9:1,1,1,1,1,3||B
Windows 6|0.700|BB|0|0/0||9:3,1,1,1,1,3||B
Windows 7|0.100|DD|0|2/2|SCRnew DPnew|9:-,-,-,-,-,-|bX|D
iOS 1|1.000|AA|0|0/0||5:2,1,1,1,1,3||A
iOS 2|0.850|AA|0|0/0||5:2,1,1,1,1,3||A
iOS 3|0.950|AA|0|0/0||5:2,1,1,1,1,3||A
iOS 4|0.850|AA|0|0/0||5:2,1,1,1,1,3||A
iOS 5|0.950|AA|0|0/0||5:1,1,1,1,1,3||A
iOS 6|0.900|AA|0|0/0||5:2,1,1,1,1,3||A
iOS 7|0.150|DD|1|0/0||5:-,-,-,-,-,-|abcX|D
```

**Result: pass.** All 14 scores and bands match the `spec.md` table (Windows 1.00 A / 0.93 A / 0.97 A / 0.90 A / 0.70 B / 0.70 B / 0.10 D;
iOS 1.00 A / 0.85 A / 0.95 A / 0.85 A / 0.95 A / 0.90 A / 0.15 D) under both T0 and T1. T1 fires only where the session is already D
(Windows 7: two desktop warnings, never-seen screen + never-seen device_params; iOS 7: mobile failed check, unchanged).
