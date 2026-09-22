// lib/utils/training_date_utils.dart

import 'package:hetaumakeiba_v2/models/training_time_model.dart';

// [追加] 調教タブ改修Step1: 調教データの日付処理とラップ計算の共通関数 (v.2026.9.22+26092210)

/// '2026年9月27日' / '2026/09/27' / '2026-9-27' / '20260927' などを 'YYYYMMDD' に変換する。
/// 変換できない場合は null を返す。
String? toYyyymmdd(String rawDate) {
  final match = RegExp(r'(\d{4})[年/\-]\s*(\d{1,2})[月/\-]\s*(\d{1,2})')
      .firstMatch(rawDate);
  if (match != null) {
    final y = match.group(1)!;
    final m = match.group(2)!.padLeft(2, '0');
    final d = match.group(3)!.padLeft(2, '0');
    return '$y$m$d';
  }
  final digits = rawDate.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length == 8) return digits;
  return null;
}

/// レース日より前（レース当日を含まない）の調教だけを返す。入力の並び順は保持する。
/// [raceDate] が変換できない場合は絞り込まずにそのまま返す。
/// 調教日が 'YYYYMMDD' 形式でない行は、判断できないため残す。
List<TrainingTimeModel> filterTrainingBeforeRace(
    List<TrainingTimeModel> records, String raceDate) {
  final raceYmd = toYyyymmdd(raceDate);
  if (raceYmd == null) return records;
  return records.where((r) {
    if (r.trainingDate.length != 8) return true;
    return r.trainingDate.compareTo(raceYmd) < 0;
  }).toList();
}

/// 馬IDごとの調教データを、すべてレース日より前だけに絞る。
Map<String, List<TrainingTimeModel>> filterTrainingMapBeforeRace(
    Map<String, List<TrainingTimeModel>> map, String raceDate) {
  return map.map((horseId, records) =>
      MapEntry(horseId, filterTrainingBeforeRace(records, raceDate)));
}

/// 累計タイム（長い距離から順。例: 4F,3F,2F,1F）から、各列の1Fラップを求める。
/// ラップ[i] = 累計[i] − 累計[i+1]、最後の要素は累計の最後（ラスト1F）そのもの。
/// 小数第1位に丸める。空リストなら空リストを返す。
List<double> calcTrainingLaps(List<double> cumulatives) {
  final laps = <double>[];
  for (int i = 0; i < cumulatives.length; i++) {
    final value = i < cumulatives.length - 1
        ? cumulatives[i] - cumulatives[i + 1]
        : cumulatives[i];
    laps.add(double.parse(value.toStringAsFixed(1)));
  }
  return laps;
}
