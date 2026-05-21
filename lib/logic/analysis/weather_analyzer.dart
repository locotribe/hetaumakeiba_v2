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

class JraConditionPrediction {
  final String conditionText;
  final String leaningText;
  final Color color;
  JraConditionPrediction({required this.conditionText, required this.leaningText, required this.color});
}

class WeatherAnalysisResult {
  final List<WeatherInsight> insights;
  final JraConditionPrediction? jraPrediction;
  WeatherAnalysisResult(this.insights, this.jraPrediction);
}

class WeatherAnalyzer {
  static final Map<String, Map<String, List<double>>> _jraTurfBounds = {
    '札幌': {'良': [0, 15], '稍重': [14, 18], '重': [17, 21], '不良': [20, 100]},
    '函館': {'良': [0, 15], '稍重': [14, 18], '重': [17, 21], '不良': [20, 100]},
    '福島': {'良': [0, 15], '稍重': [13, 17], '重': [15, 19], '不良': [17, 100]},
    '新潟': {'良': [0, 15], '稍重': [13, 17], '重': [15, 19], '不良': [17, 100]},
    '中山': {'良': [0, 13], '稍重': [11, 15], '重': [14, 18], '不良': [17, 100]},
    '東京': {'良': [0, 19], '稍重': [17, 21], '重': [18, 23], '不良': [20, 100]},
    '中京': {'良': [0, 14], '稍重': [12, 16], '重': [14, 17], '不良': [16, 100]},
    '京都': {'良': [0, 13], '稍重': [11, 14], '重': [13, 16], '不良': [14, 100]},
    '阪神': {'良': [0, 14], '稍重': [12, 16], '重': [14, 18], '不良': [16, 100]},
    '小倉': {'良': [0, 10], '稍重': [8, 12], '重': [10, 14], '不良': [12, 100]},
  };

  static final Map<String, List<double>> _jraDirtBounds = {
    '良': [0, 9], '稍重': [7, 13], '重': [11, 16], '不良': [14, 100]
  };

  static String getVenueName(String code) {
    const map = {
      '01': '札幌', '02': '函館', '03': '福島', '04': '新潟', '05': '東京',
      '06': '中山', '07': '中京', '08': '京都', '09': '阪神', '10': '小倉'
    };
    return map[code] ?? '東京';
  }

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

  static WeatherInsight analyzeSoilMoisture(double moisture) {
    return WeatherInsight(
      label: "推定地中水分量",
      value: "${(moisture * 100).toStringAsFixed(1)}%",
      description: "地表下の水分量です。JRA発表の含水率と併せて馬場の重さを判断してください。",
      color: Colors.brown,
    );
  }

  static JraConditionPrediction _calculateJraPrediction(
      String venue,
      bool isDirt,
      double moisture,
      double? cushion,
      String trend,
      ) {
    Map<String, List<double>> bounds;
    if (isDirt) {
      bounds = _jraDirtBounds;
    } else {
      String key = _jraTurfBounds.containsKey(venue) ? venue : '東京';
      bounds = _jraTurfBounds[key]!;
    }

    List<String> conditions = ['良', '稍重', '重', '不良'];
    List<String> matched = [];
    for (String c in conditions) {
      if (moisture >= bounds[c]![0] && moisture <= bounds[c]![1]) {
        matched.add(c);
      }
    }

    String baseCondition = '良';
    if (matched.isEmpty) {
      if (moisture < bounds['良']![0]) baseCondition = '良';
      else baseCondition = '不良';
    } else if (matched.length == 1) {
      baseCondition = matched.first;
    } else {
      if (trend == '悪化' || trend == 'フラット') {
        baseCondition = matched.last;
      } else {
        baseCondition = matched.first;
      }
    }

    if (!isDirt && cushion != null) {
      int idx = conditions.indexOf(baseCondition);
      if (cushion >= 9.5 && idx > 0) {
        baseCondition = conditions[idx - 1];
      } else if (cushion < 8.0 && idx < 3) {
        baseCondition = conditions[idx + 1];
      }
    }

    int fIdx = conditions.indexOf(baseCondition);
    String leaning = "";
    double lowerBound = bounds[baseCondition]![0];
    double upperBound = bounds[baseCondition]![1];
    double center = lowerBound == 0 ? upperBound - 2.0 :
    upperBound == 100 ? lowerBound + 2.0 :
    (lowerBound + upperBound) / 2.0;

    bool leansLighter = (fIdx > 0) && (moisture <= bounds[conditions[fIdx - 1]]![1]);
    bool leansHeavier = (fIdx < 3) && (moisture >= bounds[conditions[fIdx + 1]]![0]);

    if (leansLighter && leansHeavier) {
      if (moisture < center) leaning = "(${conditions[fIdx - 1]}寄り)";
      else if (moisture > center) leaning = "(${conditions[fIdx + 1]}寄り)";
    } else if (leansLighter) {
      leaning = "(${conditions[fIdx - 1]}寄り)";
    } else if (leansHeavier) {
      leaning = "(${conditions[fIdx + 1]}寄り)";
    }

    Color c = Colors.green;
    if (baseCondition == '稍重') c = Colors.orange;
    if (baseCondition == '重') c = Colors.brown;
    if (baseCondition == '不良') c = Colors.blue;

    return JraConditionPrediction(
      conditionText: baseCondition,
      leaningText: leaning,
      color: c,
    );
  }

