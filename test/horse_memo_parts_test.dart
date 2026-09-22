// test/horse_memo_parts_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/widgets/memo/horse_memo_parts.dart';

// [追加] 馬詳細タブStep2: 過去メモの対象の選び方と表示用データ（移す前のメモタブと同じ結果か） (v.2026.9.23+26092307)

HorseRaceRecord _race(String raceId, String date,
    {String raceName = '', String rank = ''}) {
  return HorseRaceRecord(
    horseId: 'h1',
    raceId: raceId,
    date: date,
    venue: '',
    weather: '',
    raceNumber: '',
    raceName: raceName,
    numberOfHorses: '',
    frameNumber: '',
    horseNumber: '',
    odds: '',
    popularity: '',
    rank: rank,
    jockey: '',
    jockeyId: '',
    carriedWeight: '',
    distance: '',
    trackCondition: '',
    time: '',
    margin: '',
    cornerPassage: '',
    pace: '',
    agari: '',
    horseWeight: '',
    winnerOrSecondHorse: '',
    prizeMoney: '',
  );
}

HorseMemo _memo(String raceId, {String? prediction, String? review}) {
  return HorseMemo(
    userId: 'u1',
    raceId: raceId,
    horseId: 'h1',
    predictionMemo: prediction,
    reviewMemo: review,
    timestamp: DateTime(2026, 9, 23),
  );
}

void main() {
  group('selectPastMemoTargetRecords', () {
    test('今回のレースとレースIDが空の走を除き、直近5走まで', () {
      final records = [
        _race('now', '2026/09/27'),
        _race('', '2026/09/01'),
        _race('r1', '2026/08/01'),
        _race('r2', '2026/07/01'),
        _race('r3', '2026/06/01'),
        _race('r4', '2026/05/01'),
        _race('r5', '2026/04/01'),
        _race('r6', '2026/03/01'),
      ];
      final targets = selectPastMemoTargetRecords(records, 'now');
      expect(targets.map((r) => r.raceId).toList(), ['r1', 'r2', 'r3', 'r4', 'r5']);
    });
  });

  group('buildPastMemoDetails', () {
    test('メモがある走だけ・日付は2桁年・着順の表記', () {
      final targets = [
        _race('r1', '2026/05/31', raceName: '東京優駿', rank: '1'),
        _race('r2', '2026/04/19', raceName: '皐月賞', rank: '取消'),
        _race('r3', '2026/03/01', raceName: '弥生賞', rank: ''),
        _race('r4', '2026/02/15', raceName: '共同通信杯', rank: '2'),
        _race('r5', '2026/01/10', raceName: '未勝利', rank: '3'),
      ];
      final memos = {
        'r1': _memo('r1', prediction: '本命'),
        'r2': _memo('r2', review: '出遅れ'),
        'r3': _memo('r3', prediction: '穴'),
        'r4': _memo('r4', prediction: '', review: ''),
      };
      final details = buildPastMemoDetails(targets, memos);
      expect(details.length, 3);
      expect(details[0].date, '26/05/31');
      expect(details[0].raceName, '東京優駿');
      expect(details[0].rank, '1着');
      expect(details[0].predictionMemo, '本命');
      expect(details[0].reviewMemo, '');
      expect(details[1].rank, '取消');
      expect(details[1].reviewMemo, '出遅れ');
      expect(details[2].rank, '他');
    });

    test('年月日表記とハイフン表記も2桁年のスラッシュ区切りにする', () {
      final targets = [
        _race('r1', '2025年7月19日', rank: '5'),
        _race('r2', '2025-06-01', rank: '4'),
      ];
      final memos = {
        'r1': _memo('r1', prediction: 'a'),
        'r2': _memo('r2', prediction: 'b'),
      };
      final details = buildPastMemoDetails(targets, memos);
      expect(details[0].date, '25/7/19');
      expect(details[1].date, '25/06/01');
    });
  });
}
