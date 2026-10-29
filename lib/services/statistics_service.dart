// lib/services/statistics_service.dart

// [削除] 結果分析タブの廃止 Step4: レース名検索で過去レースを集める関数を消したので、それだけに使っていた import（foundation・scraper_service）を外した (v.2026.10.19+26101904)
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_statistics_repository.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'dart:convert';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/logic/analysis/leg_style_classifier.dart';
// [追加] 年齢別成績: 年齢の区分と性齢から年齢を読む関数 (v.2026.10.30+26103002)
import 'package:hetaumakeiba_v2/logic/analysis/age_category.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';

class StatisticsService {
  final RaceRepository _raceRepo = RaceRepository();
  final RaceStatisticsRepository _raceStatsRepo = RaceStatisticsRepository();

  /// [新規追加] レースIDのリストを直接受け取り、統計データを生成・保存する
  Future<RaceStatistics?> processAndSaveRaceStatisticsByIds({
    required String raceId,
    required String raceName,
    required List<String> pastRaceIds,
  }) async {
    final List<RaceResult> pastResults = [];
    for (final pastId in pastRaceIds) {
      RaceResult? result = await _raceRepo.getRaceResult(pastId);
      if (result == null) {
        result = await RaceResultScraperService.scrapeRaceDetails(generateRaceResultUrl(pastId));
        await Future.delayed(const Duration(milliseconds: 200));
      }
      pastResults.add(result);
    }

    if (pastResults.isEmpty) {
      throw Exception('過去のレース結果を取得できませんでした。');
    }

    final statistics = _calculateStatistics(pastResults);

    // ★追加: 分析対象レースのメタデータリストを作成
    final analyzedRacesList = pastResults.map((result) {
      // 1着馬の名前を取得（勝馬がいない場合は空文字）
      String winner = '';
      final firstPlace = result.horseResults.firstWhere(
              (h) => h.rank == '1',
          orElse: () => HorseResult(
              rank: '', frameNumber: '', horseNumber: '', horseName: '', horseId: '',
              sexAndAge: '', weightCarried: '', jockeyName: '', jockeyId: '',
              time: '', margin: '', cornerRanking: '', agari: '', odds: '',
              popularity: '', horseWeight: '', trainerName: '', trainerAffiliation: '',
              ownerName: '', prizeMoney: ''
          ) // ダミー
      );
      if (firstPlace.horseName.isNotEmpty) {
        winner = firstPlace.horseName;
      }

      return {
        'raceId': result.raceId,
        'date': result.raceDate,
        'raceName': result.raceTitle,
        'raceInfo': result.raceInfo, // 距離や馬場状態など
        'winner': winner,
      };
    }).toList();

    // 日付の新しい順にソート
    analyzedRacesList.sort((a, b) => (b['date'] as String).compareTo(a['date'] as String));

    final statsToSave = RaceStatistics(
      raceId: raceId,
      raceName: raceName,
      statisticsJson: json.encode(statistics),
      analyzedRacesJson: json.encode(analyzedRacesList), // ★追加
      lastUpdatedAt: DateTime.now(),
    );

    await _raceStatsRepo.insertOrUpdateRaceStatistics(statsToSave);
    return statsToSave;
  }

  // [削除] 結果分析タブの廃止 Step4: レース名検索で過去レースを集める fetchPastRacesForAnalysis と、それを使う古い統計の作成 processAndSaveRaceStatistics を削除した（過去分析は processAndSaveRaceStatisticsByIds を使う。レース結果ページのペースの予想だけが使っていた） (v.2026.10.19+26101904)


  // [追加] 馬体重増減別の7区分（表示順）。保存用の集計・過去分析の画面・好走馬の選出が同じ区分を使う (v.2026.10.30+26103001)
  static const List<String> weightChangeCategories = [
    '-10kg以下',
    '-9~-5kg',
    '-4~-1kg',
    '0kg',
    '+1~+4kg',
    '+5~+9kg',
    '+10kg以上',
  ];

  // [追加] 馬体重の増減(kg)を7区分のラベルへ変換する (v.2026.10.30+26103001)
  static String weightChangeCategoryOf(int change) {
    if (change <= -10) return '-10kg以下';
    if (change <= -5) return '-9~-5kg';
    if (change <= -1) return '-4~-1kg';
    if (change == 0) return '0kg';
    if (change <= 4) return '+1~+4kg';
    if (change <= 9) return '+5~+9kg';
    return '+10kg以上';
  }

