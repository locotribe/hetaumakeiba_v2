// lib/logic/analysis/historical_match_engine_factors/training_factor.dart

import 'package:hetaumakeiba_v2/models/training_time_model.dart';
import 'dart:math' as math;

class TrainingFactorResult {
  final double score;
  final String rank;
  final String diagnosis;
  final String course;
  final String timeStr;
  final String lapStr;

  TrainingFactorResult({
    required this.score,
    required this.rank,
    required this.diagnosis,
    required this.course,
    required this.timeStr,
    required this.lapStr,
  });
}

class TrainingFactor {
  DateTime _parseDate(String dateStr) {
    try {
      if (dateStr.length == 8) {
        int year = int.parse(dateStr.substring(0, 4));
        int month = int.parse(dateStr.substring(4, 6));
        int day = int.parse(dateStr.substring(6, 8));
        return DateTime(year, month, day);
      }
      return DateTime.parse(dateStr.replaceAll('/', '-'));
    } catch (e) {
      return DateTime.now();
    }
  }

  // ★修正: 単一馬の履歴ではなく、全馬の調教データと対象馬IDを受け取り、完全相対評価を行う
  TrainingFactorResult evaluate(String horseId, Map<String, List<TrainingTimeModel>> allTrainingData, String sexAndAge) {
    List<TrainingTimeModel> trainingHistory = allTrainingData[horseId] ?? [];

    if (trainingHistory.isEmpty) {
      return TrainingFactorResult(
        score: -5.0, // データなしは最低点へ
        rank: 'C',
        diagnosis: '調教データなし',
        course: '-',
        timeStr: '-',
        lapStr: '-',
      );
    }

    // sexAndAgeから年齢を抽出
    int age = 4; // デフォルト値
    final ageMatch = RegExp(r'\d+').firstMatch(sexAndAge);
    if (ageMatch != null) {
      age = int.parse(ageMatch.group(0)!);
    }

    // 履歴を日付の降順（新しい順）にソート
    var sortedHistory = List<TrainingTimeModel>.from(trainingHistory)
      ..sort((a, b) => _parseDate(b.trainingDate).compareTo(_parseDate(a.trainingDate)));

    // ステップ2: 最新のデータを「当週追い切り」とする
    TrainingTimeModel currentTraining = sortedHistory.first;
    DateTime currentDate = _parseDate(currentTraining.trainingDate);

    // 同一コースの過去履歴を抽出（パーソナルベースライン・調教量評価用）
    String targetLocation = currentTraining.location;
    String targetTrackType = currentTraining.trackType;
    bool isWood = targetTrackType.contains('ウッド') || targetTrackType.contains('W');
    bool isMiho = targetLocation.contains('美浦'); // 美浦の判定

    List<TrainingTimeModel> sameCourseHistory = sortedHistory.where((t) =>
    t.location == targetLocation && t.trackType == targetTrackType
    ).toList();

    // ステップ1: パーソナルベースライン（PB）の算出
    double pbTime = 999.0;
    double pbLap1f = 999.0;

    for (var t in sameCourseHistory) {
      double? time = isWood ? t.f6 : t.f4;
      if (time != null && time > 0 && time < pbTime) {
        pbTime = time;
      }
      if (t.f1 != null && t.f1! > 0 && t.f1! < pbLap1f) {
        pbLap1f = t.f1!;
      }
    }

    // ステップ2: 1週前追い切りの特定（7〜14日前）
    TrainingTimeModel? lastWeekTraining;
    for (var t in sameCourseHistory) {
      DateTime d = _parseDate(t.trainingDate);
      int diffDays = currentDate.difference(d).inDays;
      if (diffDays >= 6 && diffDays <= 15) {
        lastWeekTraining = t;
        break; // 最も当週に近い1週前を採用
      }
    }

    // 施設別の基準値設定 (平均データ不足時のフォールバック用)
    double baseTimeTarget = 0.0;
    double oniAshiTarget = 0.0;
    String courseName = '';

    if (!isMiho) {
      if (isWood) { baseTimeTarget = 83.0; oniAshiTarget = 11.4; courseName = '栗東CW'; }
      else { baseTimeTarget = 53.5; oniAshiTarget = 11.9; courseName = '栗東坂路'; }
    } else {
      if (isWood) { baseTimeTarget = 83.5; oniAshiTarget = 11.2; courseName = '美浦W'; }
      else { baseTimeTarget = 54.0; oniAshiTarget = 12.0; courseName = '美浦新坂路'; }
    }

    // 評価対象の決定（当週・1週前・外厩パターンの判定）
    TrainingTimeModel targetForEval = currentTraining;
    bool usingLastWeek = false;
    bool isGaityuPattern = false;

    double getCurrentTime(TrainingTimeModel t) => isWood ? (t.f6 ?? 999.0) : (t.f4 ?? 999.0);

    double cTime = getCurrentTime(currentTraining);
    double lTime = lastWeekTraining != null ? getCurrentTime(lastWeekTraining) : 999.0;

    if (lastWeekTraining != null) {
      if (cTime > baseTimeTarget + 1.5 && lTime <= baseTimeTarget + 1.0) {
        targetForEval = lastWeekTraining;
        usingLastWeek = true;
      } else if (cTime > baseTimeTarget + 1.5 && lTime > baseTimeTarget + 1.5) {
        isGaityuPattern = true;
      }
    } else if (cTime > baseTimeTarget + 1.5) {
      isGaityuPattern = true;
    }

    double evalTime = getCurrentTime(targetForEval);
    double? evalLap1f = targetForEval.f1;
    double? evalLap2f = targetForEval.f2;

    // ★追加: 同一コースにおける今回のレース全体の平均・標準偏差の算出 (相対評価のコア)
    List<double> raceTimes = [];
    List<double> raceLaps = [];

    allTrainingData.forEach((keyHorseId, hHistory) {
      if (hHistory.isEmpty) return;
      var sHist = List<TrainingTimeModel>.from(hHistory)..sort((a,b) => _parseDate(b.trainingDate).compareTo(_parseDate(a.trainingDate)));
      try {
        var recent = sHist.firstWhere((t) {
          DateTime d = _parseDate(t.trainingDate);
          // 同一コースかつ、直近21日以内のデータを今回のレースの比較対象とする
          return t.location == targetLocation && t.trackType == targetTrackType && currentDate.difference(d).inDays.abs() <= 21;
        });
        double rTime = isWood ? (recent.f6 ?? 0.0) : (recent.f4 ?? 0.0);
        if (rTime > 0.0) raceTimes.add(rTime);
        double rLap = recent.f1 ?? 0.0;
        if (rLap > 0.0) raceLaps.add(rLap);
      } catch(e) {} // 該当データがない馬はスキップ
    });

    double calcMean(List<double> vals) => vals.isEmpty ? 0.0 : vals.reduce((a, b) => a + b) / vals.length;
    double calcSd(List<double> vals, double mean) {
      if (vals.length < 2) return 1.5; // 計算不可時のダミー標準偏差
      double sumSq = vals.fold(0.0, (acc, val) => acc + math.pow(val - mean, 2));
      return math.sqrt(sumSq / (vals.length - 1));
    }

    double raceMeanTime = raceTimes.isNotEmpty ? calcMean(raceTimes) : baseTimeTarget;
    double raceSdTime = calcSd(raceTimes, raceMeanTime);

    double raceMeanLap = raceLaps.isNotEmpty ? calcMean(raceLaps) : oniAshiTarget + 0.3;
    double raceSdLap = calcSd(raceLaps, raceMeanLap);

    // ★解像度を倍増させた新・7軸スコアリング (合計100点満点)

    // 軸1. メンバー内相対・全体時計の偏差評価 (20点)
    double scoreRelativeTime = 10.0;
    bool isOverTraining = false;
    if (evalTime < 999.0) {
      // zScore: 負の値ほど速い（優秀）
      double zTime = (evalTime - raceMeanTime) / raceSdTime;
      if (evalTime <= baseTimeTarget - 2.0) isOverTraining = true;
      // Z=-1.5で満点(20点), Z=0で平均(10点), Z=1.5で最低(0点)
      scoreRelativeTime = (10.0 - (zTime * 6.66)).clamp(0.0, 20.0);
    } else {
      scoreRelativeTime = 0.0;
    }

    // 軸2. メンバー内相対・上がりキレの偏差評価 (20点)
    double scoreRelativeLap = 10.0;
    if (evalLap1f != null && evalLap1f > 0) {
      double zLap = (evalLap1f - raceMeanLap) / raceSdLap;
      scoreRelativeLap = (10.0 - (zLap * 6.66)).clamp(0.0, 20.0);
    }

    // 軸3. 自己ベスト(PB)到達度 (15点)
    double scorePB = 7.5;
    if (pbTime < 999.0 && evalTime < 999.0) {
      if (evalTime <= pbTime) {
        scorePB = 15.0; // PBタイ・更新で満点
      } else {
        double diff = evalTime - pbTime;
        scorePB = math.max(0.0, 15.0 - (diff * 7.5)); // 2.0秒遅れで0点
      }
    }

    // 軸4. 年齢・状態落ち判定 (15点)
    double scoreCondition = 15.0;
    bool hasAgingSignal = false;
    bool hasConditionDropSignal = false;
    if (evalLap1f != null && evalLap1f > 0 && pbLap1f < 99.0) {
      if ((evalLap1f - pbLap1f) >= 0.5) {
        if (age >= 6) {
          hasAgingSignal = true;
          scoreCondition = 0.0; // 高齢馬の明確な劣化は15点全ロス
        } else {
          hasConditionDropSignal = true;
          scoreCondition = 7.5; // 若馬の反応鈍化は半減(7.5点ロス)
        }
      }
    }

    // 軸5. ラップ推移・プロセスの質 (10点)
    double scorePace = 5.0;
    bool isRunaway = false;
    if (evalLap1f != null && evalLap2f != null && evalLap2f > 0 && evalLap1f > 0) {
      double diff = evalLap1f - (evalLap2f - evalLap1f); // 正なら失速、負なら加速
      if (diff <= 0.0) {
        scorePace = 10.0;
      } else {
        if (isOverTraining) isRunaway = true;
        if (isWood) {
          scorePace = math.max(0.0, 10.0 - (diff * 20.0)); // ウッドは減点厳格
        } else {
          scorePace = diff <= 0.5 ? 8.0 : math.max(0.0, 10.0 - (diff * 10.0));
        }
      }
    }

    // 軸6. 意図的な1週前仕上げ判定 (10点)
    double scoreIntent = usingLastWeek ? 10.0 : 5.0;

    // 軸7. 調教量・順調度判定 (10点)
    double scoreVolume = 0.0;
    int trainingCount = sameCourseHistory.where((t) {
      return currentDate.difference(_parseDate(t.trainingDate)).inDays <= 28 &&
          ((isWood ? t.f6 : t.f4) ?? 999.0) < 999.0;
    }).length;
    if (trainingCount >= 4) scoreVolume = 10.0;
    else if (trainingCount == 3) scoreVolume = 8.0;
    else if (trainingCount == 2) scoreVolume = 5.0;
    else if (trainingCount == 1) scoreVolume = 2.0;

    // ★トータルポイント集計とペナルティ計算
    double totalPoints = scoreRelativeTime + scoreRelativeLap + scorePB + scoreCondition + scorePace + scoreIntent + scoreVolume;

    if (isRunaway) {
      double penalty = isMiho ? 5.0 : 10.0;
      totalPoints = math.max(0.0, totalPoints - penalty);
    }

    if (isGaityuPattern && evalLap1f != null && evalLap2f != null) {
      double diff = evalLap1f - (evalLap2f - evalLap1f);
      if (diff <= -0.1 && totalPoints < 40.0) {
        totalPoints = 40.0; // 外厩セーフティネット
      }
    }

    // ★ステップ5: 連続値シームレススコアリングへの変換 (-5.0 〜 +10.0)
    // 0点 -> -5.0, 100点 -> +10.0 に線形マッピング
    double finalContinuousScore = -5.0 + (totalPoints / 100.0) * 15.0;
    // 小数第1位で丸める
    finalContinuousScore = double.parse(finalContinuousScore.toStringAsFixed(1));

    String rankStr = '';
    String diagnosisText = '';

    // ランク付けの閾値変更（連続値に基づく）
    if (finalContinuousScore >= 7.0) {
      rankStr = 'S';
      diagnosisText = usingLastWeek
          ? '1週前に猛時計。メンバー上位の仕上がり'
          : '他馬を圧倒する時計・キレ。状態はピークに迫る';
    } else if (finalContinuousScore >= 3.0) {
      rankStr = 'A';
      diagnosisText = usingLastWeek
          ? '1週前の時計が優秀。当週は余力残しで好調'
          : '水準以上の時計とラップ推移で好調キープ';
      if (hasAgingSignal) diagnosisText += ' (※キレに衰えサインあり)';
      if (hasConditionDropSignal) diagnosisText += ' (※終いの反応にやや鈍さあり)';
    } else if (finalContinuousScore >= -1.0) {
      rankStr = 'B';
      if (isGaityuPattern && totalPoints == 40.0) {
        diagnosisText = '時計は遅いが加速ラップ。外厩調整の実戦想定か';
      } else if (isRunaway && isMiho) {
        diagnosisText = '時計は速いが失速ラップ。逍遥馬道の回復効果に期待';
      } else {
        diagnosisText = 'メンバー内では平均的な時計とラップ推移';
      }
    } else {
      rankStr = 'C';
      if (isRunaway) {
        diagnosisText = 'オーバースピードによる明確な失速。暴走の危険性大';
      } else if (hasAgingSignal) {
        diagnosisText = '終いの時計に明確な劣化。加齢による能力減衰の懸念';
      } else if (hasConditionDropSignal) {
        diagnosisText = '終いの反応が鈍く、実力発揮には疑問符（仕上がり途上か）';
      } else {
        diagnosisText = 'メンバー比較で時計・キレ共に見劣り。良化途上か';
      }
    }

    // 表示用文字列の生成
    double? dispTime = isWood ? currentTraining.f6 : currentTraining.f4;
    String timeStr = dispTime != null ? '${dispTime.toStringAsFixed(1)}秒' : '-';

    String lapStr = '-';
    if (currentTraining.f2 != null && currentTraining.f1 != null && currentTraining.f2! > currentTraining.f1!) {
      double split2F = currentTraining.f2! - currentTraining.f1!;
      lapStr = '${split2F.toStringAsFixed(1)}-${currentTraining.f1!.toStringAsFixed(1)}';
    } else if (currentTraining.f1 != null) {
      lapStr = '${currentTraining.f1!.toStringAsFixed(1)}';
    }

    return TrainingFactorResult(
      score: finalContinuousScore, // ★連続値をそのまま返す
      rank: rankStr,
      diagnosis: diagnosisText,
      course: courseName.isNotEmpty ? courseName : '${currentTraining.location}${currentTraining.trackType}',
      timeStr: timeStr,
      lapStr: lapStr,
    );
  }
}