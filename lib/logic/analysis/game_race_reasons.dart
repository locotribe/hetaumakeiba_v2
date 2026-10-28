// lib/logic/analysis/game_race_reasons.dart
// [追加] 展開シミュ改良Step5a(案E): なぜこの勝率か。各馬について、ゴールまでに得した(+)・損した(−)距離を要素ごとに出し、
// 全馬の平均との差(馬身)の大きい上位2つを返す純粋ロジック。参照実装は Claude outputs/展開シミュ_ゲーム式原型/reasonref.py。
// 設計は memory/展開シミュ_改良案_考察.md の案E (v.2026.10.29+26102902)

import 'package:hetaumakeiba_v2/logic/analysis/game_ability_builder.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_aptitude.dart';
import 'package:hetaumakeiba_v2/logic/analysis/game_race_simulator.dart';

/// 1つの理由。
class GameReason {
  /// 要素([GameRaceReasons.keys] のどれか)
  final String key;

  /// 全馬の平均との差(馬身。+ = 得、− = 損)
  final double lengths;

  /// 適性([key] が 'aptitude')のときの、いちばん効いた項(GameAptitude.termKeys のどれか)。無ければ null
  final String? term;

  /// スタミナ切れ([key] が 'stamina')のときの、HPが尽きた所(ゴールまでの距離 m の平均)。無ければ null
  final double? staminaOutAt;

  /// 画面に出す言葉(「スピード指数が高い」など)
  final String label;

  const GameReason({
    required this.key,
    required this.lengths,
    required this.term,
    required this.staminaOutAt,
    required this.label,
  });

  /// 「+3.1馬身 スピード指数が高い」
  String get text =>
      '${lengths >= 0 ? '+' : '−'}${lengths.abs().toStringAsFixed(1)}馬身 $label';
}

class GameRaceReasons {
  GameRaceReasons._();

  /// 1馬身(m)
  static const double lengthMeters = 2.4;

  /// これより小さい差(馬身)は出さない
  static const double minLengths = 0.1;

  /// 1頭に出す理由の数
  static const int maxCount = 2;

  /// 要素(並びは同じ大きさのときの順)。能力の3つ(スピード指数・適性・斤量)と、エンジンで数えた6つ
  static const List<String> keys = [
    'speedIndex',
    'aptitude',
    'weight',
    'stamina',
    'block',
    'corner',
    'kick',
    'wear',
    'inner',
  ];

