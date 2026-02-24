// lib/widgets/volatility_analysis_tab.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/ai/volatility_analyzer.dart';

class VolatilityAnalysisTab extends StatefulWidget {
  final List<String> targetRaceIds;

  const VolatilityAnalysisTab({Key? key, required this.targetRaceIds}) : super(key: key);

  @override
  State<VolatilityAnalysisTab> createState() => _VolatilityAnalysisTabState();
}

class _VolatilityAnalysisTabState extends State<VolatilityAnalysisTab> {
  final RaceRepository _raceRepo = RaceRepository();
  final VolatilityAnalyzer _analyzer = VolatilityAnalyzer();
  bool _isLoading = true;
  VolatilityResult? _result;

  @override
  void initState() {
    super.initState();
    _fetchAndAnalyze();
  }

  Future<void> _fetchAndAnalyze() async {
    List<RaceResult> pastRaces = [];
    for (String id in widget.targetRaceIds) {
      final race = await _raceRepo.getRaceResult(id);
      if (race != null) pastRaces.add(race);
    }

    if (mounted) {
      setState(() {
        _result = _analyzer.analyze(pastRaces);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_result == null) {
      return const Center(child: Text('データを取得できませんでした。'));
    }

    final res = _result!;
    Color diagColor = Colors.green;
    IconData diagIcon = Icons.check_circle;
    if (res.diagnosis == '大波乱') {
      diagColor = Colors.red;
      diagIcon = Icons.warning_amber_rounded;
    } else if (res.diagnosis == '堅実') {
      diagColor = Colors.blue;
      diagIcon = Icons.shield;
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(diagIcon, size: 48, color: diagColor),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '波乱度: ${res.diagnosis}',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: diagColor),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '上位馬平均人気: ${res.averagePopularity.toStringAsFixed(2)}番人気',
                          style: const TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '分析レポート',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            res.description,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}