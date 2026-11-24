# Run 1 notes (no agents)

## What I asked

1. Figma Registration K2, 20 Nov 12:00–14:00 UTC: sessions and verify rate by DI dictionary.
2. Same query for 19 Nov, to check the window is typical.
3. Dict 1 and Dict 3 broken down by OS and top-5 JA4, compared with Dict 63.

## What happened

- Checked that `vw_events.timestamp` is UTC before querying (latest event vs `SYSDATE()`: 0 min apart).
- Split is stable across both days (shares within ~1.3 points). ~55% Dict 63.
- ~99% of sessions that reach a challenge pass it at every dictionary, so "verified" doesn't separate good from bad on this key.
- Dict 1 = JA4s never seen on real devices, several non-browser-looking. Dict 3 = normal JA4s; the mismatch is elsewhere. macOS is ~2× over-represented at Dict 3.
- One query failed (window function inside an aggregate); fixed by simplifying.

## What I'd change

- Report verify rate both ways from the start ("of all sessions" vs "of those challenged").
- Always include a baseline column (Dict 63) when breaking a dictionary down.
- Next: find which field drops macOS sessions to Dict 3; join Figma truth data (Athena) to test the readings.
