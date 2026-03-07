// lib/utils/track_constants.dart

class TrackConstants {
  /// クッション値の評価を返すメソッド
  static String getCushionEvaluation(double cushionValue) {
    if (cushionValue >= 12.0) return '硬め';
    if (cushionValue >= 10.0) return 'やや硬め';
    if (cushionValue >= 8.0) return '標準';
    if (cushionValue >= 7.0) return 'やや軟らかめ';
    return '軟らかめ';
  }

  /// 芝コースの含水率閾値 [良の上限, 稍重の上限, 重の上限]
  /// JRAの基準表の重複部分をプログラム判定用に整理した閾値です。
  static const Map<String, List<double>> turfMoistureThresholds = {
    '01': [15.0, 18.0, 21.0], // 札幌
    '02': [15.0, 18.0, 21.0], // 函館
    '03': [15.0, 17.0, 19.0], // 福島
    '04': [15.0, 17.0, 19.0], // 新潟
    '05': [19.0, 21.0, 23.0], // 東京
    '06': [13.0, 15.0, 18.0], // 中山
    '07': [14.0, 16.0, 17.0], // 中京
    '08': [13.0, 14.0, 16.0], // 京都
    '09': [14.0, 16.0, 18.0], // 阪神
    '10': [10.0, 12.0, 14.0], // 小倉
  };

  /// ダートコースの含水率閾値（全場共通） [良の上限, 稍重の上限, 重の上限]
  static const List<double> dirtMoistureThresholds = [9.0, 13.0, 16.0];

  /// 含水率から馬場状態（文字列）を判定するメソッド
  static String evaluateTrackCondition(String venueCode, String trackType, double moisture) {
    List<double>? thresholds;

    if (trackType.contains('ダ') || trackType.contains('ダート')) {
      thresholds = dirtMoistureThresholds;
    } else {
      thresholds = turfMoistureThresholds[venueCode];
    }

    if (thresholds == null) return '不明';

    if (moisture <= thresholds[0]) return '良';
    if (moisture <= thresholds[1]) return '稍重';
    if (moisture <= thresholds[2]) return '重';
    return '不良';
  }

  /// 対象コースの「良馬場の上限値（%）」を取得するメソッド（水分指数 Moisture Index 計算の分母用）
  static double getGoodMoistureLimit(String venueCode, String trackType) {
    if (trackType.contains('ダ') || trackType.contains('ダート')) {
      return dirtMoistureThresholds[0]; // ダートは9.0
    } else {
      final thresholds = turfMoistureThresholds[venueCode];
      return thresholds != null ? thresholds[0] : 15.0; // データがない場合は標準的な15.0を返す
    }
  }
}