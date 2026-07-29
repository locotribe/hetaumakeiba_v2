# スピード指数 確定定数（案C：オフライン重回帰）

生成日: 2026-07-29
生成元: `tools/speed_index_fit.py`（race_results を重回帰）
再生成: `python3 tools/speed_index_fit.py --db <DBパス> --out lib/logic/analysis/speed_index_constants.dart`
データが増えたら再実行して定数を更新する運用（高速馬場化で徐々に古くなるため）。

## 計算式

```
D = (距離m − 1800) / 100
基準タイム = const + dc·D + dc2·D² + yearTrend·(走った年 − 2023) + 競馬場補正 + 馬場補正
            ※クラスは基準(OP)=中立。基準タイムにクラス補正は加えない（絶対能力を測るため）
指数 = (基準タイム − 実走タイム) × 距離係数(距離帯) + 80
```

- クラス中立基準のため、勝っても絶対タイムが遅い下級戦の馬は低指数、上位クラスの速い走は高指数になり、**絶対能力**を反映する。
- 全て固定定数なので **DB蓄積量に依存せず、新規/既存ユーザーで同一指数**が出る。

## 検証結果

- 係数はすべて競馬の常識と一致：クラス順序（G1最速〜新馬最遅、芝で約4秒差）、競馬場差（東京最速〜札幌+1.6s）、
  馬場補正のサーフェス依存（芝は悪化で遅い／ダートは湿ると速い）、芝の年トレンド −0.10s/年（高速馬場化）。
- 1〜3着馬 約2,950件の指数分布：p5=52・中央=78・p95=97（狙いの40〜120に収まる）。
- 同一コースでの挙動例（東京芝1800）：G2の走→89.2、新馬の走→69.0（絶対能力を反映）。

## 生成された定数（Dart）

```dart
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
```

## 注意・限界

- 障害(障)は対象外。芝/ダートのみ。
- 定数は固定のため、高速馬場化で徐々にズレる → 定期的に `tools/speed_index_fit.py` を再実行して更新。
- 京都改修(2020-23)の断層は現状は年トレンドで近似。将来、競馬場ダミーを「京都_改修前/後」に分割するとより正確。
- 馬場状態は4段階の離散補正。将来クッション値・含水率(track_conditions)の連続量へ置換予定(フェーズ7)。
- 馬場状態キーは「良/稍重/重/不良」。horse_performance.track_condition が「稍/重/不」等の略記の場合は正規化が必要。
