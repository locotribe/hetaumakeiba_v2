// [追加] UIと描画ロジックを分離するサービスクラス (v.1.0)
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hetaumakeiba_v2/models/elevation_model.dart';

/// UI側へ渡すためのチャート描画用データ構造
class ChartDrawData {
  final List<FlSpot> spots;
  final LinearGradient lineGradient;
  final LinearGradient areaGradient;
  final double maxX;

  /// 表示用に並べ替えたセクション一覧。右回りコースの場合は
  /// [spots]のx軸反転に合わせてstartDistance/endDistanceを
  /// (raceDistance - 元の値)に変換し、表示順も反転させたもの。
  final List<CourseSection> displaySections;

  ChartDrawData({
    required this.spots,
    required this.lineGradient,
    required this.areaGradient,
    required this.maxX,
    required this.displaySections,
  });
}

class ElevationLogic {
  /// レースデータからチャート描画用のスポットデータとグラデーションを生成する
  static ChartDrawData generateRaceChartData(RaceCourseData race) {
    final lapDist = race.baseData.lapDistance;
    final raceDist = race.raceDistance.toDouble();

    final approachDist = race.approachPath?.fold(0.0, (sum, a) => sum + a.distance) ?? 0.0;
    final joinPointOnLap = (raceDist - approachDist) % lapDist;

    final isStraight = race.baseData.trackType.contains('straight');

    final List<FlSpot> spots = [];

    // 高低差の座標（FlSpot）を生成
    for (double x = 0; x <= raceDist; x += 1.0) {
      double elevation;

      if (isStraight) {
        // 直線コース：ゴールが0m地点となるため逆算して参照
        elevation = race.baseData.getElevationAt(raceDist - x);
      } else {
        // 周回コース：ゴールからの逆算
        double distFromGoal = raceDist - x;
        if (distFromGoal > (raceDist - approachDist)) {
          // 本線へのアプローチ区間
          elevation = race.baseData.getElevationAt(joinPointOnLap);
        } else {
          // 周回本線区間
          double d = distFromGoal % lapDist;
          if (d == 0.0 && distFromGoal > 0.0) d = lapDist;
          elevation = race.baseData.getElevationAt(d);
        }
      }
      spots.add(FlSpot(x, elevation));
    }
    // 終端スポット（常にゴール：0.0m地点）
    spots.add(FlSpot(raceDist, race.baseData.getElevationAt(0.0)));

    // セクションに応じたグラデーションを生成
    final lineGradient = _buildLineGradient(race.sections, race.baseData.trackType, raceDist);
    final areaGradient = LinearGradient(
      colors: lineGradient.colors.map((c) => c.withOpacity(0.15)).toList(),
      stops: lineGradient.stops,
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    // 右回りコース(isLeftHanded=false)はチャートの左右を反転させ、
    // 右側がスタート・左側がゴールになるようにする。
    // (左回りコースは従来通り左=スタート/右=ゴール)
    if (!race.isLeftHanded) {
      final flippedSpots = spots.reversed
          .map((s) => FlSpot(raceDist - s.x, s.y))
          .toList();
      final flippedSections = race.sections.reversed
          .map((sec) => CourseSection(
                name: sec.name,
                startDistance: raceDist - sec.endDistance,
                endDistance: raceDist - sec.startDistance,
              ))
          .toList();

      return ChartDrawData(
        spots: flippedSpots,
        lineGradient: _reverseGradient(lineGradient),
        areaGradient: _reverseGradient(areaGradient),
        maxX: raceDist,
        displaySections: flippedSections,
      );
    }

    return ChartDrawData(
      spots: spots,
      lineGradient: lineGradient,
      areaGradient: areaGradient,
      maxX: raceDist,
      displaySections: race.sections,
    );
  }

  /// グラデーションの色配列とstopsを反転させる(チャートのx軸反転に追従させる)
  static LinearGradient _reverseGradient(LinearGradient gradient) {
    final stops = gradient.stops!;
    final n = stops.length;
    final newColors = <Color>[];
    final newStops = <double>[];
    for (int i = n - 1; i >= 0; i--) {
      newColors.add(gradient.colors[i]);
      newStops.add(1.0 - stops[i]);
    }
    return LinearGradient(
      colors: newColors,
      stops: newStops,
      begin: gradient.begin,
      end: gradient.end,
    );
  }

  /// トラックタイプに応じた基本カラーを取得
  static Color getTrackColor(String trackType) {
    return trackType.contains('dirt') ? const Color(0xFFB07040) : Colors.greenAccent;
  }

  /// セクション名から路面変更（芝・ダート）に応じたグラデーションを生成
  static LinearGradient _buildLineGradient(List<CourseSection> sections, String baseTrackType, double maxDistance) {
    List<Color> colors = [];
    List<double> stops = [];
    Color baseColor = getTrackColor(baseTrackType);

    if (maxDistance <= 0 || sections.isEmpty) {
      return LinearGradient(colors: [baseColor, baseColor], stops: const [0.0, 1.0]);
    }

    for (var sec in sections) {
      Color secColor = baseColor;
      final name = sec.name.toLowerCase();

      // セクション名に応じて色を判定
      if (name.contains('turf') || name.contains('shiba')) {
        secColor = Colors.greenAccent;
      } else if (name.contains('dirt')) {
        secColor = const Color(0xFFB07040);
      }

      double startStop = (sec.startDistance / maxDistance).clamp(0.0, 1.0);
      double endStop = (sec.endDistance / maxDistance).clamp(0.0, 1.0);

      if (stops.isEmpty) {
        colors.add(secColor);
        stops.add(startStop);
      } else if (colors.last != secColor) {
        // 直前の色と違う場合は、境界線をパキッとさせるためのハードストップ処理
        colors.add(colors.last);
        stops.add(startStop);
        colors.add(secColor);
        stops.add(startStop);
      }

      colors.add(secColor);
      stops.add(endStop);
    }

    if (stops.isEmpty) {
      colors = [baseColor, baseColor];
      stops = [0.0, 1.0];
    } else if (stops.last < 1.0) {
      colors.add(colors.last);
      stops.add(1.0);
    }

    return LinearGradient(colors: colors, stops: stops, begin: Alignment.centerLeft, end: Alignment.centerRight);
  }

  /// セクション名の日本語表示用変換
  static String translateSectionName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('start_turf')) return '発走(芝)';
    if (lower.contains('start_dirt')) return '発走(ダ)';
    if (lower.contains('straight') || lower.contains('finish') || lower.contains('home')) return '直線';
    if (lower.contains('backstretch')) return '向正面';
    if (lower.contains('start')) return '発走';
    if (lower.contains('corner_1') || lower.contains('turn_1')) return '1C';
    if (lower.contains('corner_2') || lower.contains('turn_2')) return '2C';
    if (lower.contains('corner_3') || lower.contains('turn_3')) return '3C';
    if (lower.contains('corner_4') || lower.contains('turn_4')) return '4C';
    return name;
  }
}