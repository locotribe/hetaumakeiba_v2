// lib/logic/analysis/weather_analyzer.dart

import 'package:flutter/material.dart';

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
}