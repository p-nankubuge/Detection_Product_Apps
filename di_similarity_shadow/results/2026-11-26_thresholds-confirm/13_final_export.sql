-- {FINAL} for 11_: export fired sessions as shortened IDs grouped by rule bitmask, for scoring labels in Athena (15_).
-- Bits: 1 today ST | 2 today LT | 4 ST m5 f11 | 8 ST m5 f8 | 16 ST m10 f8 | 32 ST m5 f5 | 64 ST m10 f11 | 128 LT m5 f11 | 256 LT m5 f8.
-- ID = first 7 digits + last digit of the 10-digit part after the '.' (the 9th-10th digits are a code 01-05, not random).
-- {VERONLY} = 'AND ver=1' for Blizzard (labels exist only on verified sessions), '' for Figma.
, y AS (SELECT sid, r0+2*r1+4*r3+8*r4+16*r5+32*r6+64*r7+128*r8+256*r9 mask FROM s4 WHERE 1=1 {VERONLY})
SELECT mask, COUNT(*) n, LISTAGG(LEFT(RIGHT(sid,10),7)||RIGHT(sid,1), ',') ids FROM y WHERE mask>0 GROUP BY mask ORDER BY n DESC
