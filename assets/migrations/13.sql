CREATE TABLE horse_stats_cache(
  raceId TEXT PRIMARY KEY,
  statsJson TEXT NOT NULL,
  lastUpdatedAt TEXT NOT NULL
);