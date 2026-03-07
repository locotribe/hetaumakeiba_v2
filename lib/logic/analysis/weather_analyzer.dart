// lib/logic/analysis/weather_analyzer.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/utils/track_constants.dart';

class WeatherInsight {
  final String label;
  final String description;
  final Color color;
  final String value;

  WeatherInsight({
    required this.label,
    required this.description,
    required this.color,
    required this.value,
  });
}

class WeatherAnalyzer {
  /// WMO天気コードを日本語に変換 (WMO準拠)
  static String getWeatherText(int code) {
    if (code == 0) return '晴れ';
    if (code >= 1 && code <= 3) return '曇り';
    if (code >= 45 && code <= 48) return '霧';
    if (code >= 51 && code <= 67) return '雨';
    if (code >= 71 && code <= 77) return '雪';
    if (code >= 80 && code <= 82) return 'にわか雨';
    if (code >= 85 && code <= 86) return 'にわか雪';
    if (code >= 95 && code <= 99) return '雷雨';
    return '不明';
  }

  /// 1. 馬場状態の回復・悪化を予測するデータ
  static WeatherInsight analyzeTrackRecovery(double radiation, double evap) {
    String desc = "標準的な馬場の乾燥条件です。";
    Color color = Colors.grey;
    if (radiation > 500) {
      desc = "強い日射により馬場表面の乾燥が非常に早い状態です。";
      color = Colors.orange;
    } else if (radiation < 150 && radiation > 0) {
      desc = "日射が弱く、降水があった場合の馬場回復には時間がかかります。";
      color = Colors.blueGrey;
    }
    return WeatherInsight(
      label: "馬場回復・悪化予測",
      value: "${radiation.toStringAsFixed(0)} W/m²",
      description: desc,
      color: color,
    );
  }

  /// 2. 馬のスタミナと「隠れた暑さ」
  static WeatherInsight analyzeHorseStamina(double apparentTemp, double humidity) {
    String desc = "馬にとって比較的過ごしやすい気候条件です。";
    Color color = Colors.green;
    if (apparentTemp > 30 || humidity > 70) {
      desc = "体感温度が高く、蒸し暑さにより発汗やスタミナ消耗の恐れがあります。";
      color = Colors.red;
    }
    return WeatherInsight(
      label: "馬のスタミナ負荷",
      value: "体感 ${apparentTemp.toStringAsFixed(1)}℃",
      description: desc,
      color: color,
    );
  }

  /// 3. レース展開への影響（風の不確定要素）
  static WeatherInsight analyzeRaceRisk(double gusts, double visibility) {
    String desc = "気象条件による展開の紛れは少ない見込みです。";
    Color color = Colors.blue;
    if (gusts > 10) {
      desc = "突風の恐れあり。物音に敏感な馬や直線の進路取りに影響する可能性があります。";
      color = Colors.deepOrange;
    } else if (visibility < 5) {
      desc = "視界不良。馬群の距離感や進路確保に影響を与える可能性があります。";
      color = Colors.purple;
    }
    return WeatherInsight(
      label: "展開・波乱要因",
      value: "最大風速 ${gusts.toStringAsFixed(1)}m/s",
      description: desc,
      color: color,
    );
  }

  /// 4. 土壌水分量（究極の馬場指数）
  static WeatherInsight analyzeSoilMoisture(double moisture) {
    return WeatherInsight(
      label: "推定地中水分量",
      value: "${(moisture * 100).toStringAsFixed(1)}%",
      description: "地表下の水分量です。JRA発表の含水率と併せて馬場の重さを判断してください。",
      color: Colors.brown,
    );
  }

