# Run 1 notes (no agents)

## What we looked at

- Figma Registration K2 (`A207F8A1-ED09-4325-ACE6-C8E26A458FBA`), 12:00–14:00 UTC on 20 Nov 2026, with 19 Nov as a comparison.
- Sessions and verify rate by today's DI dictionary (-1 to 63).
- Dict 1 and Dict 3 broken down by OS and top-5 JA4, compared with Dict 63 (known real devices).

## What we found

- The split is stable across both days: ~55% of sessions are Dict 63, and shares moved by at most ~1.3 points.
- ~99% of sessions that reach a challenge pass it at every dictionary, so "verified" doesn't separate good from bad on this key.
- Dict 1 is mostly JA4s never seen at Dict 63, several of them non-browser-looking (HTTP/1.1 only, TLS 1.2, no ALPN).
- Dict 3 has ordinary Chrome/Safari JA4s, so its mismatch is in another field. macOS is ~2× its normal share there (185 sessions).

## Questions I still have

1. Which field drops the macOS sessions to Dict 3: OS version, browser version, screen size or WebGL?
2. Are the Dict 1 sessions with non-browser JA4s actually bad? Figma's truth data should say.
3. Why do ~10% of low-dictionary sessions never reach the final verify step: abandoned, not challenged, or something else?
   **Answered** in `figma_k2_no_verify.md`: 85% were challenged and abandoned; low dictionaries are challenged more often. TD can't see these sessions.