  // [追加] 過去レース結果から馬体重増減別の成績だけを7区分で集計し直す。保存済みの旧区分（5区分）の統計を画面側で差し替えるために使う。集計の条件は _calculateStatistics と同じ (v.2026.10.30+26103001)
  static Map<String, Map<String, dynamic>> recalcHorseWeightChangeStats(List<RaceResult> results) {
    final Map<String, Map<String, dynamic>> stats = {};
    for (final result in results) {
      for (final horse in result.horseResults) {
        final rank = int.tryParse(horse.rank);
        if (rank == null) continue;
        // [修正] 実データの増減0は符号なしの (0) なので、符号を省略可にした (v.2026.10.30+26103001)
        final weightMatch = RegExp(r'(\d+)\(([\+\-]?\d+)\)').firstMatch(horse.horseWeight);
        if (weightMatch == null) continue;
        final weightChange = int.tryParse(weightMatch.group(2)!);
        if (weightChange == null) continue;
        final category = weightChangeCategoryOf(weightChange);
        stats.putIfAbsent(category, () => {'total': 0, 'win': 0, 'place': 0, 'show': 0});
        stats[category]!['total'] = (stats[category]!['total'] ?? 0) + 1;
        if (rank == 1) stats[category]!['win'] = (stats[category]!['win'] ?? 0) + 1;
        if (rank <= 2) stats[category]!['place'] = (stats[category]!['place'] ?? 0) + 1;
        if (rank <= 3) stats[category]!['show'] = (stats[category]!['show'] ?? 0) + 1;
      }
    }
    return stats;
  }

  // [追加] 年齢別（3歳〜7歳以上の5区分）の成績を集計する。出走馬に2つ以上の年齢がいるレース（年齢混合戦）だけを対象にし、2歳戦・3歳限定戦など同世代戦は除く。保存用の集計（_calculateStatistics）と、保存済みの統計に年齢別が無いときの画面側の集計し直しの両方で使う (v.2026.10.30+26103002)
  static Map<String, Map<String, dynamic>> recalcAgeStats(List<RaceResult> results) {
    final Map<String, Map<String, dynamic>> stats = {};
    for (final result in results) {
      if (!hasMixedAges(result.horseResults.map((h) => h.sexAndAge))) continue;
      for (final horse in result.horseResults) {
        final rank = int.tryParse(horse.rank);
        if (rank == null) continue;
        final age = ageOfSexAndAge(horse.sexAndAge);
        if (age == null) continue;
        final category = ageCategoryOf(age);
        if (category == null) continue;
        stats.putIfAbsent(category, () => {'total': 0, 'win': 0, 'place': 0, 'show': 0});
        stats[category]!['total'] = (stats[category]!['total'] ?? 0) + 1;
        if (rank == 1) stats[category]!['win'] = (stats[category]!['win'] ?? 0) + 1;
        if (rank <= 2) stats[category]!['place'] = (stats[category]!['place'] ?? 0) + 1;
        if (rank <= 3) stats[category]!['show'] = (stats[category]!['show'] ?? 0) + 1;
      }
    }
    return stats;
  }

