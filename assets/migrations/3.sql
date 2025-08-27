CREATE TABLE IF NOT EXISTS analytics_summaries(
  period TEXT PRIMARY KEY,
  totalInvestment INTEGER,
  totalPayout INTEGER,
  hitCount INTEGER,
  betCount INTEGER,
  lastCalculated TEXT
);