// lib/models/elevation_model.dart

class ElevationPoint {
  final double distance;
  final double elevation;
  const ElevationPoint({required this.distance, required this.elevation});
}

class CourseSection {
  final String name;
  final double startDistance;
  final double endDistance;
  const CourseSection({required this.name, required this.startDistance, required this.endDistance});
}

class CourseApproach {
  final double angle;
  final double distance;
  const CourseApproach({required this.angle, required this.distance});
}

class TrackBaseData {
  final String venueCode;
  final String trackType;
  final double lapDistance;
  final List<ElevationPoint> points;
  final List<CourseSection> sections;

  const TrackBaseData({
    required this.venueCode,
    required this.trackType,
    required this.lapDistance,
    required this.points,
    required this.sections,
  });

  bool get isLeftHanded {
    return venueCode == '04' || venueCode == '05' || venueCode == '07';
  }

  // [修正] 標高取得ロジックに線形補間（Linear Interpolation）を追加し、階段状のグラフを滑らかにする (v.1.4)
  double getElevationAt(double distance) {
    if (points.isEmpty) return 0.0;

    // データ範囲外の場合は両端の値を返す
    if (distance <= points.first.distance) return points.first.elevation;
    if (distance >= points.last.distance) return points.last.elevation;

    // 前後のポイントを探して線形補間を計算
    for (int i = 0; i < points.length - 1; i++) {
      if (distance >= points[i].distance && distance <= points[i + 1].distance) {
        final p1 = points[i];
        final p2 = points[i + 1];
        if (p1.distance == p2.distance) return p1.elevation; // ゼロ除算防止

        // 2点間の距離の割合（0.0 ~ 1.0）を計算
        final ratio = (distance - p1.distance) / (p2.distance - p1.distance);
        // 標高の差分に割合を掛けて補間値を算出
        return p1.elevation + (p2.elevation - p1.elevation) * ratio;
      }
    }
    return points.last.elevation;
  }
}

class RaceCourseData {
  final TrackBaseData baseData;
  final int raceDistance;
  final List<CourseSection> sections;
  final List<CourseApproach>? approachPath;

  const RaceCourseData({
    required this.baseData,
    required this.raceDistance,
    required this.sections,
    this.approachPath,
  });

  bool get isLeftHanded => baseData.isLeftHanded;
  String get venueCode => baseData.venueCode;
}