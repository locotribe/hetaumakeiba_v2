// lib/logic/analysis/game_form_inputs.dart
// [追加] 展開シミュ改良Step7b: 調子を展開シミュタブに渡すための材料作り(過去走のレース結果から上がりの順位を作る・出走馬ぶんの調子を作る)と、
// 画面に出す言葉。純粋ロジック。上がりの順位は原型の agari.py と同じ(上がりの速い順。同じ秒は馬IDの順)で、参照実装は formref7b.py。
// 設計は memory/展開シミュ_調子_設計メモ.md の4章・6章 (v.2026.10.30+26103006)

import 'package:hetaumakeiba_v2/logic/analysis/game_form.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/training_time_model.dart';

class GameFormInputs {
  GameFormInputs._();

  /// レース結果を一度に読む件数(DB の変数の数の上限に当たらないように分ける)
  static const int resultChunkSize = 400;

  /// 上がりの順位を出すのに必要な、上がりが読めた頭数の最小
  static const int minAgariCount = 5;

  /// 出走馬全員の過去走のレースID(重複なし。空は除く。出てきた順)
  static List<String> raceIdsOf(Iterable<List<HorseRaceRecord>> recordLists) {
    final seen = <String>{};
    final out = <String>[];
    for (final list in recordLists) {
      for (final r in list) {
        if (r.raceId.isEmpty) continue;
        if (seen.add(r.raceId)) out.add(r.raceId);
      }
    }
    return out;
  }

  /// レースIDを [resultChunkSize] 件ずつに分ける
  static List<List<String>> chunksOf(List<String> ids) {
    final out = <List<String>>[];
    for (int i = 0; i < ids.length; i += resultChunkSize) {
      final end = i + resultChunkSize < ids.length ? i + resultChunkSize : ids.length;
      out.add(ids.sublist(i, end));
    }
    return out;
  }

  /// レース結果1つ → 馬ID → 上がりの順位(速い順)。
  /// 上がりが読めた(0より大きい)馬が [minAgariCount] 頭未満のレースは空。
  static Map<String, GameFormAgariRank> agariRanksOfResult(RaceResult result) {
    final rows = <(double, String)>[];
    for (final h in result.horseResults) {
      final a = double.tryParse(h.agari.trim());
      if (h.horseId.isEmpty || a == null || !(a > 0)) continue;
      rows.add((a, h.horseId));
    }
    if (rows.length < minAgariCount) return const {};
    rows.sort((x, y) {
      final c = x.$1.compareTo(y.$1);
      return c != 0 ? c : x.$2.compareTo(y.$2);
    });
    return {
      for (int i = 0; i < rows.length; i++)
        rows[i].$2: GameFormAgariRank(rank: i + 1, count: rows.length),
    };
  }

  /// レースID → (馬ID → 上がりの順位)
  static Map<String, Map<String, GameFormAgariRank>> agariTableOf(
      Map<String, RaceResult> results) {
    return {
      for (final e in results.entries) e.key: agariRanksOfResult(e.value),
    };
  }

  /// 1頭ぶんの、過去走のレースID → 上がりの順位(その馬の分だけ)
  static Map<String, GameFormAgariRank> agariRanksOfHorse(
    String horseId,
    List<HorseRaceRecord> records,
    Map<String, Map<String, GameFormAgariRank>> table,
  ) {
    final out = <String, GameFormAgariRank>{};
    for (final r in records) {
      final a = table[r.raceId]?[horseId];
      if (a != null) out[r.raceId] = a;
    }
    return out;
  }

  /// 出走馬ぶんの調子(入力の馬の順)。
  /// [records]・[trainings] は馬ID → 今回のレースの日より前の過去走・坂路とウッドの時計、[raceYmd] は今回のレースの日(YYYYMMDD)、
  /// [results] は過去走のレースID → レース結果(上がりの順位を作る。無いレースは着順だけで出来を出す)。
  static List<GameFormResult> formsOf({
    required List<String> horseIds,
    required Map<String, List<HorseRaceRecord>> records,
    required Map<String, List<TrainingTimeModel>> trainings,
    required String raceYmd,
    Map<String, RaceResult> results = const {},
  }) {
    final table = agariTableOf(results);
    return [
      for (final id in horseIds)
        GameForm.of(
          records[id] ?? const <HorseRaceRecord>[],
          trainings: trainings[id] ?? const <TrainingTimeModel>[],
          raceYmd: raceYmd,
          agariRanks: agariRanksOfHorse(
              id, records[id] ?? const <HorseRaceRecord>[], table),
        ),
    ];
  }
}

/// 調子を画面に出す言葉。
class GameFormText {
  GameFormText._();

  /// 5段階の名前
  static String levelLabel(GameFormLevel level) {
    switch (level) {
      case GameFormLevel.best:
        return '絶好調';
      case GameFormLevel.good:
        return '好調';
      case GameFormLevel.normal:
        return '普通';
      case GameFormLevel.poor:
        return '不調';
      case GameFormLevel.worst:
        return '絶不調';
    }
  }

  /// 5段階の矢印
  static String arrowOf(GameFormLevel level) {
    switch (level) {
      case GameFormLevel.best:
        return '▲▲';
      case GameFormLevel.good:
        return '▲';
      case GameFormLevel.normal:
        return '―';
      case GameFormLevel.poor:
        return '▼';
      case GameFormLevel.worst:
        return '▼▼';
    }
  }

  /// ラベルの言葉(「▲ 好調」)
  static String chipOf(GameFormLevel level) =>
      '${arrowOf(level)} ${levelLabel(level)}';

  /// ラベルの横に出す言葉。
  /// 普通以外は「時計が良い・参照5走」。普通は理由を出さず「参照3走」(追い切りが無い・比べる過去走が無いときは、その理由)
  static String detailOf(GameFormResult r) {
    if (r.level == GameFormLevel.normal) {
      return r.referenceCount > 0 ? '参照${r.referenceCount}走' : r.reason;
    }
    return '${r.reason}・参照${r.referenceCount}走';
  }
}
