-- Blizzard ROW Registration K2: proxy-key check (top JA4 share per day), current ST/LT thresholds (count / ratio) and change in window,
-- di_dictionary_used, volume. vw_events session_setup, 2-11 Nov 2026 (base + replay), one key.
SELECT TO_DATE(timestamp) dy, COUNT(*) n, COUNT(DISTINCT cdn__ja4_hash) n_ja4,
  MAX(c_ja4)/COUNT(*) top_ja4_share_approx,
  LISTAGG(DISTINCT di_dictionary_used, ',') dict_used,
  ROUND(MIN(IFF(di_short_term_count>0,di_short_term_count/NULLIF(di_short_term_threshold_ratio,0),NULL)),1) st_thr_min, ROUND(MAX(IFF(di_short_term_count>0,di_short_term_count/NULLIF(di_short_term_threshold_ratio,0),NULL)),1) st_thr_max,
  ROUND(MIN(IFF(di_long_term_count>0,di_long_term_count/NULLIF(di_long_term_threshold_ratio,0),NULL)),1) lt_thr_min, ROUND(MAX(IFF(di_long_term_count>0,di_long_term_count/NULLIF(di_long_term_threshold_ratio,0),NULL)),1) lt_thr_max
FROM (SELECT e.*, COUNT(*) OVER (PARTITION BY TO_DATE(timestamp), cdn__ja4_hash) c_ja4 FROM ARK_PROD.events.vw_events e
  WHERE public_key='E8A75615-1CBA-5DFF-8032-D16BCF234E10' AND location='session_setup' AND timestamp>='2026-11-02' AND timestamp<'2026-11-12')
GROUP BY 1 ORDER BY 1;
-- As run: thresholds computed only where count > 0. Output: raw/01_blizzard_checks.txt