  /// 5. キャッシュデータ(前回)と最新データ(今回)を比較・判定する動的馬場シミュレーション
  static List<WeatherInsight> analyzeTrackConditionInsights({
    required String venueCode,
    required String trackType,
    dynamic currentRecord, // 最新のTrackConditionRecord
    dynamic cachedRecord,  // 画面にキャッシュされていた前回のTrackConditionRecord
    required double expectedPrecipitation,
    required double expectedRadiation,
    double? expectedTemp,
    double? expectedSoilMoisture,
  }) {
    if (currentRecord == null) {
      return [
        WeatherInsight(
          label: "複合馬場予測",
          value: "データ待機中",
          description: "JRA公式データが取得でき次第、発走時刻の馬場シミュレーションを行います。",
          color: Colors.grey,
        )
      ];
    }

    final bool isDirt = trackType.contains('ダ') || trackType.contains('ダート');
    List<WeatherInsight> results = [];

    // 内部計算用ヘルパー関数
    _SimulationResult? buildInsight(dynamic record, String labelPrefix, String timeLabel) {
      final double? baseMoisture = isDirt ? record.moistureDirtGoal : record.moistureTurfGoal;
      final double? baseCushion = record.cushionValue;

      if (baseMoisture == null) return null;

      double cWet = baseMoisture > 15.0 ? 1.2 : 0.8;
      double cDry = 0.005;

      double addedMoisture = expectedPrecipitation * cWet;
      double reducedMoisture = expectedRadiation * cDry;
      double soilPercent = (expectedSoilMoisture ?? 0.15) * 100;
      double soilAdjustment = (soilPercent - 15.0) * 0.05;

      double predictedMoisture = baseMoisture + addedMoisture - reducedMoisture + soilAdjustment;

      double minLimit = isDirt ? 2.0 : 8.0;
      double maxLimit = 25.0;
      bool hitLimit = false;

      if (predictedMoisture < minLimit) { predictedMoisture = minLimit; hitLimit = true; }
      if (predictedMoisture > maxLimit) { predictedMoisture = maxLimit; hitLimit = true; }

      double goodLimit = TrackConstants.getGoodMoistureLimit(venueCode, trackType);
      double moistureIndex = predictedMoisture / goodLimit;

      double? predictedCushion = baseCushion;
      if (!isDirt && baseCushion != null) {
        if (expectedRadiation > 300 && (expectedTemp ?? 15.0) > 20.0 && expectedPrecipitation == 0) {
          predictedCushion = baseCushion + 0.3;
        } else if (expectedPrecipitation > 1.0) {
          predictedCushion = baseCushion - 0.4;
        }
      }

      String insightLabel = "";
      String insightDesc = "";
      Color insightColor = Colors.grey;

      if (isDirt) {
        if (predictedMoisture <= 9.0) { insightLabel = "標準ダート (パサパサ)"; insightDesc = "水分が抜けきった標準的なダート。スタミナと力通りの決着になりやすいです。"; insightColor = Colors.brown; }
        else if (predictedMoisture <= 13.0) { insightLabel = "時計短縮ダート (稍重)"; insightDesc = "適度に水分を含み砂が締まって時計が出やすい状態。逃げ・先行馬に有利です。"; insightColor = Colors.orange; }
        else { insightLabel = "泥濘ダート (重・不良)"; insightDesc = "水分が浮く脚抜きが良い馬場。スピード能力と前走道悪実績が問われます。"; insightColor = Colors.blue; }
      } else {
        double cVal = predictedCushion ?? 8.5;
        if (moistureIndex <= 0.8 && cVal >= 10.5) { insightLabel = "超高速 (高速良)"; insightDesc = "乾燥が進み反発力が非常に強い状態。持ち時計重視、内枠・先行馬が圧倒的に有利。"; insightColor = Colors.redAccent; }
        else if (moistureIndex >= 1.3 && expectedPrecipitation > 0) { insightLabel = "泥濘 (消耗戦)"; insightDesc = "極端に時計が掛かる馬場。適性重視、前走重馬場実績に注目。"; insightColor = Colors.indigo; }
        else if (moistureIndex >= 1.1 && cVal >= 9.0) { insightLabel = "高速稍重 (外差し)"; insightDesc = "水分はあるが路盤は締まっている。表面が滑りやすく、外から勢いをつけた差しが届く。"; insightColor = Colors.purple; }
        else if (moistureIndex >= 1.0 && cVal <= 8.0) { insightLabel = "タフ (重い良)"; insightDesc = "水分を含みクッションは軟らかめ。時計が掛かり、パワーとスタミナを要する。"; insightColor = Colors.teal; }
        else { insightLabel = "標準 (乾いた良)"; insightDesc = "JRA基準通りの良好なコンディション。実力通りの決着になりやすい。"; insightColor = Colors.green; }
      }

      String limitNote = hitLimit ? " (※限界値補正あり)" : "";
      String cushionText = !isDirt && predictedCushion != null ? "・予測クッション値: ${predictedCushion.toStringAsFixed(1)}\n" : "";
      String soilAdjSign = soilAdjustment >= 0 ? "+" : "";

      String formulaText = "【予測シミュレーションの根拠】\n"
          "・起点 ($timeLabel公式): ${baseMoisture}%\n"
          "・加水 (降水予報 ${expectedPrecipitation}mm): +${addedMoisture.toStringAsFixed(1)}%\n"
          "・乾燥 (日射・風予報): -${reducedMoisture.toStringAsFixed(1)}%\n"
          "・地盤補正 (気象API ${soilPercent.toStringAsFixed(1)}%): $soilAdjSign${soilAdjustment.toStringAsFixed(1)}%\n"
          "➡ 予測含水率: ${predictedMoisture.toStringAsFixed(1)}%$limitNote\n"
          "$cushionText";

      return _SimulationResult(
          predictedMoisture,
          WeatherInsight(
            label: "$labelPrefix$insightLabel",
            value: "予測含水率: ${predictedMoisture.toStringAsFixed(1)}%",
            description: "$insightDesc\n\n$formulaText",
            color: insightColor,
          )
      );
    }

    // ① キャッシュデータ（古いデータ）があれば「前日予測」として表示
    _SimulationResult? prevResult;
    if (cachedRecord != null) {
      prevResult = buildInsight(cachedRecord, "[前回予測] ", "前回");
      if (prevResult != null) results.add(prevResult.insight);
    }

    // ② 最新データで「今回確定版」を生成し、ギャップがあればアラートを結合
    _SimulationResult? currentResult = buildInsight(currentRecord, cachedRecord != null ? "🎯[今回確定] " : "", "今回");
    if (currentResult != null) {
      if (prevResult != null) {
        double diff = currentResult.predictedMoisture - prevResult.predictedMoisture;
        String warning = "";

        // ±1.5%以上のズレがあればアラートを追加
        if (diff >= 1.5) {
          warning = "\n\n⚠️【乖離アラート】前回のシミュレーションより含水率が ${diff.toStringAsFixed(1)}% 上振れしています。未明の雨やJRAの散水作業の影響により、想定より時計が掛かる馬場になっています。";
        } else if (diff <= -1.5) {
          warning = "\n\n⚠️【乖離アラート】前回のシミュレーションより含水率が ${diff.abs().toStringAsFixed(1)}% 下振れしています。想定以上に乾燥が進んでおり、時計が速くなる可能性があります。";
        }

        if (warning.isNotEmpty) {
          final old = currentResult.insight;
          results.add(WeatherInsight(
            label: old.label,
            value: old.value,
            description: old.description + warning,
            color: old.color,
          ));
        } else {
          results.add(currentResult.insight);
        }
      } else {
        results.add(currentResult.insight);
      }
    }

    return results;
  }
}

// 内部計算の戻り値用クラス
class _SimulationResult {
  final double predictedMoisture;
  final WeatherInsight insight;
  _SimulationResult(this.predictedMoisture, this.insight);
}