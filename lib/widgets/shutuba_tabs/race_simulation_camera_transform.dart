// lib/widgets/shutuba_tabs/race_simulation_camera_transform.dart
// [改修] 展開予想アニメーション メインカメラビュー: コース座標基準の固定カメラへ刷新 (v.2.1)

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/painting.dart' show MatrixUtils;
import 'package:vector_math/vector_math_64.dart' show Matrix4;
import 'package:hetaumakeiba_v2/models/course_diagram_model.dart';
import 'package:hetaumakeiba_v2/models/elevation_model.dart';

/// メインカメラビュー用の視点変換行列。
///
/// 表示画面のアスペクト比16:9を約80m(横):50m(縦)の縮尺として固定し、
/// 「現在位置」([refPos]/[refDistanceFromGoal]=先頭馬のdistanceFromGoalおよび
/// その地点を位置のジグザグノイズを平滑化した座標)を画面中央・上端から10%(=5m)
/// の位置に固定する。画面上端からの5m分が内ラチの外側(インフィールド)の空白領域となる。
/// スケール・アンカー位置はフレーム間で変動しない固定値のため、ジッターは発生しない。
class RaceSimulationCameraTransform {
  final Matrix4 matrix;

  const RaceSimulationCameraTransform(this.matrix);

  /// 生ピクセル座標pをカメラ変換後のキャンバス座標へ変換する。
  Offset apply(Offset p) => MatrixUtils.transformPoint(matrix, p);

  /// メインカメラの画面縦幅(=走路の幅方向)に表示したい現実の距離(m)。
  /// [修正] 改善Phase10 50m相当ではマーカー(直径18px)が馬4.5頭分の大きさになり、
  /// 馬群が団子に見えるため30m相当に変更。画面横幅は約60m相当になる。
  /// Layer2からも同じ値を参照するため公開する (v.2026.9.18+26091802)
  static const double viewportHeightMeters = 30.0;

  /// 内ラチ(コース基準線=edgePoints上の点)を画面上端からこの比率の位置に固定する。
  /// (3m / 30m = 0.1 → 画面上端から3m分を内ラチ外側の空白領域とする)
  static const double _railOffsetRatio = 0.1;

  /// [追加] 改善Phase12 先頭馬を画面の横方向どこに固定するかの比率。
  /// 進行方向側(右回りなら左)から35%の位置に置き、後続に約65%分のスペースを残す。
  /// Layer2も同じ値を参照して描画基準を揃える (v.2026.9.18+26091802)
  static const double leaderAnchorRatio = 0.35;

  /// [追加] 改善Phase12 先頭馬を固定する画面X座標を返す。
  /// 右回りは進行方向が画面左なので左から35%、左回りは右から35%(=左から65%)に置く
  /// (v.2026.9.18+26091802)
  static double anchorXFor({
    required Size viewportSize,
    required bool isLeftHanded,
  }) {
    final ratio = isLeftHanded ? (1.0 - leaderAnchorRatio) : leaderAnchorRatio;
    return viewportSize.width * ratio;
  }

  /// `viewportHeightMeters`に基づく固定スケール値(px/raw-px)を返す。
  /// オーバーレイ線の太さなど、カメラ変換と同じスケールを参照したい描画で使用する。
  static double scaleFor({
    required Size viewportSize,
    required CourseEdgeCoordsData coords,
  }) {
    return viewportSize.height / (viewportHeightMeters * coords.pixelsPerMeter);
  }

  /// [refDistanceFromGoal]はミニマップの光るドット
  /// ([RaceSimulationMinimapPainter])と同一の値（先頭馬のdistanceFromGoal）を
  /// 渡すこと。[refPos]は[CourseEdgeCoordsData.smoothedPositionForRaceDistance]
  /// で位置のジグザグノイズを平滑化した座標を渡す。これにより、メインカメラ
  /// ビューの表示中心はミニマップの現在位置表示とほぼ同じコース上の地点を
  /// 指しつつ、画面全体の水平方向の微振動を抑える。
  static RaceSimulationCameraTransform compute({
    required Offset refPos,
    required double refDistanceFromGoal,
    required Size viewportSize,
    required bool isLeftHanded,
    required CourseEdgeCoordsData coords,
    required double raceDistance,
    List<CourseApproach>? approach,
  }) {
    // 1. 基準点での進行方向(ゴールに向かう方向 = cameraTangentAtの逆方向)を取得
    final tangent = coords.cameraTangentAt(
      refDistanceFromGoal,
      raceDistance: raceDistance,
      approach: approach,
    );
    final travelDir = -tangent;

    // 2. 画面上の目標方向: 右回り→左向き(-1,0)、左回り/直線→右向き(1,0)
    final desiredDir = isLeftHanded ? const Offset(1, 0) : const Offset(-1, 0);

    // 3. travelDirをdesiredDirに一致させる回転角を求める
    final rotationAngle = math.atan2(desiredDir.dy, desiredDir.dx) -
        math.atan2(travelDir.dy, travelDir.dx);

    // 4. 固定スケール(viewportSize.heightがviewportHeightMetersメートル相当になる)
    final scale = scaleFor(viewportSize: viewportSize, coords: coords);

    // 5. 基準点(refPos)を画面の横方向leaderAnchorRatioの位置・上端から10%(縦)に固定する
    // [修正] 改善Phase12 中央(50%)では後続を表示するスペースが足りないため、
    // 進行方向側35%へ移動する (v.2026.9.18+26091802)
    final anchorX = anchorXFor(
      viewportSize: viewportSize,
      isLeftHanded: isLeftHanded,
    );
    final targetRailY = viewportSize.height * _railOffsetRatio;

    // 6. Matrix4合成: refPosを原点に → 回転 → 固定スケール → (anchorX, targetRailY)へ平行移動
    final matrix = Matrix4.identity()
      ..translateByDouble(anchorX, targetRailY, 0.0, 1.0)
      ..scaleByDouble(scale, scale, 1.0, 1.0)
      ..rotateZ(rotationAngle)
      ..translateByDouble(-refPos.dx, -refPos.dy, 0.0, 1.0);

    return RaceSimulationCameraTransform(matrix);
  }
}