  static WeatherAnalysisResult analyzeTrackConditionInsights({
    required String venueCode,
    required String trackType,
    dynamic currentRecord,
    dynamic cachedRecord,
    required double expectedPrecipitation,
    required double expectedRadiation,
    double? expectedTemp,
    double? expectedSoilMoisture,
    List<dynamic> dailyWeather = const [],
    String? raceDateStr,
  }) {
    if (currentRecord == null) {
      return WeatherAnalysisResult([
        WeatherInsight(
          label: "複合馬場予測",
          value: "データ待機中",
          description: "JRA公式データが取得でき次第、発走時刻の馬場シミュレーションを行います。",
          color: Colors.grey,
        )
      ], null);
    }

    final bool isDirt = trackType.contains('ダ') || trackType.contains('ダート');
    List<WeatherInsight> results = [];

    _SimulationResult? buildInsight(dynamic record, String labelPrefix, String timeLabel) {
      final double? baseMoisture = isDirt ? record.moistureDirtGoal : record.moistureTurfGoal;
      final double? baseCushion = record.cushionValue;

      if (baseMoisture == null) return null;

      double currentMoisture = baseMoisture;
      double intermediatePrecip = 0.0;
      int simulatedDays = 0;

      // [修正] ダート専用の低い加水係数 (v.5.0)
      double cWet = isDirt ? 0.25 : (baseMoisture > 15.0 ? 1.2 : 0.8);
      double cDry = 0.005;
      double goodLimit = TrackConstants.getGoodMoistureLimit(venueCode, trackType);

      if (dailyWeather.isNotEmpty && raceDateStr != null && record.date != null) {
        try {
          DateTime recordDate = DateTime.parse(record.date);
          final rMatch = RegExp(r'(\d{4})[^\d]*(\d{1,2})[^\d]*(\d{1,2})').firstMatch(raceDateStr);
          DateTime rDate = recordDate;
          if (rMatch != null) {
            rDate = DateTime(int.parse(rMatch.group(1)!), int.parse(rMatch.group(2)!), int.parse(rMatch.group(3)!));
          }

          for (var day in dailyWeather) {
            DateTime dDate = DateTime.parse(day['date']);
            if (dDate.isAfter(recordDate) && dDate.isBefore(rDate)) {
              double p = (day['precipitationSum'] as num?)?.toDouble() ?? 0.0;
              double e = (day['evapoTranspiration'] as num?)?.toDouble() ?? 0.0;

              intermediatePrecip += p;
              currentMoisture += (p * cWet) - (e * 0.1);

              double lowerBound = goodLimit * 0.85;
              if (currentMoisture < lowerBound) {
                currentMoisture = lowerBound;
              }
              simulatedDays++;
            }
          }
        } catch (e) {}
      }

      double addedMoisture = expectedPrecipitation * cWet;
      double reducedMoisture = expectedRadiation * cDry;
      double soilPercent = (expectedSoilMoisture ?? 0.15) * 100;
      double soilAdjustment = (soilPercent - 15.0) * 0.05;

      double predictedMoisture = currentMoisture + addedMoisture - reducedMoisture + soilAdjustment;

      double minLimit = isDirt ? 2.0 : 8.0;
      // [修正] ダートの現実的な上限値を設定 (v.5.0)
      double maxLimit = isDirt ? 18.0 : 25.0;
      bool hitLimit = false;

      if (predictedMoisture < minLimit) { predictedMoisture = minLimit; hitLimit = true; }
      if (predictedMoisture > maxLimit) { predictedMoisture = maxLimit; hitLimit = true; }

      double moistureIndex = predictedMoisture / goodLimit;

      double? predictedCushion = baseCushion;
      if (!isDirt && baseCushion != null) {
        if (predictedMoisture > baseMoisture + 2.0) {
          predictedCushion = baseCushion - 0.4;
        } else if (expectedRadiation > 300 && (expectedTemp ?? 15.0) > 20.0 && expectedPrecipitation == 0) {
          predictedCushion = baseCushion + 0.3;
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

      // [修正] ダートの場合は限界値補正アラートを非表示にする (v.5.0)
      String limitNote = hitLimit && !isDirt ? " (※限界値補正あり)" : "";
      String cushionText = !isDirt && predictedCushion != null ? "・予測クッション値: ${predictedCushion.toStringAsFixed(1)}\n" : "";
      String soilAdjSign = soilAdjustment >= 0 ? "+" : "";

      String intermediateText = simulatedDays > 0
          ? "・中間推移 ($simulatedDays日間): 降水 ${intermediatePrecip.toStringAsFixed(1)}mm / 自然乾燥・標準下限維持\n"
          : "";

      String formulaText = "【予測シミュレーションの根拠】\n"
          "・起点 ($timeLabel公式): ${baseMoisture}%\n"
          "$intermediateText"
          "・当日加水 (降水予報 ${expectedPrecipitation}mm): +${addedMoisture.toStringAsFixed(1)}%\n"
          "・当日乾燥 (日射・風予報): -${reducedMoisture.toStringAsFixed(1)}%\n"
          "・地盤補正 (気象API ${soilPercent.toStringAsFixed(1)}%): $soilAdjSign${soilAdjustment.toStringAsFixed(1)}%\n"
          "➡ 予測含水率: ${predictedMoisture.toStringAsFixed(1)}%$limitNote\n"
          "$cushionText";

      return _SimulationResult(
          predictedMoisture,
          predictedCushion,
          WeatherInsight(
            label: "$labelPrefix$insightLabel",
            value: "予測含水率: ${predictedMoisture.toStringAsFixed(1)}%",
            description: "$insightDesc\n\n$formulaText",
            color: insightColor,
          )
      );
    }

    _SimulationResult? prevResult;
    if (cachedRecord != null) {
      prevResult = buildInsight(cachedRecord, "[前回予測] ", "前回");
      if (prevResult != null) results.add(prevResult.insight);
    }

    _SimulationResult? currentResult = buildInsight(currentRecord, cachedRecord != null ? "🎯[今回確定] " : "", "今回");
    JraConditionPrediction? latestPrediction;

    if (currentResult != null) {
      if (prevResult != null) {
        double diff = currentResult.predictedMoisture - prevResult.predictedMoisture;
        String warning = "";

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

      String venueName = getVenueName(venueCode);
      String trend = 'フラット';
      if (expectedPrecipitation > 0.1) trend = '悪化';
      else if (expectedRadiation > 200 && expectedPrecipitation == 0) trend = '回復';

      latestPrediction = _calculateJraPrediction(
          venueName,
          isDirt,
          currentResult.predictedMoisture,
          currentResult.predictedCushion,
          trend
      );
    }

    return WeatherAnalysisResult(results, latestPrediction);
  }
}

class _SimulationResult {
  final double predictedMoisture;
  final double? predictedCushion;
  final WeatherInsight insight;
  _SimulationResult(this.predictedMoisture, this.predictedCushion, this.insight);
}