  /// 馬ごとの理由(入力の馬の順。大きい順・最大 [maxCount] 個)。
  /// [parts] は終盤の速度加算の内訳(GameAbilityBuilder.speedPartsOf)、[aptitudeTerms]・[aptitudeWeights] は適性の項と重み、
  /// [horses] は多数回の集計(数え上げの平均 stats が無い馬は、エンジンで数えた要素を0とする)。
  /// 能力の3つは「速度加算の差 × 終盤の時間(距離の3分の1 ÷ 基準速度)」の距離にする。
  static List<List<GameReason>> of({
    required List<GameSpeedParts> parts,
    required List<Map<String, double>> aptitudeTerms,
    required Map<String, double> aptitudeWeights,
    required List<GameHorseSummary> horses,
    required double distance,
    required bool isDirt,
  }) {
    final n = parts.length;
    if (n == 0) return const [];
    final vb = 22.0 - distance / 1000.0;
    final late = (distance / 3.0) / vb;
    final values = <String, List<double>>{
      'speedIndex': [for (final p in parts) p.speedIndex * late],
      'aptitude': [for (final p in parts) p.aptitude * late],
      'weight': [for (final p in parts) p.weight * late],
      'stamina': [for (final h in horses) -(h.stats?.staminaLoss ?? 0.0)],
      'block': [for (final h in horses) -(h.stats?.blockLoss ?? 0.0)],
      'corner': [for (final h in horses) -(h.stats?.cornerLoss ?? 0.0)],
      'kick': [for (final h in horses) -(h.stats?.kickLoss ?? 0.0)],
      'wear': [for (final h in horses) -(h.stats?.wearLoss ?? 0.0)],
      'inner': [for (final h in horses) h.stats?.innerGain ?? 0.0],
    };
    final rel = <String, List<double>>{
      for (final k in keys) k: _relLengths(values[k]!),
    };
    // 適性の項ごとの寄与(重み × 項)から、レースの中の平均を引いた値
    final termRel = <String, List<double>>{};
    for (final t in GameAptitude.termKeys) {
      final w = aptitudeWeights[t];
      if (w == null) continue;
      final c = [
        for (int i = 0; i < n; i++)
          w * (i < aptitudeTerms.length ? (aptitudeTerms[i][t] ?? 0.0) : 0.0)
      ];
      final m = _mean(c);
      termRel[t] = [for (final x in c) x - m];
    }
    final out = <List<GameReason>>[];
    for (int i = 0; i < n; i++) {
      final items = <(int, String, double)>[];
      for (int k = 0; k < keys.length; k++) {
        final l = rel[keys[k]]![i];
        if (l.abs() >= minLengths) items.add((k, keys[k], l));
      }
      items.sort((a, b) {
        final c = b.$3.abs().compareTo(a.$3.abs());
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
      final row = <GameReason>[];
      for (final (_, key, l) in items.take(maxCount)) {
        String? term;
        if (key == 'aptitude') {
          double best = 0.0;
          termRel.forEach((t, v) {
            final x = v[i] * (l > 0 ? 1.0 : -1.0);
            if (x > best) {
              best = x;
              term = t;
            }
          });
        }
        final outAt = key == 'stamina' ? horses[i].stats?.staminaOutAt : null;
        row.add(GameReason(
          key: key,
          lengths: l,
          term: term,
          staminaOutAt: outAt,
          label: labelOf(key, l > 0,
              term: term, staminaOutAt: outAt, isDirt: isDirt),
        ));
      }
      out.add(row);
    }
    return out;
  }

  /// 要素と向きから、画面に出す言葉を作る
  static String labelOf(
    String key,
    bool plus, {
    String? term,
    double? staminaOutAt,
    bool isDirt = false,
  }) {
    switch (key) {
      case 'speedIndex':
        return plus ? 'スピード指数が高い' : 'スピード指数が低い';
      case 'aptitude':
        return _aptitudeLabelOf(term, plus, isDirt);
      case 'weight':
        return plus ? '斤量が軽い' : '斤量が重い';
      case 'stamina':
        if (plus) return 'スタミナが持つ';
        if (staminaOutAt == null) return 'スタミナ切れ';
        return 'スタミナ切れ(残り約${(staminaOutAt / 10.0).round() * 10}m)';
      case 'block':
        return plus ? '前が詰まりにくい' : '前が詰まる';
      case 'corner':
        return plus ? '内を回れる' : '外を回る';
      case 'kick':
        return plus ? '砂をかぶりにくい' : '砂をかぶる';
      case 'wear':
        return plus ? '傷んだ内を避けられる' : '傷んだ内を通る';
      case 'inner':
        return plus ? '内ラチ沿いを走れる' : '内ラチから離れる';
    }
    return key;
  }

  static String _aptitudeLabelOf(String? term, bool plus, bool isDirt) {
    switch (term) {
      case 'nearTop3':
        return plus ? '近い距離の成績が良い' : '近い距離の成績が悪い';
      case 'nearNone':
        return plus ? '近い距離を経験済み' : '近い距離の経験がない';
      case 'overBest':
        return plus ? '好走した距離の範囲' : '好走した距離より長い';
      case 'newSurface':
        final s = isDirt ? 'ダート' : '芝';
        return plus ? '$sを経験済み' : '初めての$s';
      case 'distanceUp':
        return plus ? '距離延長ではない' : '距離延長';
      case 'age':
        return plus ? '若い' : '年齢が高い';
      case 'female':
        return plus ? '牡馬・せん馬' : '牝馬';
      case 'restLong':
        return plus ? '休み明けではない' : '休み明け';
      case 'bodyWeightChange':
        return plus ? '馬体重の増減が小さい' : '馬体重の増減が大きい';
    }
    return plus ? '適性が高い' : '適性が低い';
  }

  /// 全馬の平均を引いて馬身にする
  static List<double> _relLengths(List<double> xs) {
    final m = _mean(xs);
    return [for (final x in xs) (x - m) / lengthMeters];
  }

  static double _mean(List<double> xs) {
    double s = 0.0;
    for (final x in xs) {
      s += x;
    }
    return s / xs.length;
  }
}
