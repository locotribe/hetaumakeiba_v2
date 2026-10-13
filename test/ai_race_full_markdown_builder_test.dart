// test/ai_race_full_markdown_builder_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:hetaumakeiba_v2/logic/ai_export/ai_race_full_markdown_builder.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/ai_export/ai_race_export_bundle.dart';
import 'package:hetaumakeiba_v2/models/horse_speed_index_model.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/db/elevations/tokyo/tokyo_course.dart';
import 'package:hetaumakeiba_v2/logic/ai_export/ai_course_profile.dart';
import 'package:hetaumakeiba_v2/logic/ai_export/ai_weather_snapshot.dart';
import 'package:hetaumakeiba_v2/models/course_preset_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/leg_style_analyzer.dart';

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
    // [修正] AI分析データ 文章・ラベル除外: レースメモ・予想メモは出さない (v.2026.10.12+26101201)
    test('標準: 概要・馬場詳細・スピード指数を含み、メモは出さず、統計JSONは埋め込まない', () {
      final md = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: _bundle(), grain: AiExportGrain.standard);
      expect(md, contains('AI分析資料（標準）'));
      expect(md, contains('raceId: 202606040911'));
      expect(md, contains('クッション値 9.5'));
      expect(md, contains('スピード指数: ベスト 88'));
      expect(md, isNot(contains('レースメモ')));
      expect(md, isNot(contains('重い馬場想定')));
      expect(md, isNot(contains('- 予想メモ:')));
      expect(md, contains('過去10年統計: 登録あり'));
      expect(md, contains('（過去成績データなし）'));
      // [修正] AI分析データ 過去データ分離 Step2: 過去10年傾向（集計表）は出さない (v.2026.10.14+26101402)
      expect(md, isNot(contains('## 過去10年傾向（縦の比較）')));
    });

    // [修正] AI分析データ 過去データ分離 Step2: 全部でも過去10年傾向（集計表）は出さない。統計の登録の有無は概要に残す (v.2026.10.14+26101402)
    test('全部: 過去10年傾向（集計表）は出さない', () {
      final md = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: _bundle(), grain: AiExportGrain.full);
      expect(md, contains('AI分析資料（全部）'));
      expect(md, contains('過去10年統計: 登録あり'));
      expect(md, isNot(contains('## 過去10年傾向（縦の比較）')));
      expect(md, isNot(contains('**枠番別**')));
      expect(md, isNot(contains('勝ち馬の平均馬体重')));
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
      expect(md, contains('AI総評テキスト'));
      expect(md, contains('レース情報タブ'));
      expect(
          md.indexOf('# この資料の使い方（AIへの依頼）') <
              md.indexOf('AI分析資料（標準）'),
          isTrue);
    });

    // [追加] AIファイル名整理: 依頼文の保存ファイル名がインポート用の .txt になっている (v.2026.10.10+26101006)
    test('依頼ブロックの保存ファイル名がインポート用の .txt になっている', () {
      final md = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: _bundle(), grain: AiExportGrain.standard);
      expect(md, contains('インポート総評_(レース名)_(日付)_(raceId).txt'));
      expect(md, contains('インポート予想メモ_(レース名)_(日付)_(raceId).txt'));
      expect(md, isNot(contains('```csv')));
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

    test('馬柱の距離馬場に過去走の馬場(クッション値)が付記される', () {
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
      final tc = TrackConditionRecord(
        trackConditionId: 1,
        date: '2026-06-01',
        weekDay: 'sa',
        cushionValue: 9.2,
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
            pastTrackByRaceId: {'pr1': tc},
          ),
        ],
        raceStatistics: null,
        trackCondition: null,
        raceMemoText: null,
      );
      final md = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: bundle, grain: AiExportGrain.standard);
      expect(md, contains('芝1200良(ク9.20)'));
    });

    // [追加] AI分析データ 天気・コース追加 Step4: 総合スコア・期待値の削除、賞金、馬場詳細の補完、コース・馬場推移・天気の節 (v.2026.10.11+26101104)
    // [修正] AI分析データ 文章・ラベル除外: 馬場適性のラベル（アプリ評価）も出さない (v.2026.10.12+26101201)
    test('総合スコア・期待値・馬場適性のラベルを出さない', () {
      final md = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: _bundle(), grain: AiExportGrain.standard);
      expect(md, isNot(contains('総合スコア')));
      expect(md, isNot(contains('期待値')));
      expect(md, isNot(contains('アプリ評価')));
      expect(
          md,
          contains(
              '| 馬番 | 枠 | 馬名 | 性齢 | 騎手(斤量) | 単勝 | 人気 | 馬体重 | 出否 |'));
    });

    test('馬柱に賞金列、各馬に通算獲得賞金が出る', () {
      HorseRaceRecord rec(String raceId, String prizeMoney) => HorseRaceRecord(
            horseId: 'h1',
            raceId: raceId,
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
            prizeMoney: prizeMoney,
          );
      final bundle = AiRaceExportBundle(
        raceId: 'r1',
        raceName: 'テスト',
        raceDate: '2026年9月27日',
        horses: [
          AiHorseData(
            horseId: 'h1',
            performance: [rec('pr1', '5000'), rec('pr2', '')],
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
      expect(md, contains('| 指数/馬場 | 賞金(万円) |'));
      expect(md, contains('| 5,000.0 |'));
      expect(md, contains('- 通算獲得賞金: 5,000.0万円（賞金のある1走／成績2件）'));
    });

    test('当日の測定が無ければ、その競馬場の最新の測定を馬場詳細に出す', () {
      final bundle = AiRaceExportBundle(
        raceId: 'r1',
        raceName: 'テスト',
        raceDate: '2026年9月27日',
        horses: const [],
        raceStatistics: null,
        trackCondition: null,
        raceMemoText: null,
        latestVenueTrackCondition: TrackConditionRecord(
          trackConditionId: 202606040401,
          date: '2026-09-26',
          weekDay: 'sa',
          cushionValue: 9.6,
          moistureTurfGoal: 13.3,
        ),
      );
      final md = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: bundle, grain: AiExportGrain.standard);
      expect(md, contains('- 馬場詳細（当日の測定なし・最新測定 2026-09-26）: クッション値 9.6'));
    });

    test('コース情報: 区間表は全粒度、100mごとの標高は標準以上', () {
      final profile = buildAiCourseProfile(TokyoCourse.shiba1800);
      final preset = CoursePreset(
        id: '05_shiba_1800',
        venueCode: '05',
        venueName: '東京',
        distance: '芝1800',
        direction: '左回り',
        straightLength: 526,
        courseLayout: 'テストのレイアウト',
        keyPoints: 'テストのポイント',
      );
      final bundle = AiRaceExportBundle(
        raceId: 'r1',
        raceName: 'テスト',
        raceDate: '2026年9月27日',
        horses: const [],
        raceStatistics: null,
        trackCondition: null,
        raceMemoText: null,
        courseProfile: profile,
        coursePreset: preset,
      );
      final standard = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: bundle, grain: AiExportGrain.standard);
      final summary = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: bundle, grain: AiExportGrain.summary);
      expect(standard, contains('## コース情報'));
      expect(standard, contains('/ 左回り / 1周 2083.1m'));
      expect(standard, contains('- ゴール前直線（プリセット）: 526m'));
      // [修正] AI分析データ 文章・ラベル除外: プリセットの解説文は出さない (v.2026.10.12+26101201)
      expect(standard, isNot(contains('コースの特徴')));
      expect(standard, isNot(contains('テストのレイアウト')));
      expect(standard, isNot(contains('テストのポイント')));
      expect(standard, contains('| ゴール前直線 | 1274.1〜1800m | 525.9m |'));
      expect(standard, contains('**100mごとの標高**'));
      expect(standard, contains('| 1800m | 0m | 0.00 |'));
      expect(summary, contains('| ゴール前直線 | 1274.1〜1800m | 525.9m |'));
      expect(summary, isNot(contains('**100mごとの標高**')));
    });

    test('開催中の馬場推移: 古い順・当日の印・前回との差、要約は直近3件', () {
      TrackConditionRecord r(int id, String date, String weekDay,
              double cushion, double turfGoal) =>
          TrackConditionRecord(
            trackConditionId: id,
            date: date,
            weekDay: weekDay,
            cushionValue: cushion,
            moistureTurfGoal: turfGoal,
          );
      final bundle = AiRaceExportBundle(
        raceId: 'r1',
        raceName: 'テスト',
        raceDate: '2026年9月27日',
        horses: const [],
        raceStatistics: null,
        trackCondition: null,
        raceMemoText: null,
        meetingTrackHistory: [
          r(202606040101, '2026-09-12', 'sa', 10.1, 12.0),
          r(202606040201, '2026-09-13', 'su', 9.9, 12.4),
          r(202606040401, '2026-09-26', 'sa', 9.7, 13.0),
          r(202606040501, '2026-09-27', 'su', 9.5, 13.4),
        ],
      );
      final standard = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: bundle, grain: AiExportGrain.standard);
      final summary = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: bundle, grain: AiExportGrain.summary);
      expect(standard, contains('## 開催中の馬場推移（JRA発表・同じ開催）'));
      expect(standard, contains('| 2026-09-12(土) | 10.1（やや硬め） | 12.0/- | -/- |'));
      expect(standard, contains('| 2026-09-27(日)（レース当日） | 9.5（標準） |'));
      expect(
          standard,
          contains(
              '- 最新(2026-09-27)と前回(2026-09-26)の差: クッション値 -0.2、芝含水率(G) +0.4%'));
      expect(summary, isNot(contains('2026-09-12')));
      expect(summary, contains('| 2026-09-13(日) |'));
    });

    test('天気: 取れないときは理由を出す', () {
      final bundle = AiRaceExportBundle(
        raceId: 'r1',
        raceName: 'テスト',
        raceDate: '2026年9月27日',
        horses: const [],
        raceStatistics: null,
        trackCondition: null,
        raceMemoText: null,
        weatherUnavailableReason: '未取得（レース情報タブの🔄で取得）',
      );
      final md = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: bundle, grain: AiExportGrain.standard);
      expect(md, contains('- 天気: 未取得（レース情報タブの🔄で取得）'));
    });

    // [修正] AI分析データ 文章・ラベル除外: 直線の風・インサイトは出さず、根拠は馬場予測の直後（全部だけ） (v.2026.10.12+26101201)
    test('天気: 予報と馬場予測。直線の風・インサイトは出さず、根拠は全部だけ', () {
      final snapshot = buildAiWeatherSnapshot(
        pinpoint: {
          'current': {'time': '10/10 12:15'},
          'raceTime': {
            'temp': 25.5,
            'humidity': 51,
            'pop': 0,
            'precipitation': 0.0,
            'windSpeed': 5.4,
            'weatherCode': 0,
            'apparentTemp': 26.2,
            'radiation': 453.0,
            'evap': 0.3,
            'gusts': 28.8,
            'visibility': 24.1,
            'soilMoisture': 0.258,
          },
          'timeline': [
            {'time': '15:00', 'temp': 25.5, 'pop': 0, 'precipitation': 0.0, 'windSpeed': 5.4, 'weatherCode': 0},
          ],
          'daily': [
            {'date': '2026-10-11', 'weatherCode': 0, 'tempMax': 25.6, 'tempMin': 16.0, 'precipitationSum': 0.0},
          ],
          'windAnalysis': '💨 直線は【追い風】の傾向（逃げ・先行馬が止まりにくい）',
          'windDirText': '北東',
        },
        baseline: TrackConditionRecord(
          trackConditionId: 202605040201,
          date: '2026-10-10',
          weekDay: 'sa',
          cushionValue: 9.6,
          moistureTurfGoal: 13.3,
        ),
        venueCode: '05',
        trackType: '芝',
        raceDate: '2026年10月11日',
      )!;
      final bundle = AiRaceExportBundle(
        raceId: 'r1',
        raceName: 'テスト',
        raceDate: '2026年9月27日',
        horses: const [],
        raceStatistics: null,
        trackCondition: null,
        raceMemoText: null,
        weatherSnapshot: snapshot,
      );
      final summary = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: bundle, grain: AiExportGrain.summary);
      final standard = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: bundle, grain: AiExportGrain.standard);
      final full = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: bundle, grain: AiExportGrain.full);

      expect(summary, contains('- 取得時刻: 10/10 12:15'));
      expect(summary, contains('風 北東 1.5m/s（5.4km/h）'));
      expect(summary, contains('| 15:00 | 晴れ | 25.5℃ | 0% | 0.0mm | 1.5m/s |'));
      expect(
          summary,
          contains(
              '- 馬場予測: JRA基準で 良 / 予測含水率 11.6%（芝） / 予測クッション値 9.6（起点: 2026-10-10 の測定）'));
      expect(summary, isNot(contains('- インサイト')));
      expect(summary, isNot(contains('- 予測含水率の根拠')));

      expect(standard, isNot(contains('直線の風')));
      expect(standard, isNot(contains('【追い風】')));
      expect(standard, isNot(contains('- インサイト')));
      expect(standard, isNot(contains('乾いた良')));
      expect(standard, contains('**開催週の日別（予報・実績）**'));
      expect(standard, isNot(contains('- 予測含水率の根拠')));

      expect(full, isNot(contains('直線の風')));
      expect(full, isNot(contains('- インサイト')));
      expect(full, isNot(contains('実力通りの決着')));
      expect(full, isNot(contains('  - 根拠:')));
      expect(
          full,
          contains(
              '- 予測含水率の根拠: 【予測シミュレーションの根拠】 / ・起点 (今回公式): 13.3% / ・当日加水 (降水予報 0.0mm): +0.0%'));
      expect(full.indexOf('- 馬場予測:') < full.indexOf('- 予測含水率の根拠:'),
          isTrue);
      expect(
          full.indexOf('- 予測含水率の根拠:') <
              full.indexOf('**開催週の日別（予報・実績）**'),
          isTrue);
    });

    // [追加] AI分析データ 文章・ラベル除外: 脚質の内訳（脚質詳細ダイアログと同じ数値）を出す (v.2026.10.12+26101201)
    test('脚質の内訳: 4脚質の割合・着度数・勝率、マクリは回数で別記', () {
      final race = _race();
      race.horses.first.legStyleProfile = LegStyleProfile(
        primaryStyle: '先行',
        styleDistribution: {'逃げ': 0.2, '先行': 0.6, '差し': 0.2, '追込': 0.0},
        styleWinRates: {'逃げ': 1.0, '先行': 1 / 3, '差し': 0.0, 'マクリ': 0.0},
        styleRecordCounts: {
          '逃げ': [1, 0, 0, 0],
          '先行': [1, 1, 0, 1],
          '差し': [0, 0, 0, 1],
          '追込': [0, 0, 0, 0],
          'マクリ': [0, 1, 0, 1],
        },
      );
      final md = buildRaceFullAiMarkdown(
          raceData: race, bundle: _bundle(), grain: AiExportGrain.summary);
      expect(
          md,
          contains(
              '- 脚質の内訳: 逃げ 20.0%（1-0-0-0, 勝率100.0%） / 先行 60.0%（1-1-0-1, 勝率33.3%） / 差し 20.0%（0-0-0-1, 勝率0.0%） / 追込 0.0%（0-0-0-0, 勝率0.0%）（マクリ 2回: 0-1-0-1, 勝率0.0%）'));
      expect(md, contains('- 脚質の内訳: 過去走の脚質ごとの割合'));
    });

    test('脚質の内訳: 着度数の無い古い保存は割合だけ、脚質データが無ければ行を出さない', () {
      final race = _race();
      race.horses.first.legStyleProfile = LegStyleProfile(
        primaryStyle: '逃げ',
        styleDistribution: {'逃げ': 0.5, '先行': 0.5},
      );
      final md = buildRaceFullAiMarkdown(
          raceData: race, bundle: _bundle(), grain: AiExportGrain.standard);
      expect(
          md,
          contains(
              '- 脚質の内訳: 逃げ 50.0% / 先行 50.0% / 差し 0.0% / 追込 0.0%（着度数・勝率は未計算）'));
      expect(md, isNot(contains('マクリ 0回')));

      final none = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: _bundle(), grain: AiExportGrain.standard);
      expect(none, isNot(contains('- 脚質の内訳: 逃げ')));
    });

    // [追加] 過去レースの印・メモ Step2: 各馬の過去走の印・メモと、過去レースのAI予想・レース総評 (v.2026.10.12+26101204)
    HorseRaceRecord pastRec(String raceId, String date, String raceName) =>
        HorseRaceRecord(
          horseId: 'h1',
          raceId: raceId,
          date: date,
          venue: '2中山3',
          weather: '晴',
          raceNumber: '11',
          raceName: raceName,
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

    AiRaceExportBundle pastBundle({
      Map<String, AiPastRaceNote> notes = const {},
      Map<String, AiPastRaceMemo> raceMemos = const {},
    }) =>
        AiRaceExportBundle(
          raceId: '202606040911',
          raceName: 'スプリンターズS',
          raceDate: '2026年9月27日',
          horses: [
            AiHorseData(
              horseId: 'h1',
              performance: [
                pastRec('202606040911', '2026/09/27', 'スプリンターズS(GI)'),
                pastRec('p1', '2026/06/01', 'テスト重賞(GII)'),
                pastRec('p2', '2026/05/01', '過去レース2'),
                pastRec('p3', '2026/04/01', '過去レース3'),
                pastRec('p4', '2026/03/01', '過去レース4'),
                pastRec('p5', '2026/02/01', '過去レース5'),
              ],
              extrasByRaceId: const {},
              trainingSessions: const [],
              trainingReview: null,
              profile: null,
              speedIndex: null,
              simulationParams: null,
              trainingTimes: const [],
              pastNotesByRaceId: notes,
            ),
          ],
          raceStatistics: null,
          trackCondition: null,
          raceMemoText: null,
          pastRaceMemos: raceMemos,
        );

    test('過去走の印・メモ: 馬柱の直後に出し、馬柱の範囲外は出さない', () {
      final bundle = pastBundle(notes: {
        'p1': const AiPastRaceNote(
            mark: '◎', predictionMemo: '先行有利\n内枠', reviewMemo: '完勝'),
        'p5': const AiPastRaceNote(reviewMemo: '出遅れ'),
      });
      final summary = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: bundle, grain: AiExportGrain.summary);
      final standard = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: bundle, grain: AiExportGrain.standard);
      expect(summary, contains('#### 過去走の印・メモ（そのレースで付けたもの）'));
      expect(
          summary,
          contains(
              '- 2026/06/01 テスト重賞(GII) 2人気1着: 印 ◎ / 予想メモ: 先行有利 内枠 / 回顧メモ: 完勝'));
      expect(summary, isNot(contains('出遅れ')));
      expect(standard, contains('- 2026/02/01 過去レース5 2人気1着: 回顧メモ: 出遅れ'));
      expect(
          standard.indexOf('#### 馬柱（過去成績）') <
              standard.indexOf('#### 過去走の印・メモ（そのレースで付けたもの）'),
          isTrue);
      expect(
          standard.indexOf('#### 過去走の印・メモ（そのレースで付けたもの）') <
              standard.indexOf('#### 調教'),
          isTrue);
    });

    test('過去走の印・メモ: 無ければ節を出さない', () {
      final md = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: pastBundle(), grain: AiExportGrain.full);
      expect(md, isNot(contains('#### 過去走の印・メモ')));
      expect(md, isNot(contains('## 過去レースのAI予想・レース総評')));
    });

    test('過去レースのAI予想・レース総評: 標準以上で全文を「> 」付きで出し、今回のレースと範囲外は出さない', () {
      final bundle = pastBundle(raceMemos: {
        '202606040911': const AiPastRaceMemo(aiPrediction: '今回のAI予想'),
        'p1': const AiPastRaceMemo(
            aiPrediction: '【レース総論】スロー\n\n【買い目】単勝1番',
            review: '内が止まらない'),
        'p2': const AiPastRaceMemo(review: '外差し決着'),
        'p9': const AiPastRaceMemo(aiPrediction: '出ていないレース'),
      });
      final standard = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: bundle, grain: AiExportGrain.standard);
      final summary = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: bundle, grain: AiExportGrain.summary);

      expect(standard,
          contains('## 過去レースのAI予想・レース総評（過去のレースの見立て）'));
      expect(standard, contains('### 2026/06/01 テスト重賞(GII)（raceId: p1）'));
      expect(standard, contains('- 今回の出走馬: 1番 テスト馬 2人気1着'));
      expect(
          standard,
          contains(
              '**AIの予想（レース前に取り込んだもの）**\n> 【レース総論】スロー\n>\n> 【買い目】単勝1番\n'));
      expect(standard,
          contains('**レース総評（レース後に書いたもの）**\n> 内が止まらない\n'));
      expect(standard, contains('### 2026/05/01 過去レース2（raceId: p2）'));
      expect(
          standard.indexOf('（raceId: p1）') < standard.indexOf('（raceId: p2）'),
          isTrue);
      expect(standard, isNot(contains('今回のAI予想')));
      expect(standard, isNot(contains('（raceId: 202606040911）')));
      expect(standard, isNot(contains('出ていないレース')));
      expect(
          standard.indexOf('## 各馬詳細') <
              standard.indexOf('## 過去レースのAI予想・レース総評'),
          isTrue);
      expect(summary, isNot(contains('## 過去レースのAI予想・レース総評')));
    });

    test('依頼文に過去レースの印・メモの読み方がある', () {
      final md = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: _bundle(), grain: AiExportGrain.summary);
      expect(md,
          contains('- 過去走の印・メモ／過去レースのAI予想・レース総評: 過去のレースで'));
    });

    // [追加] AI分析データ 過去データ分離 Step2: 出力日時と、依頼文の過去データの説明 (v.2026.10.14+26101402)
    test('出力日時を渡すと資料の先頭に書き、渡さなければ書かない', () {
      final md = buildRaceFullAiMarkdown(
          raceData: _race(),
          bundle: _bundle(),
          grain: AiExportGrain.standard,
          exportedAt: DateTime(2026, 10, 14, 6, 58));
      expect(md.startsWith('出力日時: 2026-10-14 06:58\n'), isTrue);
      final none = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: _bundle(), grain: AiExportGrain.standard);
      expect(none.startsWith('# この資料の使い方（AIへの依頼）'), isTrue);
      expect(none, isNot(contains('出力日時: 20')));
    });

    test('formatAiExportedAt は月・日・時・分を2桁にする', () {
      expect(formatAiExportedAt(DateTime(2026, 1, 2, 3, 4)), '2026-01-02 03:04');
    });

    test('依頼文に過去データ（別ファイル）と出力日時の読み方がある', () {
      final md = buildRaceFullAiMarkdown(
          raceData: _race(), bundle: _bundle(), grain: AiExportGrain.summary);
      expect(md, contains('同じレースの「過去データ」（別のMarkdown'));
      expect(md, contains('- 過去データ（別ファイル）: '));
      expect(md, contains('- 出力日時: この資料（追加データ）を出した時刻'));
    });
  });
}
