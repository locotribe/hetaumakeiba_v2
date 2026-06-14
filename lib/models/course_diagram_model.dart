// lib/models/course_diagram_model.dart
// [追加] コース平面図統合表示機能のためのデータモデル (v.1.0)

import 'dart:math' as math;
import 'dart:ui';
import 'package:hetaumakeiba_v2/models/elevation_model.dart';

/// {venue}_{type}_base_coords.json をパースしたコース平面図の座標データ
class CourseEdgeCoordsData {
  final String venue;
  final String trackType;
  final double baseLapDistance;
  final double pixelsPerMeter;

  /// 本線をトレースした生ピクセル座標列。
  /// index 0 = ゴール位置、index増加方向 = ゴールから逆算した距離が増加する方向。
  final List<Offset> edgePoints;

  /// edgePoints[i]までの累積距離(m)。cumulativeDistances[0] == 0.0。
  final List<double> cumulativeDistances;

  /// レース距離(m) -> シュート（引き込み線）の生ピクセル座標列。
  /// 本線上から発走するレース距離はここに含まれない。
  final Map<int, List<Offset>> approachPaths;

  const CourseEdgeCoordsData({
    required this.venue,
    required this.trackType,
    required this.baseLapDistance,
    required this.pixelsPerMeter,
    required this.edgePoints,
    required this.cumulativeDistances,
    required this.approachPaths,
  });

  factory CourseEdgeCoordsData.fromJson(
      String venue, String trackType, Map<String, dynamic> json) {
    final pixelsPerMeter = (json['pixels_per_meter'] as num).toDouble();

    final edgePoints = (json['edge_points'] as List)
        .map((p) => Offset(
              (p[0] as num).toDouble(),
              (p[1] as num).toDouble(),
            ))
        .toList();

    final cumulativeDistances = <double>[0.0];
    for (int i = 1; i < edgePoints.length; i++) {
      final segmentPx = (edgePoints[i] - edgePoints[i - 1]).distance;
      cumulativeDistances
          .add(cumulativeDistances.last + segmentPx / pixelsPerMeter);
    }

    final approachPathsJson = json['approach_paths'] as Map<String, dynamic>?;
    final approachPaths = <int, List<Offset>>{};
    approachPathsJson?.forEach((key, value) {
      final raceDistance = int.tryParse(key);
      if (raceDistance == null) return;
      approachPaths[raceDistance] = (value as List)
          .map((p) => Offset(
                (p[0] as num).toDouble(),
                (p[1] as num).toDouble(),
              ))
          .toList();
    });

    return CourseEdgeCoordsData(
      venue: venue,
      trackType: trackType,
      baseLapDistance: (json['base_lap_distance'] as num).toDouble(),
      pixelsPerMeter: pixelsPerMeter,
      edgePoints: edgePoints,
      cumulativeDistances: cumulativeDistances,
      approachPaths: approachPaths,
    );
  }

  /// 指定レース距離のシュート（引き込み線）座標列を取得する。
  /// 該当データがない場合（本線上から発走するレース）はnullを返す。
  List<Offset>? approachPathFor(int raceDistance) => approachPaths[raceDistance];

  /// distance(m, 0=ゴール)に最も近い隣接区間を二分探索し、
  /// edgePoints間を線形補間した座標を返す（マーカー位置算出用）。
  Offset positionAtDistance(double distance) {
    final d = distance.clamp(0.0, cumulativeDistances.last);
    int lo = 0, hi = cumulativeDistances.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (cumulativeDistances[mid] <= d) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final d0 = cumulativeDistances[lo];
    final d1 = cumulativeDistances[hi];
    final ratio = (d1 == d0) ? 0.0 : (d - d0) / (d1 - d0);
    final p0 = edgePoints[lo];
    final p1 = edgePoints[hi];
    return Offset(
      p0.dx + (p1.dx - p0.dx) * ratio,
      p0.dy + (p1.dy - p0.dy) * ratio,
    );
  }

  /// distance(m, 0=ゴール)以下となる最大のedgePointsインデックスを取得する
  /// （軌跡描画の区間切り出し用）。
  int indexAtDistance(double distance) {
    final d = distance.clamp(0.0, cumulativeDistances.last);
    int lo = 0, hi = cumulativeDistances.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (cumulativeDistances[mid] <= d) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo;
  }

