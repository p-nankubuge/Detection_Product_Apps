# Follow-up: were rule hits already challenged? Are N9 hits company proxies?

- **Key:** Figma Registration K2, sessions created October 2026 (3,076,846), no sampling
- **Queries:** `followup_already_challenged.sql`
- **Run in the main session** after reviewing the agent's results, because the agent's verdicts leaned on the TD sample alone.

## 1. Rule hits vs the key's normal traffic

| Group | Sessions | Challenged | Challenged, not solved | Of challenged, didn't solve | No verify | High risk |
|---|---:|---:|---:|---:|---:|---:|
| All sessions | 3,076,846 | 31.0% | 12.2% | 39% | 12.8% | 6.91% |
| Dict 63 | 1,704,733 | 25.8% | 8.9% | 34% | 9.4% | 4.68% |
| C2 | 18,887 | 22.3% | 8.1% | 36% | 8.9% | 4.74% |
| C3 | 7,353 | 31.6% | 12.6% | 40% | 13.7% | 4.39% |
| N9 | 62,128 | 28.2% | 15.9% | **56%** | 16.6% | 5.12% |
| N10 | 28,949 | 37.0% | 16.5% | 45% | 17.4% | 8.59% |
| N11 | 7,738 | 32.0% | 12.5% | 39% | 13.5% | 4.67% |

- TD Nonlegit labels only exist on sessions we let through, so low TD uplift doesn't mean a rule is wrong.
- N10 is already challenged more than normal; C2 less; C3, N9, N11 about normal.
- When N9 sessions are challenged, 56% don't solve (vs 39% normal): a real share of N9 traffic can't or won't pass a challenge. Together with the 78 Legit labels, N9 looks **mixed**, not "reject".

## 2. N9 hits by IP tag (15 Oct, simplified N9)

| IP tag | N9 hits | Share of N9 hits | Share of all sessions | N9 rate within tag |
|---|---:|---:|---:|---:|
| cloud-security | 1,624 | 57.6% | 3.8% | 37.0% |
| (untagged) | 1,046 | 37.1% | 92.2% | 1.0% |
| dns | 92 | 3.3% | 0.1% | 54.1% |
| cloud | 44 | 1.6% | 1.4% | 2.7% |
| others | 15 | 0.5% | | |

- 58% of N9 hits are from cloud-security IPs (15× their traffic share). That **fits** company TLS inspection, but an IP tag shows who owns the IP, not who is behind it.
- 37% of N9 hits are from ordinary IPs; the proxy explanation doesn't cover these.

## Corrections to the run-2 summary

- "Mostly corporate TLS-inspection proxies" was stated as fact; it is a likely explanation for ~58% of N9 hits, not proven.
- N9 "reject" rested on the TD sample alone; the challenge outcome above points to a mixed rule.
- The N10 baseline did not follow the intended design (1 day, 99.9% cut-off, min 50 sessions, impossible-combo sessions not removed first). N10 results need re-running.

## Next

- Split N9 / C2 / C3 / N11 by cloud-security vs other IPs; compare challenge outcome and TD labels per half.
- Re-run N10 with the corrected baseline.
