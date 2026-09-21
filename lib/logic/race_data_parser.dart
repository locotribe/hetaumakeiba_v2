// lib/logic/race_data_parser.dart

import 'package:hetaumakeiba_v2/models/race_result_model.dart';

class RaceDataParser {
  /// コーナー通過順位の文字列（例: "1角:1-2-3 / 2角:2-1-3"）を解析し、
  /// 構造化データ（Map<String, List<int>>）に変換します。
  static Map<String, List<int>> parseCornerPassages(String cornerData) {
    final Map<String, List<int>> cornerMap = {};
    if (cornerData.isEmpty) {
      return cornerMap;
    }

    // " / "で各コーナーのデータを分割
    final parts = cornerData.split(' / ');
    for (final part in parts) {
      // ":"でコーナー名と順位リストを分割
      final cornerParts = part.split(':');
      if (cornerParts.length == 2) {
        final cornerName = cornerParts[0].trim();
        final passages = cornerParts[1]
            .trim()
            .replaceAll(RegExp(r'[\(\)]'), '') // カッコを削除
            .split(',') // カンマ区切りの場合に対応
            .expand((s) => s.split('-')) // ハイフン区切りでさらに分割
            .map((s) => int.tryParse(s.trim()))
            .where((i) => i != null)
            .cast<int>()
            .toList();
        cornerMap[cornerName] = passages;
      }
    }
    return cornerMap;
  }

  /// ラップタイムの文字列（例: "12.5 - 10.8 - 11.2"）を解析し、
  /// ラップのリスト（List<double>）に変換します。
  static List<double> parseLapTimes(String lapData) {
    if (lapData.isEmpty) {
      return [];
    }

    return lapData
        .split('-')
        .map((s) => double.tryParse(s.trim()))
        .where((d) => d != null)
        .cast<double>()
        .toList();
  }

  /// 前半・後半3ハロンのタイム文字列（例: "34.5-35.0"）から、
  /// レースペース（ハイ/ミドル/スロー）を判定します。
  static String calculatePace(String paceData) {
    if (paceData.isEmpty || !paceData.contains('-')) {
      return 'ミドル'; // 不明な場合はミドルペースとする
    }

    final parts = paceData.split('-');
    if (parts.length < 2) {
      return 'ミドル';
    }

    final zenhan = double.tryParse(parts[0].trim());
    final kouhan = double.tryParse(parts[1].trim());

    if (zenhan == null || kouhan == null) {
      return 'ミドル';
    }

    final difference = kouhan - zenhan;

    // [修正] 前傾(テン速い→上がり遅い=差が正)はハイペース。ハイ/スローの反転を是正 (v.2026.7.26+26072604)
    if (difference >= 1.0) {
      return 'ハイ';
    } else if (difference <= -1.0) {
      return 'スロー';
    } else {
      return 'ミドル';
    }
  }

