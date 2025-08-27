DROP TABLE IF EXISTS analytics_summaries;
DROP TABLE IF EXISTS category_summary_cache;
CREATE TABLE analytics_aggregates(
  aggregate_key TEXT PRIMARY KEY,
  total_investment INTEGER NOT NULL DEFAULT 0,
  total_payout INTEGER NOT NULL DEFAULT 0,
  hit_count INTEGER NOT NULL DEFAULT 0,
  bet_count INTEGER NOT NULL DEFAULT 0
);