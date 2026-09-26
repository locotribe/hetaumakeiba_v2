// test/ai_race_full_markdown_builder_test.dart
// [追加] AI分析データエクスポート Step3: buildRaceFullAiMarkdown の単体テスト（純粋関数・DB不要） (v.2026.9.27+26092703)

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/ai_export/ai_race_full_markdown_builder.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/ai_export/ai_race_export_bundle.dart';
import 'package:hetaumakeiba_v2/models/horse_speed_index_model.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';

PredictionRaceData _race() => PredictionRaceData(
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
      horseCount: 1,
      horses: [
        PredictionHorseDetail(
          horseId: 'h1',
          horseNumber: 1,
          gateNumber: 1,
          horseName: 'テスト馬',
          sexAndAge: '牡5',
          jockey: 'テスト騎手',
          jockeyId: 'j1',
          carriedWeight: 57.0,
          trainerName: 'テスト師',
          trainerAffiliation: '美浦',
          isScratched: false,
        ),
      ],
    );

AiRaceExportBundle _bundle() => AiRaceExportBundle(
      raceId: '202606040911',
      raceName: 'スプリンターズS',
      raceDate: '2026年9月27日',
      horses: [
        AiHorseData(
          horseId: 'h1',
          performance: const [],
          extrasByRaceId: const {},
          trainingSessions: const [],
          trainingReview: null,
          profile: null,
          speedIndex: HorseSpeedIndex(
            horseId: 'h1',
            bestIndex: 88.0,
            recentAvgIndex: 85.0,
            trend: 1.0,
            confidence: 0.8,
            sampleCount: 6,
            calculatedAt: '2026-09-27T00:00:00.000',
          ),
          simulationParams: null,
          trainingTimes: const [],
        ),
      ],
      raceStatistics: RaceStatistics(
        raceId: '202606040911',
        raceName: 'スプリンターズS',
        statisticsJson:
            '{"analyzedYears":["2025","2024"],"frameStats":{"1":{"total":10,"win":1,"place":2,"show":3},"8":{"total":10,"win":3,"place":5,"show":6}},"legStyleStats":{"逃げ":{"total":8,"win":2,"place":3,"show":4}},"avgWinningHorseWeight":486.0}',
        lastUpdatedAt: DateTime(2026, 9, 27),
      ),
      trackCondition: TrackConditionRecord(
        trackConditionId: 1,
        date: '2026-09-27',
        weekDay: 'su',
        cushionValue: 9.5,
      ),
      raceMemoText: '重い馬場想定',
    );

void main() {
  group('buildRaceFullAiMarkdown', () {
    test('標準: 概要・馬場詳細・スピード指数・メモを含み、統計JSONは埋め込まない', () {
      final md = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: _bundle(), grain: AiExportGrain.standard);
      expect(md, contains('AI分析資料（標準）'));
      expect(md, contains('raceId: 202606040911'));
      expect(md, contains('クッション値 9.5'));
      expect(md, contains('スピード指数: ベスト 88'));
      expect(md, contains('レースメモ: 重い馬場想定'));
      expect(md, contains('過去10年統計: 登録あり'));
      expect(md, contains('（過去成績データなし）'));
      expect(md, contains('## 過去10年傾向（縦の比較）'));
    });

    test('全部: 統計JSONを埋め込む', () {
      final md = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: _bundle(), grain: AiExportGrain.full);
      expect(md, contains('AI分析資料（全部）'));
      expect(md, contains('## 過去10年傾向（縦の比較）'));
      expect(md, contains('**枠番別**'));
      expect(md, contains('勝ち馬の平均馬体重: 486kg'));
    });

    test('要約: 見出しと各馬詳細を含む', () {
      final md = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: _bundle(), grain: AiExportGrain.summary);
      expect(md, contains('AI分析資料（要約）'));
      expect(md, contains('### 1 テスト馬（horseId: h1）'));
    });

    test('フロントマター(依頼ブロック)を先頭に含む', () {
      final md = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: _bundle(), grain: AiExportGrain.standard);
      expect(md, contains('# この資料の使い方（AIへの依頼）'));
      expect(md, contains('raceId,horseId,horseNumber,horseName,predictionMemo'));
      expect(
          md.indexOf('# この資料の使い方（AIへの依頼）') <
              md.indexOf('AI分析資料（標準）'),
          isTrue);
    });

    test('馬柱に過去走の馬体重・騎手・頭数の列が出る', () {
      final rec = HorseRaceRecord(
        horseId: 'h1',
        raceId: 'pr1',
        date: '2026/06/01',
        venue: '2中山3',
        weather: '晴',
        raceNumber: '11',
        raceName: 'テスト重賞(GII)',
        numberOfHorses: '16',
        frameNumber: '3',
        horseNumber: '5',
        odds: '4.5',
        popularity: '2',
        rank: '1',
        jockey: '武豊',
        jockeyId: 'j1',
        carriedWeight: '57',
        distance: '芝1200',
        trackCondition: '良',
        time: '1:08.0',
        margin: '0.0',
        cornerPassage: '3-3',
        pace: '33.0-34.0',
        agari: '33.5',
        horseWeight: '502(+4)',
        winnerOrSecondHorse: 'テスト2着馬',
        prizeMoney: '5000',
      );
      final bundle = AiRaceExportBundle(
        raceId: 'r1',
        raceName: 'テスト',
        raceDate: '2026年9月27日',
        horses: [
          AiHorseData(
            horseId: 'h1',
            performance: [rec],
            extrasByRaceId: const {},
            trainingSessions: const [],
            trainingReview: null,
            profile: null,
            speedIndex: null,
            simulationParams: null,
            trainingTimes: const [],
          ),
        ],
        raceStatistics: null,
        trackCondition: null,
        raceMemoText: null,
      );
      final md = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: bundle, grain: AiExportGrain.standard);
      expect(
          md,
          contains(
              '| 日付 | レース | 距離馬場 | 頭数 | 枠馬番 | 人気着 | 馬体重 | 騎手 |'));
      expect(md, contains('502(+4)'));
      expect(md, contains('武豊'));
    });
  });
}