  /// RaceResultオブジェクトからレースペースを判定する
  static String calculatePaceFromRaceResult(RaceResult raceResult) {
    // 距離を取得
    final distanceMatch = RegExp(r'(\d+)m').firstMatch(raceResult.raceInfo);
    if (distanceMatch == null) return 'ミドル';
    final distance = int.tryParse(distanceMatch.group(1)!);
    if (distance == null) return 'ミドル';

    // ラップタイムを数値のリストに変換
    // [修正] lapTimesには「ラップ:」行と累計タイムの「ペース:」行が混在しており、両方を合算していたため「ラップ:」行のみを対象にする (v.2026.9.22+26092201)
    final lapTimes = raceResult.lapTimes
        .where((lapStr) => lapStr.trim().startsWith('ラップ'))
        .expand((lapStr) => lapStr.split(':').last.trim().split('-'))
        .map((s) => double.tryParse(s.trim()))
        .where((d) => d != null)
        .cast<double>()
        .toList();

    if (lapTimes.isEmpty) return 'ミドル';

    // 前半・後半のラップを計算
    final halfPoint = (distance / 2).floor();
    double firstHalfTime = 0;
    double secondHalfTime = 0;
    int currentDistance = 0;

    for (final lap in lapTimes) {
      // 200mごとのラップ
      currentDistance += 200;
      if (currentDistance <= halfPoint) {
        firstHalfTime += lap;
      } else {
        secondHalfTime += lap;
      }
    }

    if (firstHalfTime == 0 || secondHalfTime == 0) return 'ミドル';

    final difference = secondHalfTime - firstHalfTime;

    // [修正] 前半が速く後半が遅い(差が正)はハイペース。ハイ/スローの反転を是正 (v.2026.7.26+26072604)
    if (difference >= 1.0) return 'ハイ';
    if (difference <= -1.0) return 'スロー';
    return 'ミドル';
  }
  // [追加] 成績タブ拡充: レース全体の前後半3F・ペース記号・上がり順位の補助関数 (v.2026.9.22+26092201)
  /// RaceResult.lapTimes の「ペース:」行末尾の括弧（例: "(35.6-34.2)"）から
  /// レース全体の前半3F・後半3Fを取り出す。括弧が無ければ null を返す。
  static ({double first3f, double last3f})? extractRaceFirstLast3F(RaceResult raceResult) {
    for (final lapStr in raceResult.lapTimes) {
      final trimmed = lapStr.trim();
      if (!trimmed.startsWith('ペース')) continue;
      final match = RegExp(r'\(\s*(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)\s*\)').firstMatch(trimmed);
      if (match == null) continue;
      final first = double.tryParse(match.group(1)!);
      final last = double.tryParse(match.group(2)!);
      if (first != null && last != null) {
        return (first3f: first, last3f: last);
      }
    }
    return null;
  }

  /// HorseRaceRecord.pace（例: "35.0-34.5"）をレース全体の前半3F・後半3Fに分解する。
  /// 障害戦など3Fとして不自然な値（45秒以上）は null を返す。
  static ({double first3f, double last3f})? parseRecordPace(String pace) {
    final match = RegExp(r'^\s*(\d+(?:\.\d+)?)\s*-\s*(\d+(?:\.\d+)?)\s*$').firstMatch(pace);
    if (match == null) return null;
    final first = double.tryParse(match.group(1)!);
    final last = double.tryParse(match.group(2)!);
    if (first == null || last == null) return null;
    if (first >= 45.0 || last >= 45.0) return null;
    return (first3f: first, last3f: last);
  }

  /// 前半3F・後半3Fからペース記号（'H' / 'M' / 'S'）を返す。
  /// 判定基準は calculatePace() と同じ（後半-前半 が +1.0秒以上でハイ、-1.0秒以下でスロー）。
  static String paceMarkFromFirstLast3F(double first3f, double last3f) {
    final difference = last3f - first3f;
    if (difference >= 1.0) return 'H';
    if (difference <= -1.0) return 'S';
    return 'M';
  }

  /// レース結果の全頭の上がり3Fから、指定馬の上がり順位（1始まり）を返す。算出できない場合は null。
  static int? computeAgariRank(RaceResult raceResult, String horseId) {
    final targets = raceResult.horseResults.where((h) => h.horseId == horseId);
    if (targets.isEmpty) return null;
    final myAgari = double.tryParse(targets.first.agari.trim());
    if (myAgari == null) return null;
    int fasterCount = 0;
    for (final h in raceResult.horseResults) {
      final agari = double.tryParse(h.agari.trim());
      if (agari != null && agari < myAgari) fasterCount++;
    }
    return fasterCount + 1;
  }

  static String getSimpleLegStyle(String cornerPassage, String numberOfHorsesStr) {
    final horseCount = int.tryParse(numberOfHorsesStr);
    if (horseCount == null || horseCount == 0) return '不明';

    final positions = cornerPassage.split('-').map((p) => int.tryParse(p)).toList();
    if (positions.isEmpty || positions.first == null) return '不明';

    final firstCornerPosition = positions.first!;
    final positionRate = firstCornerPosition / horseCount;

    if (positionRate <= 0.25) return '逃げ';
    if (positionRate <= 0.5) return '先行';
    if (positionRate <= 0.75) return '差し';
    return '追込';
  }
}