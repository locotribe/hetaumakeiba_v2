CREATE TABLE horse_memos(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  userId TEXT NOT NULL,
  raceId TEXT NOT NULL,
  horseId TEXT NOT NULL,
  predictionMemo TEXT,
  reviewMemo TEXT,
  timestamp TEXT NOT NULL,
  UNIQUE(userId, raceId, horseId) ON CONFLICT REPLACE
);