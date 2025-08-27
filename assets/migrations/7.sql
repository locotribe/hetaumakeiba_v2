ALTER TABLE qr_data ADD COLUMN userId TEXT NOT NULL DEFAULT '';
ALTER TABLE user_feeds ADD COLUMN userId TEXT NOT NULL DEFAULT '';
ALTER TABLE analytics_aggregates RENAME TO analytics_aggregates_old;
CREATE TABLE analytics_aggregates(
  aggregate_key TEXT NOT NULL,
  userId TEXT NOT NULL,
  total_investment INTEGER NOT NULL DEFAULT 0,
  total_payout INTEGER NOT NULL DEFAULT 0,
  hit_count INTEGER NOT NULL DEFAULT 0,
  bet_count INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (aggregate_key, userId)
);
INSERT INTO analytics_aggregates (aggregate_key, userId, total_investment, total_payout, hit_count, bet_count)
SELECT aggregate_key, '', total_investment, total_payout, hit_count, bet_count FROM analytics_aggregates_old;
DROP TABLE analytics_aggregates_old;
ALTER TABLE user_marks RENAME TO user_marks_old;
CREATE TABLE user_marks(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  userId TEXT NOT NULL,
  raceId TEXT NOT NULL,
  horseId TEXT NOT NULL,
  mark TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  UNIQUE(userId, raceId, horseId) ON CONFLICT REPLACE
);
INSERT INTO user_marks (id, userId, raceId, horseId, mark, timestamp)
SELECT id, '', raceId, horseId, mark, timestamp FROM user_marks_old;
DROP TABLE user_marks_old;