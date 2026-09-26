// test/ai_race_markdown_builder_test.dart
// [追加] AI分析データエクスポート Step1: buildRaceAiMarkdown の単体テスト（純粋関数・DB不要） (v.2026.9.27+26092701)

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/ai_export/ai_race_markdown_builder.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';

PredictionHorseDetail _horse({
  required int number,
  required String id,
  required String name,
  bool scratched = false,
  String? memo,
  double? odds,
  int? pop,
}) {
  return PredictionHorseDetail(
    horseId: id,
    horseNumber: number,
    gateNumber: number,
    horseName: name,
    sexAndAge: '牡5',
    jockey: 'テスト騎手',
    jockeyId: 'j001',
    carriedWeight: 57.0,
    trainerName: 'テスト調教師',
    trainerAffiliation: '美浦',
    isScratched: scratched,
    odds: odds,
    popularity: pop,
    userMemo: memo == null
        ? null
        : HorseMemo(
            userId: 'u1',
            raceId: 'r1',
            horseId: id,
            predictionMemo: memo,
            timestamp: DateTime(2026, 1, 1),
          ),
  );
}

void main() {
  final race = PredictionRaceData(
    raceId: '202606040911',
    raceName: 'スプリンターズS',
    raceDate: '2026年9月27日',
    venue: '中山',
    raceNumber: '11',
    shutubaTableUrl: 'https://example.com',
    raceGrade: 'G1',
    trackType: '芝',
    distanceValue: 1200,
    direction: '右',
    courseInOut: '外',
    weather: '晴',
    trackCondition: '良',
    horseCount: 2,
    horses: [
      _horse(
          number: 1,
          id: '2019105394',
          name: 'ママコチャ',
          memo: '中山巧者。連覇に期待。',
          odds: 4.5,
          pop: 2),
      _horse(number: 2, id: '2021110099', name: 'ジューンブレア', scratched: true),
    ],
  );

  group('buildRaceAiMarkdown', () {
    test('見出しとraceId・コースを含む', () {
      final md = buildRaceAiMarkdown(race);
      expect(md, contains('# スプリンターズS（G1） AI分析資料'));
      expect(md, contains('raceId: 202606040911'));
      expect(md, contains('コース: 芝1200m 右 外'));
    });

    test('出走馬一覧テーブルと各馬の見出しを含む', () {
      final md = buildRaceAiMarkdown(race);
      expect(md, contains('## 出走馬一覧'));
      expect(md, contains('| 馬番 | 枠 | 馬名'));
      expect(md, contains('### 1 ママコチャ（horseId: 2019105394）'));
      expect(md, contains('### 2 ジューンブレア（horseId: 2021110099）'));
    });

    test('予想メモは記入済み馬に反映され、未記入馬は（未記入）', () {
      final md = buildRaceAiMarkdown(race);
      expect(md, contains('予想メモ: 中山巧者。連覇に期待。'));
      expect(md, contains('（未記入）'));
    });

    test('スクラッチ馬は取消表示', () {
      final md = buildRaceAiMarkdown(race);
      expect(md, contains('**出走取消**'));
      expect(md, contains('| 2 | 2 | ジューンブレア |'));
    });

    test('null項目は - で表示される', () {
      final md = buildRaceAiMarkdown(race);
      expect(md, contains('単勝/人気: - / -'));
    });
  });
}