  // 取得したレース結果リストから統計を計算する
  Map<String, dynamic> _calculateStatistics(List<RaceResult> results) {
    // 各分析項目用のMapを初期化
    final Map<String, Map<String, dynamic>> popularityStats = {};
    final Map<String, Map<String, dynamic>> frameStats = {};
    final Map<String, Map<String, dynamic>> jockeyStats = {};
    final Map<String, Map<String, dynamic>> trainerStats = {};
    final Map<String, Map<String, dynamic>> legStyleStats = {};
    // [追加] 性別（牡・牝・セ）別成績。混合戦のみを母集団とする (v.2026.9.9+26090904)
    final Map<String, Map<String, dynamic>> genderStats = {};
    final Map<String, List<int>> payoutStats = {
      for (var v in bettingDict.values) v: []
    };
    final Map<String, Map<String, dynamic>> horseWeightChangeStats = {};
    final List<int> winningHorseWeights = [];

    // 集計用のループ
    for (final result in results) {
      // [追加] 混合戦判定: 牝 と 牡/セ が両方出走しているレースのみ性別集計の対象とする (v.2026.9.9+26090904)
      bool hasFemale = false;
      bool hasMaleOrGelding = false;
      for (final h in result.horseResults) {
        if (h.sexAndAge.isEmpty) continue;
        final s = h.sexAndAge.substring(0, 1);
        if (s == '牝') {
          hasFemale = true;
        } else if (s == '牡' || s == 'セ') {
          hasMaleOrGelding = true;
        }
      }
      final bool isMixedGenderRace = hasFemale && hasMaleOrGelding;

      // 配当データの集計
      for (final refund in result.refunds) {
        final ticketTypeName = bettingDict[refund.ticketTypeId];
        if (ticketTypeName != null && payoutStats.containsKey(ticketTypeName)) {
          for (final payout in refund.payouts) {
            final amount = int.tryParse(payout.amount.replaceAll(',', '')) ?? 0;
            if (amount > 0) {
              payoutStats[ticketTypeName]?.add(amount);
            }
          }
        }
      }

      for (final horse in result.horseResults) {
        final rank = int.tryParse(horse.rank);
        if (rank == null) continue; // 着順が数値でない馬は集計から除外

        final isWin = rank == 1;
        final isPlace = rank <= 2;
        final isShow = rank <= 3;

        // 人気別成績
        final popularity = horse.popularity;
        popularityStats.putIfAbsent(popularity, () => {'total': 0, 'win': 0, 'place': 0, 'show': 0});
        popularityStats[popularity]!['total'] = (popularityStats[popularity]!['total'] ?? 0) + 1;
        if (isWin) popularityStats[popularity]!['win'] = (popularityStats[popularity]!['win'] ?? 0) + 1;
        if (isPlace) popularityStats[popularity]!['place'] = (popularityStats[popularity]!['place'] ?? 0) + 1;
        if (isShow) popularityStats[popularity]!['show'] = (popularityStats[popularity]!['show'] ?? 0) + 1;

        // 枠番別成績
        final frame = horse.frameNumber;
        frameStats.putIfAbsent(frame, () => {'total': 0, 'win': 0, 'place': 0, 'show': 0});
        frameStats[frame]!['total'] = (frameStats[frame]!['total'] ?? 0) + 1;
        if (isWin) frameStats[frame]!['win'] = (frameStats[frame]!['win'] ?? 0) + 1;
        if (isPlace) frameStats[frame]!['place'] = (frameStats[frame]!['place'] ?? 0) + 1;
        if (isShow) frameStats[frame]!['show'] = (frameStats[frame]!['show'] ?? 0) + 1;

        // 騎手別成績
        // [修正] 騎手名の表記揺れ(「M.デム」⇔「Mデムーロ」等)で照合できないため騎手IDをキーにする。
        // jockeyId は後付けフィールドで古い保存済みレース結果では空文字になりうるため、
        // 空の場合は従来どおり騎手名をキーにして、空文字キーへ全騎手が合算されるのを防ぐ。
        // 表示用に 'name' を値へ保持する (v.2026.9.9+26090905)
        final String jockeyKey =
            horse.jockeyId.isNotEmpty ? horse.jockeyId : horse.jockeyName;
        if (jockeyKey.isNotEmpty) {
          jockeyStats.putIfAbsent(
              jockeyKey,
              () => {
                    'name': horse.jockeyName,
                    'total': 0,
                    'win': 0,
                    'place': 0,
                    'show': 0
                  });
          final jockeyEntry = jockeyStats[jockeyKey]!;
          final currentName = jockeyEntry['name'];
          if (currentName is! String || currentName.isEmpty) {
            jockeyEntry['name'] = horse.jockeyName;
          }
          jockeyEntry['total'] = (jockeyEntry['total'] ?? 0) + 1;
          if (isWin) jockeyEntry['win'] = (jockeyEntry['win'] ?? 0) + 1;
          if (isPlace) jockeyEntry['place'] = (jockeyEntry['place'] ?? 0) + 1;
          if (isShow) jockeyEntry['show'] = (jockeyEntry['show'] ?? 0) + 1;
        }

        // 調教師別成績
        final trainer = horse.trainerName;
        trainerStats.putIfAbsent(trainer, () => {'total': 0, 'win': 0, 'place': 0, 'show': 0});
        trainerStats[trainer]!['total'] = (trainerStats[trainer]!['total'] ?? 0) + 1;
        if (isWin) trainerStats[trainer]!['win'] = (trainerStats[trainer]!['win'] ?? 0) + 1;
        if (isPlace) trainerStats[trainer]!['place'] = (trainerStats[trainer]!['place'] ?? 0) + 1;
        if (isShow) trainerStats[trainer]!['show'] = (trainerStats[trainer]!['show'] ?? 0) + 1;

        final horseCount = result.horseResults.length;
        final style = classifyLegStyle(horse.cornerRanking, horseCount);
        if (style != legStyleUnknown) {
          legStyleStats.putIfAbsent(style, () => {'total': 0, 'win': 0, 'place': 0, 'show': 0});
          legStyleStats[style]!['total'] = (legStyleStats[style]!['total'] ?? 0) + 1;
          if (isWin) legStyleStats[style]!['win'] = (legStyleStats[style]!['win'] ?? 0) + 1;
          if (isPlace) legStyleStats[style]!['place'] = (legStyleStats[style]!['place'] ?? 0) + 1;
          if (isShow) legStyleStats[style]!['show'] = (legStyleStats[style]!['show'] ?? 0) + 1;
        }

        // [追加] 性別別成績 (混合戦のみ集計) (v.2026.9.9+26090904)
        if (isMixedGenderRace && horse.sexAndAge.isNotEmpty) {
          final gender = horse.sexAndAge.substring(0, 1);
          if (gender == '牡' || gender == '牝' || gender == 'セ') {
            genderStats.putIfAbsent(gender, () => {'total': 0, 'win': 0, 'place': 0, 'show': 0});
            genderStats[gender]!['total'] = (genderStats[gender]!['total'] ?? 0) + 1;
            if (isWin) genderStats[gender]!['win'] = (genderStats[gender]!['win'] ?? 0) + 1;
            if (isPlace) genderStats[gender]!['place'] = (genderStats[gender]!['place'] ?? 0) + 1;
            if (isShow) genderStats[gender]!['show'] = (genderStats[gender]!['show'] ?? 0) + 1;
          }
        }

        // 馬体重別成績
        // [修正] 実データの増減0は符号なしの (0) なので、符号を省略可にした（旧: 増減0の馬が集計から漏れていた。勝ち馬の平均体重にも増減0の勝ち馬が入る） (v.2026.10.30+26103001)
        final weightMatch = RegExp(r'(\d+)\(([\+\-]?\d+)\)').firstMatch(horse.horseWeight);
        if (weightMatch != null) {
          final weight = int.tryParse(weightMatch.group(1)!);
          final weightChange = int.tryParse(weightMatch.group(2)!);
          if (weight != null && weightChange != null) {
            if(isWin) winningHorseWeights.add(weight);
            // [修正] 馬体重増減別を7区分に変更。区分けは weightChangeCategoryOf にまとめた (v.2026.10.30+26103001)
            final String category = weightChangeCategoryOf(weightChange);

            horseWeightChangeStats.putIfAbsent(category, () => {'total': 0, 'win': 0, 'place': 0, 'show': 0});
            horseWeightChangeStats[category]!['total'] = (horseWeightChangeStats[category]!['total'] ?? 0) + 1;
            if (isWin) horseWeightChangeStats[category]!['win'] = (horseWeightChangeStats[category]!['win'] ?? 0) + 1;
            if (isPlace) horseWeightChangeStats[category]!['place'] = (horseWeightChangeStats[category]!['place'] ?? 0) + 1;
            if (isShow) horseWeightChangeStats[category]!['show'] = (horseWeightChangeStats[category]!['show'] ?? 0) + 1;
          }
        }
      }
    }

    final Map<String, dynamic> finalPayoutStats = {};
    payoutStats.forEach((key, value) {
      if (value.isNotEmpty) {
        finalPayoutStats[key] = {
          'average': (value.reduce((a, b) => a + b) / value.length).round(),
          'max': value.reduce((a, b) => a > b ? a : b),
          'min': value.reduce((a, b) => a < b ? a : b),
        };
      }
    });

    final double avgWinningHorseWeight = winningHorseWeights.isNotEmpty
        ? winningHorseWeights.reduce((a, b) => a + b) / winningHorseWeights.length
        : 0.0;

    return {
      'analyzedYears': results.map((r) => r.raceDate.substring(0, 4)).toSet().toList(),
      'popularityStats': popularityStats,
      'frameStats': frameStats,
      'jockeyStats': jockeyStats,
      'trainerStats': trainerStats,
      'legStyleStats': legStyleStats,
      // [追加] 性別別成績（混合戦のみ） (v.2026.9.9+26090904)
      'genderStats': genderStats,
      // [追加] 年齢別成績（年齢混合戦のみ） (v.2026.10.30+26103002)
      'ageStats': recalcAgeStats(results),
      'payoutStats': finalPayoutStats,
      'horseWeightChangeStats': horseWeightChangeStats,
      'avgWinningHorseWeight': avgWinningHorseWeight,
    };
  }
}