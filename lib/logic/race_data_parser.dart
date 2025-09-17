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

    if (difference >= 1.0) {
      return 'スロー';
    } else if (difference <= -1.0) {
      return 'ハイ';
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
    final lapTimes = raceResult.lapTimes
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

    if (difference >= 1.0) return 'スロー';
    if (difference <= -1.0) return 'ハイ';
    return 'ミドル';
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