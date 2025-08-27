CREATE TABLE IF NOT EXISTS race_statistics(
  raceId TEXT PRIMARY KEY,
  raceName TEXT NOT NULL,
  statisticsJson TEXT NOT NULL,
  lastUpdatedAt TEXT NOT NULL
);