// lib/screens/ai_prediction_result_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';

// 表示用の統合データクラス
class PredictionResultViewData {
  final String horseName;
  final String rank;
  final double overallScore;
  final double expectedValue;

  PredictionResultViewData({
    required this.horseName,
    required this.rank,
    required this.overallScore,
    required this.expectedValue,
  });
}

class AiPredictionResultPage extends StatefulWidget {
  final String raceId;
  const AiPredictionResultPage({super.key, required this.raceId});

  @override
  State<AiPredictionResultPage> createState() => _AiPredictionResultPageState();
}

class _AiPredictionResultPageState extends State<AiPredictionResultPage> {
  late Future<List<PredictionResultViewData>> _viewDataFuture;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _viewDataFuture = _loadPredictionResults();
  }

  Future<List<PredictionResultViewData>> _loadPredictionResults() async {
    // データベースからAI予測とレース結果を両方取得
    final predictions = await _dbHelper.getAiPredictionsForRace(widget.raceId);
    final raceResult = await _dbHelper.getRaceResult(widget.raceId);

    if (predictions.isEmpty || raceResult == null) {
      // どちらかのデータがない場合は空リストを返す
      return [];
    }

    // 馬IDをキーにしたマップを作成して、データを結合しやすくする
    final raceResultMap = {for (var horse in raceResult.horseResults) horse.horseId: horse};

    final List<PredictionResultViewData> viewDataList = [];
    for (final prediction in predictions) {
      final horseResult = raceResultMap[prediction.horseId];
      if (horseResult != null) {
        viewDataList.add(
          PredictionResultViewData(
            horseName: horseResult.horseName,
            rank: horseResult.rank,
            overallScore: prediction.overallScore,
            expectedValue: prediction.expectedValue,
          ),
        );
      }
    }

    // 総合スコアの高い順にソートして返す
    viewDataList.sort((a, b) => b.overallScore.compareTo(a.overallScore));
    return viewDataList;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PredictionResultViewData>>(
      future: _viewDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('表示できるAI予測の履歴がありません。'));
        }

        final viewData = snapshot.data!;

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: DataTable(
              columns: const [
                DataColumn(label: Text('馬名')),
                DataColumn(label: Text('着順'), numeric: true),
                DataColumn(label: Text('総合評価'), numeric: true),
                DataColumn(label: Text('期待値'), numeric: true),
              ],
              rows: viewData.map((data) {
                return DataRow(
                  cells: [
                    DataCell(Text(data.horseName)),
                    DataCell(Text(data.rank)),
                    DataCell(Text(data.overallScore.toStringAsFixed(1))),
                    DataCell(Text(data.expectedValue.toStringAsFixed(2))),
                  ],
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}