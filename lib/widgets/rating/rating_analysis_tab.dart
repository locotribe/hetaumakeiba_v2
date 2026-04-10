// lib/widgets/rating/rating_analysis_tab.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/logic/analysis/rating_engine.dart';
import 'views/rating_summary_view.dart';
import 'views/rating_momentum_view.dart';
import 'views/rating_suitability_view.dart';
import 'components/rating_level_badge.dart';

class RatingAnalysisTab extends StatefulWidget {
  final List<PredictionHorseDetail> horses;
  final String raceName;
  final String raceDate;

  const RatingAnalysisTab({
    super.key,
    required this.horses,
    required this.raceName,
    required this.raceDate,
  });

  @override
  State<RatingAnalysisTab> createState() => _RatingAnalysisTabState();
}

class _RatingAnalysisTabState extends State<RatingAnalysisTab> {
  final HorseRepository _horseRepo = HorseRepository();
  bool _isLoading = true;
  final Map<String, HorseRatingProfile> _profilesMap = {};

  double _predictedRaceLevel = 0.0;
  double _levelDiff = 0.0;
  String _levelDiagnosis = '';
  String _levelDescription = '';
  String _reliabilityGrade = '';
  Color _levelColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _executeAnalysis();
  }

  Future<void> _executeAnalysis() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    double totalTrend = 0;
    int dataSufficiencyCount = 0;
    int validHorseCount = 0;

    for (var horse in widget.horses) {
      final history = await _horseRepo.getHorsePerformanceRecords(horse.horseId);
      final profile = await _horseRepo.getHorseProfile(horse.horseId);
      final gender = profile?.gender ?? '牡';

      final resultProfile = AdvancedRatingEngine.analyze(history, horse.horseId, gender, widget.raceName);
      _profilesMap[horse.horseId] = resultProfile;

      if (resultProfile.history.isNotEmpty) {
        totalTrend += resultProfile.latestTrend;
        validHorseCount++;
        if (history.length >= 3) dataSufficiencyCount++;
      }
    }

    if (validHorseCount > 0) {
      final double classBase = AdvancedRatingEngine.getBaseRating(widget.raceName);
      final double avgTrend = totalTrend / validHorseCount;

      _predictedRaceLevel = (avgTrend * 0.7) + (classBase * 0.3);
      _levelDiff = _predictedRaceLevel - classBase;

      if (_levelDiff >= 1.5) {
        _levelDiagnosis = 'ハイレベルな一戦';
        _levelDescription = 'クラス基準を大きく上回る強豪が揃いました。上位馬は昇級後も即通用する可能性があります。';
        _levelColor = Colors.red.shade700;
      } else if (_levelDiff <= -1.5) {
        _levelDiagnosis = '低調なメンバー構成';
        _levelDescription = '手薄な組み合わせです。能力不足の馬でも展開一つで勝機があり、波乱に注意が必要です。';
        _levelColor = Colors.blue.shade700;
      } else {
        _levelDiagnosis = '標準的なレースレベル';
        _levelDescription = 'このクラスの平均的な水準のメンバーです。純粋な能力比較と適性が鍵となります。';
        _levelColor = Colors.green.shade700;
      }

      double sufficiencyRatio = dataSufficiencyCount / widget.horses.length;
      if (sufficiencyRatio >= 0.8) _reliabilityGrade = 'A (高)';
      else if (sufficiencyRatio >= 0.5) _reliabilityGrade = 'B (中)';
      else _reliabilityGrade = 'C (低)';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _showHistoryDialog(PredictionHorseDetail horse, List<RatingAnalyzedResult> history) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${horse.horseName} レーティング推移'),
        content: SizedBox(
          width: double.maxFinite,
          height: 350,
          child: history.isEmpty
              ? const Center(child: Text('戦績データがありません'))
              : ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final res = history[history.length - 1 - index];
              return ListTile(
                dense: true,
                title: Text('${res.record.date} ${res.record.raceName}'),
                subtitle: Text('着順: ${res.record.rank}/${res.record.numberOfHorses} (${res.record.popularity}人)'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Rt: ${res.raceRating.toStringAsFixed(1)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    RatingLevelBadge(
                      level: res.levelGrade,
                      rankStr: res.record.rank,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('閉じる'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final sortedHorses = List<PredictionHorseDetail>.from(widget.horses);
    sortedHorses.sort((a, b) => (_profilesMap[b.horseId]?.latestTrend ?? 0).compareTo(_profilesMap[a.horseId]?.latestTrend ?? 0));

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          _buildRaceLevelCard(),
          Container(
            color: Colors.grey.shade100,
            child: TabBar(
              labelColor: Colors.blue.shade900,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue.shade900,
              isScrollable: true,
              tabs: const [
                Tab(text: '基本・期待値'),
                Tab(text: '勢い・信頼度'),
                Tab(text: '条件適合'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                RatingSummaryView(horses: sortedHorses, profiles: _profilesMap, onRowTap: _showHistoryDialog),
                RatingMomentumView(horses: sortedHorses, profiles: _profilesMap, onRowTap: _showHistoryDialog),
                RatingSuitabilityView(horses: sortedHorses, profiles: _profilesMap, raceDate: widget.raceDate, onRowTap: _showHistoryDialog),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRaceLevelCard() {
    if (_predictedRaceLevel == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(8.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _levelColor, width: 1.5),
        borderRadius: BorderRadius.circular(8.0),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('予想レースレベル診断', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
              Text('分析信頼度: $_reliabilityGrade', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(_levelDiagnosis, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _levelColor)),
              const Spacer(),
              Text('数値: ${_predictedRaceLevel.toStringAsFixed(1)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text('(${_levelDiff > 0 ? '+' : ''}${_levelDiff.toStringAsFixed(1)})',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _levelColor)),
            ],
          ),
          const Divider(height: 16),
          Text(_levelDescription, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4)),
        ],
      ),
    );
  }
}