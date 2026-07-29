// lib/logic/analysis/speed_index_constants.dart
// [自動生成] tools/speed_index_fit.py により生成。手で編集しないこと。
// 案C: race_results のオフライン重回帰による基準タイム定数(クラス中立=OP基準)。

class SpeedIndexConstants {
  SpeedIndexConstants._();
  static const double kBaseIndex = 80.0;

  // ---- 芝 (N=1869, 残差SD=1.38s) ----
  static const double turfConst = 106.539;
  static const double turfDc = 6.5224;
  static const double turfDc2 = 0.00775;
  static const double turfYearTrend = -0.0999;
  static const Map<String, double> turfVenueOffset = {'中京': 0.317, '中山': 0.832, '京都': 0.527, '函館': 0.821, '小倉': 0.668, '新潟': 0.815, '札幌': 1.604, '東京': 0.0, '福島': 1.472, '阪神': 0.215};
  static const Map<String, double> turfCondOffset = {'不良': 3.796, '稍重': 0.933, '良': 0.0, '重': 1.615};
  static const List<List<num>> turfDistCoef = [[0, 1400, 10.59], [1400, 1800, 10.04], [1800, 2200, 8.13], [2200, 9999, 4.26]];

  // ---- ダ (N=1081, 残差SD=0.89s) ----
  static const double dirtConst = 110.104;
  static const double dirtDc = 6.8581;
  static const double dirtDc2 = -0.00798;
  static const double dirtYearTrend = -0.0689;
  static const Map<String, double> dirtVenueOffset = {'中京': 1.897, '中山': 2.498, '京都': 1.578, '函館': 0.929, '小倉': 1.083, '新潟': 2.02, '札幌': 1.621, '東京': 0.0, '福島': 1.427, '阪神': 1.961};
  static const Map<String, double> dirtCondOffset = {'不良': -1.862, '稍重': -0.384, '良': 0.0, '重': -1.471};
  static const List<List<num>> dirtDistCoef = [[0, 1400, 8.22], [1400, 1800, 11.64], [1800, 9999, 11.16]];
}
