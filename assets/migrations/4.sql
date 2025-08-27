CREATE TABLE IF NOT EXISTS category_summary_cache(
  cacheKey TEXT PRIMARY KEY,
  summaryJson TEXT NOT NULL,
  lastCalculated TEXT NOT NULL
);