  /// 指定座標(生ピクセル)に最も近いedgePointsのインデックスを取得する
  /// （シュート区間が本線へ合流する地点の特定に使用）。
  int nearestEdgeIndex(Offset point) {
    int nearest = 0;
    double minDistSq = double.infinity;
    for (int i = 0; i < edgePoints.length; i++) {
      final dx = edgePoints[i].dx - point.dx;
      final dy = edgePoints[i].dy - point.dy;
      final distSq = dx * dx + dy * dy;
      if (distSq < minDistSq) {
        minDistSq = distSq;
        nearest = i;
      }
    }
    return nearest;
  }

  /// 「ゴールからの絶対残距離」(0=ゴール, raceDistance=発走, baseLapDistanceを
  /// 超えてもよい)を、本線上 or シュート内の生ピクセル座標に変換する。
  /// シュート判定・1周分のmodulo処理はこの内部でのみ行う。
  Offset positionForRaceDistance(
    double distanceFromGoal, {
    required double raceDistance,
    CourseApproach? approach,
  }) {
    final lap = cumulativeDistances.last;
    if (approach != null) {
      final mergeDist = raceDistance - approach.distance;
      if (distanceFromGoal > mergeDist) {
        final mergePt = positionAtDistance(_wrap(mergeDist, lap));
        final rad = approach.angle * (math.pi / 180.0);
        final pxLen = approach.distance * pixelsPerMeter;
        final startPt = mergePt + Offset(math.cos(rad), math.sin(rad)) * pxLen;
        final ratio =
            ((distanceFromGoal - mergeDist) / approach.distance).clamp(0.0, 1.0);
        return Offset.lerp(mergePt, startPt, ratio)!;
      }
    }
    return positionAtDistance(_wrap(distanceFromGoal, lap));
  }

  /// 接線・位置平滑化に用いる前後方向のサンプリング窓幅(m)。
  /// edgePoints(画像トレース由来)に含まれる局所的なジグザグ(階段状ノイズ)を
  /// 平均化し、距離変化に対して滑らかに変化する接線方向・位置を得るための窓幅。
  /// スタートライン法線・各馬のlateralOffset用normal([tangentAt])で使用する。
  static const double _tangentWindowMeters = 20.0;

  /// [_tangentWindowMeters]用の窓内サンプリング点数。
  static const int _tangentSampleCount = 11;

  /// メインカメラの向き・基準位置([cameraTangentAt]・
  /// [smoothedPositionForRaceDistance])専用の、より大きいサンプリング窓幅(m)。
  /// レンダリング(走路帯・黄色トレース・各馬の横位置)には使わず、カメラの
  /// 向き・基準位置のみをコース全体の大まかな進行方向に追従させ、局所的な
  /// ノイズによるカメラ自体の振動(画面全体の水平方向の揺れ)を抑える。
  static const double _cameraWindowMeters = 60.0;

  /// [_cameraWindowMeters]用の窓内サンプリング点数。
  static const int _cameraSampleCount = 21;

  /// distanceFromGoal=d周辺の窓内サンプル点に最小二乗直線(全回帰/PCA)を
  /// フィットし、その向き(tangent)と、positionAtDistance(d)をその直線へ
  /// 正射影した点(smoothedPosition)を返す。
  /// [_fitAt]の共通処理。
  ({Offset tangent, Offset smoothedPosition}) _localFit(
    double d,
    double lap,
    double windowMeters,
    int sampleCount,
  ) {
    final half = math.min(windowMeters / 2, lap / 4);

    final points = <Offset>[];
    for (int k = 0; k < sampleCount; k++) {
      final t = -half + (2 * half) * k / (sampleCount - 1);
      points.add(positionAtDistance(_wrap(d + t, lap)));
    }

    double meanX = 0, meanY = 0;
    for (final p in points) {
      meanX += p.dx;
      meanY += p.dy;
    }
    meanX /= points.length;
    meanY /= points.length;
    final centroid = Offset(meanX, meanY);

    double sxx = 0, sxy = 0, syy = 0;
    for (final p in points) {
      final dx = p.dx - meanX;
      final dy = p.dy - meanY;
      sxx += dx * dx;
      sxy += dx * dy;
      syy += dy * dy;
    }

    if (sxx + syy < 1e-9) {
      return (tangent: const Offset(1, 0), smoothedPosition: centroid);
    }

    // 共分散行列の主成分方向(=最小二乗直線の向き)。
    final angle = 0.5 * math.atan2(2 * sxy, sxx - syy);
    var tangent = Offset(math.cos(angle), math.sin(angle));

    // 主成分方向は符号が不定(±)なので、ゴールから離れる方向
    // (points.first -> points.last)に揃える。
    final overall = points.last - points.first;
    if (tangent.dx * overall.dx + tangent.dy * overall.dy < 0) {
      tangent = -tangent;
    }

    // positionAtDistance(d)をフィット直線(centroidを通りtangent方向)へ正射影し、
    // ノイズを除いた「平滑化された位置」とする。
    final actual = positionAtDistance(d);
    final rel = actual - centroid;
    final proj = rel.dx * tangent.dx + rel.dy * tangent.dy;
    final smoothedPosition = centroid + tangent * proj;

    return (tangent: tangent, smoothedPosition: smoothedPosition);
  }

  /// distanceFromGoal=d周辺の接線・平滑化位置を求める。シュート内
  /// (distanceFromGoal > raceDistance - approach.distance)の場合は、
  /// approachの方向ベクトルと[positionForRaceDistance]をそのまま返す
  /// (シュートは直線のため平滑化の必要がない)。
  /// [tangentAt]・[cameraTangentAt]・[smoothedPositionForRaceDistance]の共通処理。
  ({Offset tangent, Offset smoothedPosition}) _fitAt(
    double distanceFromGoal, {
    required double raceDistance,
    CourseApproach? approach,
    required double windowMeters,
    required int sampleCount,
  }) {
    final lap = cumulativeDistances.last;
    if (approach != null) {
      final mergeDist = raceDistance - approach.distance;
      if (distanceFromGoal > mergeDist) {
        final rad = approach.angle * (math.pi / 180.0);
        final tangent = Offset(math.cos(rad), math.sin(rad));
        final position = positionForRaceDistance(
          distanceFromGoal,
          raceDistance: raceDistance,
          approach: approach,
        );
        return (tangent: tangent, smoothedPosition: position);
      }
    }
    final d = _wrap(distanceFromGoal, lap);
    return _localFit(d, lap, windowMeters, sampleCount);
  }

  /// distanceFromGoal地点での進行方向に沿った接線ベクトル（正規化、ゴールから
  /// 離れる方向）を返す。スタートライン法線・各馬のlateralOffset用normalに
  /// 使用する([_tangentWindowMeters]/[_tangentSampleCount]の窓でフィット)。
  ///
  /// edgePoints隣接2点の差分ではなく、[_localFit]による窓内最小二乗直線
  /// フィットの向きを使う。2点の弦よりも多数点の平均的な傾きを使うため、
  /// 個々の点のノイズに対する感度が下がり、distanceFromGoalの変化に対して
  /// 接線方向が滑らかに(振動せず)変化する。
  Offset tangentAt(
    double distanceFromGoal, {
    required double raceDistance,
    CourseApproach? approach,
  }) {
    return _fitAt(
      distanceFromGoal,
      raceDistance: raceDistance,
      approach: approach,
      windowMeters: _tangentWindowMeters,
      sampleCount: _tangentSampleCount,
    ).tangent;
  }

  /// メインカメラの回転角用の接線ベクトル（正規化、ゴールから離れる方向）を
  /// 返す。[_cameraWindowMeters]/[_cameraSampleCount]のより大きい窓でフィット
  /// することで、レンダリング(走路帯・黄色トレース・各馬の横位置)には使わず、
  /// カメラの向きだけをコース全体の大まかな進行方向に追従させ、局所的なノイズ
  /// によるカメラ自体の振動を抑える。
  Offset cameraTangentAt(
    double distanceFromGoal, {
    required double raceDistance,
    CourseApproach? approach,
  }) {
    return _fitAt(
      distanceFromGoal,
      raceDistance: raceDistance,
      approach: approach,
      windowMeters: _cameraWindowMeters,
      sampleCount: _cameraSampleCount,
    ).tangent;
  }

  /// メインカメラの基準点(refPos)用に、位置のジグザグノイズを平滑化した座標を
  /// 返す。[cameraTangentAt]と同じ[_cameraWindowMeters]/[_cameraSampleCount]の
  /// 窓内最小二乗直線への正射影を使う。シュート内は[positionForRaceDistance]と
  /// 同じ値を返す(シュートは直線のため平滑化の必要がない)。
  ///
  /// `positionAtDistance`/`positionForRaceDistance`自体は変更しないため、
  /// ミニマップの軌跡・現在位置表示など他の利用箇所には影響しない。
  Offset smoothedPositionForRaceDistance(
    double distanceFromGoal, {
    required double raceDistance,
    CourseApproach? approach,
  }) {
    return _fitAt(
      distanceFromGoal,
      raceDistance: raceDistance,
      approach: approach,
      windowMeters: _cameraWindowMeters,
      sampleCount: _cameraSampleCount,
    ).smoothedPosition;
  }

  /// edgePoints全体を[_localFit]（接線用と同じ20m窓）の最小二乗直線への
  /// 正射影で平滑化した座標列を返す。内ラチのオーバーレイ線描画専用
  /// （positionAtDistance等が参照する元データには影響しない）。
  List<Offset> smoothedEdgePoints() {
    final lap = cumulativeDistances.last;
    return [
      for (final d in cumulativeDistances)
        _localFit(d, lap, _tangentWindowMeters, _tangentSampleCount)
            .smoothedPosition,
    ];
  }

  double _wrap(double d, double lap) {
    if (lap <= 0) return d;
    final r = d % lap;
    return r < 0 ? r + lap : r;
  }
}

/// 画像の生ピクセル座標系 -> キャンバス座標系 への変換パラメータ（BoxFit.contain相当）
class ImageTransform {
  final double scale;
  final Offset offset;
  const ImageTransform(this.scale, this.offset);

  Offset apply(Offset rawPixel) => Offset(
        offset.dx + rawPixel.dx * scale,
        offset.dy + rawPixel.dy * scale,
      );

  /// 画像の生ピクセル座標系 -> キャンバス座標系 への変換パラメータを計算する（BoxFit.contain相当）
  static ImageTransform compute(Size canvasSize, CourseImageInfo imageInfo) {
    final scaleX = canvasSize.width / imageInfo.width;
    final scaleY = canvasSize.height / imageInfo.height;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final drawWidth = imageInfo.width * scale;
    final drawHeight = imageInfo.height * scale;
    final dx = (canvasSize.width - drawWidth) / 2;
    final dy = (canvasSize.height - drawHeight) / 2;

    return ImageTransform(scale, Offset(dx, dy));
  }
}

/// 背景GIF画像の実ピクセルサイズ（実行時にデコードして取得）
class CourseImageInfo {
  final double width;
  final double height;
  const CourseImageInfo(this.width, this.height);
}

/// 平面図描画に必要な情報一式（座標データ＋画像サイズ）
class CourseDiagramData {
  final String imageAsset;
  final CourseImageInfo imageInfo;
  final CourseEdgeCoordsData coords;

  const CourseDiagramData({
    required this.imageAsset,
    required this.imageInfo,
    required this.coords,
  });
}

/// venueCode -> アセットファイル名スラッグ の対応表
/// （lib/db/elevations/配下の既存ディレクトリ名と同一の英語表記）
class CourseVenueNames {
  static const Map<String, String> _slugs = {
    '01': 'sapporo',
    '02': 'hakodate',
    '03': 'fukushima',
    '04': 'niigata',
    '05': 'tokyo',
    '06': 'nakayama',
    '07': 'chukyo',
    '08': 'kyoto',
    '09': 'hanshin',
    '10': 'kokura',
  };

  static String? slugFor(String venueCode) => _slugs[venueCode];
}
