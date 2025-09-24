// lib/screens/shutuba_table_page.dart

import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_the_tooltip/just_the_tooltip.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:hetaumakeiba_v2/main.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/logic/ai/stats_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/ai/race_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/ai/leg_style_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/race_interval_analyzer.dart';
import 'package:hetaumakeiba_v2/logic/race_data_parser.dart';
import 'package:hetaumakeiba_v2/widgets/themed_tab_bar.dart';
import 'package:hetaumakeiba_v2/widgets/race_header_card.dart';
import 'package:hetaumakeiba_v2/widgets/leg_style_indicator.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/shutuba_table_cache_model.dart';
import 'package:hetaumakeiba_v2/services/shutuba_table_scraper_service.dart';
import 'package:hetaumakeiba_v2/services/ai_prediction_service.dart';
import 'package:hetaumakeiba_v2/screens/ai_prediction_settings_page.dart';
import 'package:hetaumakeiba_v2/screens/ai_comprehensive_prediction_page.dart';
import 'package:hetaumakeiba_v2/screens/race_statistics_page.dart';
import 'package:hetaumakeiba_v2/screens/horse_stats_page.dart';
import 'package:hetaumakeiba_v2/screens/bulk_memo_edit_page.dart';
import '../utils/grade_utils.dart';

enum SortableColumn {
  mark,
  gateNumber,
  horseNumber,
  horseName,
  popularity,
  odds,
  carriedWeight,
  horseWeight,
  overallScore,
  bestTime,
  fastestAgari,
  legStyle,
}

class _PerformanceData {
  final List<HorseRaceRecord> records;
  final Map<String, RaceResult> raceResults;

  _PerformanceData(this.records, this.raceResults);
}

class ShutubaTablePage extends StatefulWidget {
  final String raceId;
  final RaceResult? raceResult;
  final PredictionRaceData? predictionRaceData;
  final Function(PredictionRaceData)? onDataRefreshed;

  const ShutubaTablePage({super.key, required this.raceId, this.raceResult,
    this.predictionRaceData, this.onDataRefreshed, });

  @override
  State<ShutubaTablePage> createState() => _ShutubaTablePageState();
}

class _ShutubaTablePageState extends State<ShutubaTablePage> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  PredictionRaceData? _predictionRaceData;
  bool _isLoading = true;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ShutubaTableScraperService _scraperService = ShutubaTableScraperService();
  final AiPredictionService _predictionService = AiPredictionService();
  Map<String, double> _overallScores = {};
  Map<String, double> _expectedValues = {};
  Map<String, ConditionFitResult> _conditionFits = {};

  SortableColumn _sortColumn = SortableColumn.horseNumber;
  bool _isAscending = true;
  late TabController _tabController;
  String? _highlightedRaceId;

  @override
  bool get wantKeepAlive => true;


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadShutubaData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  Future<void> _loadShutubaData({bool refresh = false}) async {
    if (!refresh) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      PredictionRaceData? data;

      if (widget.predictionRaceData != null && !refresh) {
        data = widget.predictionRaceData;
      }
      else if (widget.raceResult != null && !refresh) {
        data = _createPredictionDataFromRaceResult(widget.raceResult!);
      }
      else {
        final cache = await _dbHelper.getShutubaTableCache(widget.raceId);
        if (cache != null && !refresh) {
          data = cache.predictionRaceData;
          final userId = localUserId;
          if (userId != null) {
            final userMarks = await _dbHelper.getAllUserMarksForRace(userId, widget.raceId);
            final userMemos = await _dbHelper.getMemosForRace(userId, widget.raceId);
            final marksMap = {for (var mark in userMarks) mark.horseId: mark};
            final memosMap = {for (var memo in userMemos) memo.horseId: memo};

            for (var horse in data.horses) {
              horse.userMark = marksMap[horse.horseId];
              horse.userMemo = memosMap[horse.horseId];
            }
          }
        } else {
          data = await _fetchDataWithUserMarks();
          if (data != null) {
            final newCache = ShutubaTableCache(
              raceId: widget.raceId,
              predictionRaceData: data,
              lastUpdatedAt: DateTime.now(),
            );
            await _dbHelper.insertOrUpdateShutubaTableCache(newCache);
          }
        }
      }

      if (mounted) {
        if (data != null) {
          if (data.horses.any((h) => h.overallScore != null)) {
            _overallScores = {
              for (var h in data.horses)
                if (h.overallScore != null) h.horseId: h.overallScore!
            };
            _expectedValues = {
              for (var h in data.horses)
                if (h.expectedValue != null) h.horseId: h.expectedValue!
            };
          } else {
            final predictions = await _dbHelper.getAiPredictionsForRace(widget.raceId);
            if(predictions.isNotEmpty){
              _overallScores = {for (var p in predictions) p.horseId: p.overallScore};
              _expectedValues = {for (var p in predictions) p.horseId: p.expectedValue};
            }
          }
          if (widget.onDataRefreshed != null) {
            widget.onDataRefreshed!(data);
          }
        }
        setState(() {
          _predictionRaceData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('出馬表データの読み込みに失敗: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateMarkAndSaveInBackground(UserMark mark) async {
    await _dbHelper.insertOrUpdateUserMark(mark);
    if (_predictionRaceData != null) {
      final newCache = ShutubaTableCache(
        raceId: widget.raceId,
        predictionRaceData: _predictionRaceData!,
        lastUpdatedAt: DateTime.now(),
      );
      await _dbHelper.insertOrUpdateShutubaTableCache(newCache);
    }
  }

  Future<void> _deleteMarkAndSaveInBackground(PredictionHorseDetail horse) async {
    final userId = localUserId;
    if (userId == null) return;

    await _dbHelper.deleteUserMark(userId, widget.raceId, horse.horseId);
    if (_predictionRaceData != null) {
      final newCache = ShutubaTableCache(
        raceId: widget.raceId,
        predictionRaceData: _predictionRaceData!,
        lastUpdatedAt: DateTime.now(),
      );
      await _dbHelper.insertOrUpdateShutubaTableCache(newCache);
    }
  }

  PredictionRaceData _createPredictionDataFromRaceResult(RaceResult raceResult) {
    final horses = raceResult.horseResults.map((hr) {
      final weightMatch = RegExp(r'(\d+)\((.*?)\)').firstMatch(hr.horseWeight);
      final trainerName = hr.trainerName;
      final trainerAffiliation = hr.trainerAffiliation;

      return PredictionHorseDetail(
        horseId: hr.horseId,
        horseNumber: int.tryParse(hr.horseNumber) ?? 0,
        gateNumber: int.tryParse(hr.frameNumber) ?? 0,
        horseName: hr.horseName,
        sexAndAge: hr.sexAndAge,
        jockey: hr.jockeyName,
        jockeyId: hr.jockeyId,
        carriedWeight: double.tryParse(hr.weightCarried) ?? 0.0,
        trainerName: trainerName,
        trainerAffiliation: trainerAffiliation,
        odds: double.tryParse(hr.odds),
        popularity: int.tryParse(hr.popularity),
        horseWeight: weightMatch?.group(1),
        isScratched: int.tryParse(hr.rank) == null,
      );
    }).toList();

    final raceNumber = raceResult.raceId.length >= 2
        ? int.tryParse(raceResult.raceId.substring(raceResult.raceId.length - 2))?.toString() ?? ''
        : '';


    return PredictionRaceData(
      raceId: raceResult.raceId,
      raceName: raceResult.raceTitle,
      raceDate: raceResult.raceDate,
      venue: racecourseDict.entries.firstWhere((e) => raceResult.raceInfo.contains(e.value), orElse: () => const MapEntry("", "")).value,
      raceNumber: raceNumber,
      shutubaTableUrl: 'https://db.netkeiba.com/race/${raceResult.raceId}',
      raceGrade: raceResult.raceGrade,
      raceDetails1: raceResult.raceInfo,
      horses: horses,
    );
  }

  Future<void> _updateDynamicData() async {
    if (widget.raceResult != null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('レース結果確定後はオッズを更新できません。')));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('最新情報を取得中...')));
    try {
      await _loadShutubaData(refresh: true);

      if(mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('情報を更新しました。')));
      }

    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('情報の更新に失敗しました: $e')));
      }
    }
  }


  Future<void> _calculatePredictionScores(PredictionRaceData raceData) async {
    final scores = await _predictionService.calculatePredictionScores(
      raceData,
      widget.raceId,
    );

    for (var horse in raceData.horses) {
      horse.overallScore = scores.overallScores[horse.horseId];
      horse.expectedValue = scores.expectedValues[horse.horseId];
    }

    final newCache = ShutubaTableCache(
      raceId: widget.raceId,
      predictionRaceData: raceData,
      lastUpdatedAt: DateTime.now(),
    );
    await _dbHelper.insertOrUpdateShutubaTableCache(newCache);

    if (mounted) {
      setState(() {
        _predictionRaceData = raceData;
        _overallScores = scores.overallScores;
        _expectedValues = scores.expectedValues;
        _conditionFits = scores.conditionFits;
      });
    }
  }

  String _getRankFromScore(double score) {
    if (score >= 90) return 'S';
    if (score >= 85) return 'A+';
    if (score >= 80) return 'A';
    if (score >= 75) return 'B+';
    if (score >= 70) return 'B';
    if (score >= 60) return 'C+';
    if (score >= 50) return 'C';
    return 'D';
  }

  Future<PredictionRaceData?> _fetchDataWithUserMarks() async {
    final userId = localUserId;
    if (userId == null) {
      return await _scraperService.scrapeAllData(widget.raceId);
    }

    final raceData = await _scraperService.scrapeAllData(widget.raceId);

    final results = await Future.wait([
      _dbHelper.getAllUserMarksForRace(userId, widget.raceId),
      _dbHelper.getMemosForRace(userId, widget.raceId),
    ]);

    final userMarks = results[0] as List<UserMark>;
    final userMemos = results[1] as List<HorseMemo>;

    final marksMap = {for (var mark in userMarks) mark.horseId: mark};
    final memosMap = {for (var memo in userMemos) memo.horseId: memo};

    final Map<String, List<HorseRaceRecord>> allPastRecords = {};
    final Set<String> pastRaceIdsToFetch = {};

    for (var horse in raceData.horses) {
      if (marksMap.containsKey(horse.horseId)) {
        horse.userMark = marksMap[horse.horseId];
      }
      if (memosMap.containsKey(horse.horseId)) {
        horse.userMemo = memosMap[horse.horseId];
        if (memosMap[horse.horseId]!.odds != null) {
          horse.odds = memosMap[horse.horseId]!.odds;
        }
        if (memosMap[horse.horseId]!.popularity != null) {
          horse.popularity = memosMap[horse.horseId]!.popularity;
        }
      }
      final pastRecords = await _dbHelper.getHorsePerformanceRecords(horse.horseId);
      allPastRecords[horse.horseId] = pastRecords;

      if (pastRecords.isNotEmpty) {
        final previousRaceId = pastRecords.first.raceId;
        if (previousRaceId.isNotEmpty) {
          pastRaceIdsToFetch.add(previousRaceId);
        }
      }
    }

    final pastRaceResults = await _dbHelper.getMultipleRaceResults(pastRaceIdsToFetch.toList());

    for (var horse in raceData.horses) {
      final pastRecords = allPastRecords[horse.horseId] ?? [];

      if (pastRecords.isNotEmpty) {
        final previousRecord = pastRecords.first;
        horse.previousJockey = previousRecord.jockey;
        horse.previousHorseWeight = previousRecord.horseWeight;

        final previousRaceResult = pastRaceResults[previousRecord.raceId];
        if (previousRaceResult != null) {
          try {
            final horseResult = previousRaceResult.horseResults.firstWhere((hr) => hr.horseId == horse.horseId);
            horse.ownerName = horseResult.ownerName;
          } catch (e) {
          }
        }
      }

      horse.legStyleProfile = LegStyleAnalyzer.getRunningStyle(pastRecords);
      horse.distanceCourseAptitudeStats = StatsAnalyzer.analyzeDistanceCourseAptitude(
        raceData: raceData,
        pastRecords: pastRecords,
      );
      horse.trackAptitudeLabel = StatsAnalyzer.analyzeTrackAptitude(
        pastRecords: pastRecords,
      );
      horse.bestTimeStats = StatsAnalyzer.analyzeBestTime(
        raceData: raceData,
        pastRecords: pastRecords,
      );
      horse.fastestAgariStats = StatsAnalyzer.analyzeFastestAgari(
        pastRecords: pastRecords,
      );
    }

    raceData.racePacePrediction = RaceAnalyzer.predictRacePace(
        raceData.horses, allPastRecords, []);
    return raceData;
  }

  Future<void> _showMemoDialog(PredictionHorseDetail horse) async {
    final userId = localUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です。')),
      );
      return;
    }

    final memoController = TextEditingController(text: horse.userMemo?.predictionMemo);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${horse.horseName} - 予想メモ'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: memoController,
              autofocus: true,
              maxLines: null,
              decoration: const InputDecoration(
                hintText: 'ここにメモを入力...',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final newMemo = HorseMemo(
                    id: horse.userMemo?.id,
                    userId: userId,
                    raceId: widget.raceId,
                    horseId: horse.horseId,
                    predictionMemo: memoController.text,
                    reviewMemo: horse.userMemo?.reviewMemo,
                    odds: horse.userMemo?.odds,
                    popularity: horse.userMemo?.popularity,
                    timestamp: DateTime.now(),
                  );
                  await _dbHelper.insertOrUpdateHorseMemo(newMemo);
                  Navigator.of(context).pop();
                  _loadShutubaData(refresh: true);
                }
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _exportMemosAsCsv(PredictionRaceData raceData) async {
    final List<List<dynamic>> rows = [];
    rows.add(['raceId', 'horseId', 'horseNumber', 'horseName', 'predictionMemo', 'reviewMemo']);

    for (final horse in raceData.horses) {
      rows.add([
        widget.raceId,
        horse.horseId,
        horse.horseNumber,
        horse.horseName,
        horse.userMemo?.predictionMemo ?? '',
        horse.userMemo?.reviewMemo ?? '',
      ]);
    }

    final String csv = const ListToCsvConverter().convert(rows);

    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/${widget.raceId}_memos.csv';
    final file = File(path);
    await file.writeAsString(csv);

    await Share.shareXFiles([XFile(path)], text: '${raceData.raceName} のメモ');
  }

  Future<void> _importMemosFromCsv() async {
    final userId = localUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です。')),
      );
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final filePath = result.files.single.path!;
      final file = File(filePath);
      final csvString = await file.readAsString();

      final List<List<dynamic>> rows = const CsvToListConverter().convert(csvString);

      if (rows.length < 2) {
        throw Exception('CSVファイルにデータがありません。');
      }
      final header = rows.first;
      if (header.join(',') != 'raceId,horseId,horseNumber,horseName,predictionMemo,reviewMemo') {
        throw Exception('CSVファイルのヘッダー形式が正しくありません。');
      }

      final List<HorseMemo> memosToUpdate = [];
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        final csvRaceId = row[0].toString();

        if (csvRaceId != widget.raceId) {
          throw Exception('CSVファイルのレースIDが、現在表示しているレースと一致しません。');
        }

        memosToUpdate.add(HorseMemo(
          userId: userId,
          raceId: csvRaceId,
          horseId: row[1].toString(),
          predictionMemo: row[4].toString(),
          reviewMemo: row[5].toString(),
          timestamp: DateTime.now(),
        ));
      }

      await _dbHelper.insertOrUpdateMultipleMemos(memosToUpdate);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${memosToUpdate.length}件のメモをインポートしました。')),
      );
      _loadShutubaData();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('インポートエラー: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _predictionRaceData == null
        ? Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('レース情報の読み込みに失敗しました。'),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _loadShutubaData(),
            child: const Text('再試行'),
          )
        ],
      ),
    )
        : Column(
      children: [
        if (widget.raceResult == null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: _updateDynamicData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('オッズ・馬体重を更新'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ),
        Expanded(
            child: Column(
              children: [
                ThemedTabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabs: const [
                    Tab(text: '出走馬'),
                    Tab(text: '情報'),
                    Tab(text: '騎手・調教師'),
                    Tab(text: '分析'),
                    Tab(text: '時計'),
                    Tab(text: '成績'),
                    Tab(text: 'メモ'),
                  ],
                ),
                Expanded(
                  child: Builder(
                      builder: (context) {
                        final sortedHorses = List<PredictionHorseDetail>.from(_predictionRaceData!.horses);
                        sortedHorses.sort((a, b) {
                          int comparison;
                          int compareNullsLast(Comparable? valA, Comparable? valB) {
                            if (valA == null && valB == null) return 0;
                            if (valA == null) return 1;
                            if (valB == null) return -1;
                            return valA.compareTo(valB);
                          }

                          switch (_sortColumn) {
                            case SortableColumn.mark:
                              const markOrder = {'◎': 0, '〇': 1, '▲': 2, '△': 3, '✕': 4, '★': 5, '消': 6};
                              final aMark = markOrder[a.userMark?.mark] ?? 99;
                              final bMark = markOrder[b.userMark?.mark] ?? 99;
                              comparison = aMark.compareTo(bMark);
                              break;
                            case SortableColumn.gateNumber:
                              comparison = a.gateNumber.compareTo(b.gateNumber);
                              break;
                            case SortableColumn.horseNumber:
                              comparison = a.horseNumber.compareTo(b.horseNumber);
                              break;
                            case SortableColumn.horseName:
                              comparison = a.horseName.compareTo(b.horseName);
                              break;
                            case SortableColumn.popularity:
                              comparison = compareNullsLast(a.popularity, b.popularity);
                              break;
                            case SortableColumn.odds:
                              comparison = compareNullsLast(a.odds, b.odds);
                              break;
                            case SortableColumn.carriedWeight:
                              comparison = a.carriedWeight.compareTo(b.carriedWeight);
                              break;
                            case SortableColumn.horseWeight:
                              final aWeight = int.tryParse(a.horseWeight?.split('(').first ?? '');
                              final bWeight = int.tryParse(b.horseWeight?.split('(').first ?? '');
                              comparison = compareNullsLast(aWeight, bWeight);
                              break;
                            case SortableColumn.overallScore:
                              final aScore = _overallScores[a.horseId];
                              final bScore = _overallScores[b.horseId];
                              comparison = compareNullsLast(aScore, bScore);
                              break;
                            case SortableColumn.bestTime:
                              final aTime = a.bestTimeStats?.timeInSeconds;
                              final bTime = b.bestTimeStats?.timeInSeconds;
                              if (aTime == null && bTime == null) comparison = 0;
                              else if (aTime == null) comparison = 1;
                              else if (bTime == null) comparison = -1;
                              else comparison = aTime.compareTo(bTime);
                              break;
                            case SortableColumn.fastestAgari:
                              final aAgari = a.fastestAgariStats?.agariInSeconds;
                              final bAgari = b.fastestAgariStats?.agariInSeconds;
                              comparison = compareNullsLast(aAgari, bAgari);
                              break;

                            default:
                              comparison = a.horseNumber.compareTo(b.horseNumber);
                              break;
                          }
                          return _isAscending ? comparison : -comparison;
                        });

                        return TabBarView(
                          controller: _tabController,
                          children: [
                            _buildStartersTab(sortedHorses),
                            _buildInfoTab(sortedHorses),
                            _buildJockeyTrainerTab(sortedHorses),
                            _buildAnalysisTab(sortedHorses),
                            _buildTimeTab(sortedHorses),
                            _buildPerformanceTab(sortedHorses),
                            _buildMemoTab(sortedHorses),
                          ],
                        );
                      }
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildConditionFitCell(ConditionFitResult? fitResult) {
    if (fitResult == null) {
      return const Text('-');
    }

    final ratings = [fitResult.trackFit, fitResult.paceFit, fitResult.weightFit, fitResult.gateFit];
    int totalScore = 0;
    int validRatings = 0;
    for (var rating in ratings) {
      if (rating != FitnessRating.unknown) {
        validRatings++;
        totalScore += {FitnessRating.excellent: 4, FitnessRating.good: 3, FitnessRating.average: 2, FitnessRating.poor: 1}[rating]!;
      }
    }

    if (validRatings == 0) {
      return const Text('-');
    }

    final avgScore = totalScore / validRatings;

    String rank;
    if (avgScore >= 3.5) {
      rank = 'S';
    } else if (avgScore >= 3.0) rank = 'A';
    else if (avgScore >= 2.5) rank = 'B';
    else if (avgScore >= 2.0) rank = 'C';
    else rank = 'D';

    return Text(rank, style: const TextStyle(fontWeight: FontWeight.bold));
  }


  void _onSort(SortableColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _isAscending = !_isAscending;
      } else {
        _sortColumn = column;
        _isAscending = true;
      }
      _predictionRaceData?.horses.sort((a, b) {
        int comparison;
        int compareNullsLast(Comparable? valA, Comparable? valB) {
          if (valA == null && valB == null) return 0;
          if (valA == null) return 1;
          if (valB == null) return -1;
          return valA.compareTo(valB);
        }

        switch (_sortColumn) {
          case SortableColumn.mark:
            const markOrder = {'◎': 0, '〇': 1, '▲': 2, '△': 3, '✕': 4, '★': 5, '消': 6};
            final aMark = markOrder[a.userMark?.mark] ?? 99;
            final bMark = markOrder[b.userMark?.mark] ?? 99;
            comparison = aMark.compareTo(bMark);
            break;
          case SortableColumn.gateNumber:
            comparison = a.gateNumber.compareTo(b.gateNumber);
            break;
          case SortableColumn.horseNumber:
            comparison = a.horseNumber.compareTo(b.horseNumber);
            break;
          case SortableColumn.horseName:
            comparison = a.horseName.compareTo(b.horseName);
            break;
          case SortableColumn.legStyle:
            const styleOrder = {'逃げ': 0, '先行': 1, '差し': 2, '追い込み': 3, '自在': 4, 'マクリ': 5, '不明': 99};
            final aStyle = styleOrder[a.legStyleProfile?.primaryStyle] ?? 99;
            final bStyle = styleOrder[b.legStyleProfile?.primaryStyle] ?? 99;
            comparison = aStyle.compareTo(bStyle);
            break;
          case SortableColumn.popularity:
            comparison = compareNullsLast(a.popularity, b.popularity);
            break;
          case SortableColumn.odds:
            comparison = compareNullsLast(a.odds, b.odds);
            break;
          case SortableColumn.carriedWeight:
            comparison = a.carriedWeight.compareTo(b.carriedWeight);
            break;
          case SortableColumn.horseWeight:
            final aWeight = int.tryParse(a.horseWeight?.split('(').first ?? '');
            final bWeight = int.tryParse(b.horseWeight?.split('(').first ?? '');
            comparison = compareNullsLast(aWeight, bWeight);
            break;
          case SortableColumn.overallScore:
            final aScore = _overallScores[a.horseId];
            final bScore = _overallScores[b.horseId];
            comparison = compareNullsLast(bScore, aScore);
            break;
          case SortableColumn.bestTime:
            final aTime = a.bestTimeStats?.timeInSeconds;
            final bTime = b.bestTimeStats?.timeInSeconds;
            comparison = compareNullsLast(aTime, bTime);
            break;
          case SortableColumn.fastestAgari:
            final aAgari = a.fastestAgariStats?.agariInSeconds;
            final bAgari = b.fastestAgariStats?.agariInSeconds;
            comparison = compareNullsLast(aAgari, bAgari);
            break;
          default:
            comparison = a.horseNumber.compareTo(b.horseNumber);
            break;
        }
        return _isAscending ? comparison : -comparison;
      });
    });
  }

  /// 各タブのDataTableを生成するための共通ラッパー
  Widget _buildDataTableForTab({
    required List<DataColumn2> columns,
    required List<PredictionHorseDetail> horses,
    required List<DataCell> Function(PredictionHorseDetail horse) cellBuilder,
  }) {
    return DataTable2(
      key: ValueKey(_predictionRaceData.hashCode),
      minWidth: 2000,
      fixedTopRows: 1,
      sortColumnIndex: columns.indexWhere((c) => (c.onSort != null)),
      sortAscending: _isAscending,
      columnSpacing: 6.0,
      headingRowHeight: 50,
      dataRowHeight: 60,
      headingTextStyle: const TextStyle(
        fontSize: 12.0, // ヘッダーの文字サイズ
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
      dataTextStyle: const TextStyle(
        fontSize: 14.0, // セルの文字サイズ
        color: Colors.black87,
      ),
      columns: columns,
      rows: horses.map((horse) => DataRow(cells: cellBuilder(horse))).toList(),
    );
  }

  /// 出走馬タブ
  Widget _buildStartersTab(List<PredictionHorseDetail> horses) {
    return _buildDataTableForTab(
      columns: [
        DataColumn2(label: const Text('印'), fixedWidth: 50, onSort: (i, asc) => _onSort(SortableColumn.mark)),
        DataColumn2(label: const Text('枠\n番'), fixedWidth: 40, onSort: (i, asc) => _onSort(SortableColumn.gateNumber)),
        DataColumn2(label: const Text('馬\n番'), fixedWidth: 40, onSort: (i, asc) => _onSort(SortableColumn.horseNumber)),
        DataColumn2(label: const Text('馬名'), fixedWidth: 130, onSort: (i, asc) => _onSort(SortableColumn.horseName)),
        DataColumn2(label: const Text('人気'), fixedWidth: 65, numeric: true, onSort: (i, asc) => _onSort(SortableColumn.popularity)),
        DataColumn2(label: const Text('オッズ'), fixedWidth: 70, numeric: true, onSort: (i, asc) => _onSort(SortableColumn.odds)),
      ],
      horses: horses,
      cellBuilder: (horse) => [
        DataCell(
          horse.isScratched
              ? const Text('取消', style: TextStyle(color: Colors.red))
              : _buildMarkDropdown(horse),
        ),
        DataCell(_buildGateNumber(horse.gateNumber)),
        DataCell(_buildHorseNumber(horse.horseNumber, horse.gateNumber)),
        DataCell(
          Text(
            horse.horseName,
            style: TextStyle(
              decoration: horse.isScratched ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        DataCell(Text(horse.popularity?.toString() ?? '--')),
        DataCell(Text(horse.odds?.toString() ?? '--')),
      ],
    );
  }

  /// 情報タブ
  Widget _buildInfoTab(List<PredictionHorseDetail> horses) {
    return _buildDataTableForTab(
      columns: [
        DataColumn2(label: const Text('印'), fixedWidth: 50, onSort: (i, asc) => _onSort(SortableColumn.mark)),
        DataColumn2(label: const Text('馬名'), fixedWidth: 150, onSort: (i, asc) => _onSort(SortableColumn.horseName)),
        DataColumn2(label: const Text('脚質'), fixedWidth: 130, onSort: (i, asc) => _onSort(SortableColumn.legStyle)),
        const DataColumn2(label: Text('性齢'), fixedWidth: 40),
        DataColumn2(label: const Text('斤量'), fixedWidth: 50, onSort: (i, asc) => _onSort(SortableColumn.carriedWeight)),
        DataColumn2(label: const Text('馬体重'), fixedWidth: 70, onSort: (i, asc) => _onSort(SortableColumn.horseWeight)),
        const DataColumn2(label: Text('前走馬体重'), fixedWidth: 70),
      ],
      horses: horses,
      cellBuilder: (horse) {
        String? parsedPreviousWeight;
        if (horse.previousHorseWeight != null && horse.previousHorseWeight!.contains('(')) {
          parsedPreviousWeight = horse.previousHorseWeight!.split('(').first;
        } else if (horse.previousHorseWeight != null) {
          parsedPreviousWeight = horse.previousHorseWeight;
        }
        return [
          DataCell(
            horse.isScratched
                ? const Text('取消', style: TextStyle(color: Colors.red))
                : _buildMarkDropdown(horse),
          ),
          DataCell(
            Text(
              horse.horseName,
              style: TextStyle(
                decoration: horse.isScratched ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          DataCell(LegStyleIndicator(legStyleProfile: horse.legStyleProfile)),
          DataCell(Text(horse.sexAndAge)),
          DataCell(Text(horse.carriedWeight.toString())),
          DataCell(Text(horse.horseWeight ?? '--')),
          DataCell(Text(parsedPreviousWeight ?? '--')),
        ];
      },
    );
  }


  /// 騎手・調教師タブ
  Widget _buildJockeyTrainerTab(List<PredictionHorseDetail> horses) {
    return _buildDataTableForTab(
      columns: [
        DataColumn2(label: const Text('印'), fixedWidth: 50, onSort: (i, asc) => _onSort(SortableColumn.mark)),
        DataColumn2(label: const Text('馬名'), fixedWidth: 150, onSort: (i, asc) => _onSort(SortableColumn.horseName)),
        const DataColumn2(label: Text('騎手'), fixedWidth: 80),
        const DataColumn2(label: Text('前走騎手'), fixedWidth: 80),
        const DataColumn2(label: Text('所属'), fixedWidth: 50),
        const DataColumn2(label: Text('調教師'), fixedWidth: 80),
        const DataColumn2(label: Text('馬主'), fixedWidth: 250),
      ],
      horses: horses,
      cellBuilder: (horse) => [
        DataCell(
          horse.isScratched
              ? const Text('取消', style: TextStyle(color: Colors.red))
              : _buildMarkDropdown(horse),
        ),
        DataCell(
          Text(
            horse.horseName,
            style: TextStyle(
              decoration: horse.isScratched ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        DataCell(Text(horse.jockey)),
        DataCell(Text(horse.previousJockey ?? '--')),
        DataCell(Text(horse.trainerAffiliation)),
        DataCell(Text(horse.trainerName)),
        DataCell(Text(horse.ownerName ?? '--')),
      ],
    );
  }

  /// 分析タブ
  Widget _buildAnalysisTab(List<PredictionHorseDetail> horses) {
    return _buildDataTableForTab(
      columns: [
        DataColumn2(label: const Text('印'), fixedWidth: 50, onSort: (i, asc) => _onSort(SortableColumn.mark)),
        DataColumn2(label: const Text('馬名'), fixedWidth: 150, onSort: (i, asc) => _onSort(SortableColumn.horseName)),
        DataColumn2(label: const Text('総合評価'), fixedWidth: 80, onSort: (i, asc) => _onSort(SortableColumn.overallScore)),
        const DataColumn2(label: Text('条件適性'), fixedWidth: 80,),
        DataColumn2(
          label: Row(
            children: [
              const Text('距離適性'),
              _buildHelpIcon('距離・コース適性', 'コース種別・距離が今回と完全に一致した過去レースでの成績を「1着-2着-3着-着外」で表示します。'),
            ],
          ),
          fixedWidth: 100,
        ),
        DataColumn2(
          label: Row(
            children: [
              const Text('馬場適性'),
              _buildHelpIcon('馬場適性', '良馬場と道悪（稍重・重・不良）での複勝率を比較し、道悪でのパフォーマンスを評価します。'),
            ],
          ),
          fixedWidth: 120,
        ),
      ],
      horses: horses,
      cellBuilder: (horse) {
        final score = _overallScores[horse.horseId] ?? 0.0;
        final rank = _getRankFromScore(score);
        final fitResult = _conditionFits[horse.horseId];
        final distanceCourseStats = horse.distanceCourseAptitudeStats;
        final trackAptitudeLabel = horse.trackAptitudeLabel ?? '－';
        return [
          DataCell(
            horse.isScratched
                ? const Text('取消', style: TextStyle(color: Colors.red))
                : _buildMarkDropdown(horse),
          ),
          DataCell(
            Text(
              horse.horseName,
              style: TextStyle(
                decoration: horse.isScratched ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          DataCell(
            Text(
              '$rank (${score.toStringAsFixed(1)})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataCell(_buildConditionFitCell(fitResult)),
          DataCell(
            Text(
              (distanceCourseStats == null || distanceCourseStats.raceCount == 0) ? '-' : distanceCourseStats.recordString,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          DataCell(
            Text(
              trackAptitudeLabel,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: trackAptitudeLabel.contains('◎') ? Colors.red : (trackAptitudeLabel.contains('✕') ? Colors.blue : Colors.black87),
              ),
            ),
          ),
        ];
      },
    );
  }

  /// 時計タブ
  Widget _buildTimeTab(List<PredictionHorseDetail> horses) {
    return _buildDataTableForTab(
      columns: [
        DataColumn2(label: const Text('印'), fixedWidth: 50, onSort: (i, asc) => _onSort(SortableColumn.mark)),
        DataColumn2(label: const Text('馬名'), fixedWidth: 150, onSort: (i, asc) => _onSort(SortableColumn.horseName)),
        DataColumn2(label: const Text('持ち時計'), fixedWidth: 80, numeric: true, onSort: (i, asc) => _onSort(SortableColumn.bestTime)),
        const DataColumn2(label: Text('馬場\n(記録時)'), fixedWidth: 60),
        DataColumn2(label: const Text('最速上がり'), fixedWidth: 80, numeric: true, onSort: (i, asc) => _onSort(SortableColumn.fastestAgari)),
      ],
      horses: horses,
      cellBuilder: (horse) {
        final bestTime = horse.bestTimeStats;
        final fastestAgari = horse.fastestAgariStats;
        return [
          DataCell(
            horse.isScratched
                ? const Text('取消', style: TextStyle(color: Colors.red))
                : _buildMarkDropdown(horse),
          ),
          DataCell(
            Text(
              horse.horseName,
              style: TextStyle(
                decoration: horse.isScratched ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          DataCell(
            JustTheTooltip(
              triggerMode: TooltipTriggerMode.tap,
              backgroundColor: const Color.fromRGBO(0, 0, 0, 0.5),
              content: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(bestTime != null ? '${bestTime.date}\n${bestTime.raceName}' : 'データなし',
                  style: const TextStyle(color: Colors.white),),
              ),
              child: Text(bestTime?.formattedTime ?? '-'),
            ),
          ),
          DataCell(Text(bestTime?.trackCondition ?? '-')),
          DataCell(
            JustTheTooltip(
              triggerMode: TooltipTriggerMode.tap,
              backgroundColor: const Color.fromRGBO(0, 0, 0, 0.5),
              content: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(fastestAgari != null ? '${
                    fastestAgari.date}\n${
                    fastestAgari.raceName}\n馬場: ${
                    fastestAgari.trackCondition}' : 'データなし',
                  style: const TextStyle(color: Colors.white),),
              ),
              child: Text(fastestAgari?.formattedAgari ?? '-'),
            ),
          ),
        ];
      },
    );
  }

  /// 成績タブ
  Widget _buildPerformanceTab(List<PredictionHorseDetail> horses) {
    return _buildDataTableForTab(
      columns: [
        DataColumn2(label: const Text('印'), fixedWidth: 50, onSort: (i, asc) => _onSort(SortableColumn.mark)),
        DataColumn2(label: const Text('馬名'), fixedWidth: 150, onSort: (i, asc) => _onSort(SortableColumn.horseName)),
        const DataColumn2(label: Text('間隔/距離'), fixedWidth: 70),
        const DataColumn2(label: SizedBox(width: 120, child: Text('前走'))),
        const DataColumn2(label: Text('間隔/距離'), fixedWidth: 70),
        const DataColumn2(label: SizedBox(width: 120, child: Text('前々走'))),
        const DataColumn2(label: Text('間隔/距離'), fixedWidth: 70),
        const DataColumn2(label: SizedBox(width: 120, child: Text('3走前'))),
        const DataColumn2(label: Text('間隔/距離'), fixedWidth: 70),
        const DataColumn2(label: SizedBox(width: 120, child: Text('4走前'))),
        const DataColumn2(label: Text('間隔/距離'), fixedWidth: 70),
        const DataColumn2(label: SizedBox(width: 120, child: Text('5走前'))),
      ],
      horses: horses,
      cellBuilder: (horse) => [
        DataCell(
          horse.isScratched
              ? const Text('取消', style: TextStyle(color: Colors.red))
              : _buildMarkDropdown(horse),
        ),
        DataCell(
          Text(
            horse.horseName,
            style: TextStyle(
              decoration: horse.isScratched ? TextDecoration.lineThrough : null,
            ),
          ),
        ),
        ..._buildPerformanceCells(horse.horseId),
      ],
    );
  }

  Widget _buildMemoTab(List<PredictionHorseDetail> horses) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_note, size: 16),
                label: const Text('一括編集'),
                onPressed: () async {
                  if (_predictionRaceData == null) return;
                  final result = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BulkMemoEditPage(
                        horses: _predictionRaceData!.horses,
                        raceId: widget.raceId,
                      ),
                    ),
                  );
                  if (result == true) {
                    _loadShutubaData();
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.file_download, size: 16),
                label: const Text('インポート'),
                onPressed: _importMemosFromCsv,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.ios_share, size: 16),
                label: const Text('エクスポート'),
                onPressed: () {
                  if (_predictionRaceData != null) {
                    _exportMemosAsCsv(_predictionRaceData!);
                  }
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _buildDataTableForTab(
            columns: [
              DataColumn2(label: const Text('印'), fixedWidth: 80, onSort: (i, asc) => _onSort(SortableColumn.mark)),
              DataColumn2(label: const Text('馬名'), fixedWidth: 150, onSort: (i, asc) => _onSort(SortableColumn.horseName)),
              const DataColumn2(label: Text('メモ'), size: ColumnSize.L),
            ],
            horses: horses,
            cellBuilder: (horse) => [
              DataCell(
                horse.isScratched
                    ? const Text('取消', style: TextStyle(color: Colors.red))
                    : _buildMarkDropdown(horse),
              ),
              DataCell(
                Text(
                  horse.horseName,
                  style: TextStyle(
                    decoration: horse.isScratched ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              DataCell(_buildMemoCell(horse)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMarkDropdown(PredictionHorseDetail horse) {
    return PopupMenuButton<String>(
      constraints: const BoxConstraints(
        minWidth: 2.0 * 24.0, // 最小幅を指定
        maxWidth: 2.0 * 24.0,  // 最大幅を指定
      ),

      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        ...['◎', '〇', '▲', '△', '✕', '★'].map((String value) {
          return PopupMenuItem<String>(
            value: value,
            height: 36, // 高さを詰める
            child: Center(child: Text(value)), // 中央揃えにする
          );
        }),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '消',
          height: 36, // 高さを詰める
          child: Center(child: Text('消')), // 中央揃えにする
        ),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(
          value: '--',
          height: 36, // 高さを詰める
          child: Center(child: Text('--')), // 中央揃えにする
        ),
      ],
      onSelected: (String newValue) {
        final userId = localUserId;
        if (userId == null) return;

        if (newValue == '--') {
          if (horse.userMark != null) {
            setState(() {
              horse.userMark = null;
            });
            _deleteMarkAndSaveInBackground(horse);
          }
        } else {
          final userMark = UserMark(
            userId: userId,
            raceId: widget.raceId,
            horseId: horse.horseId,
            mark: newValue,
            timestamp: DateTime.now(),
          );
          setState(() {
            horse.userMark = userMark;
          });
          _updateMarkAndSaveInBackground(userMark);
        }
      },
      padding: EdgeInsets.zero,
      child: Center(
        child: Text(
          horse.userMark?.mark ?? '--',
          style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildMemoCell(PredictionHorseDetail horse) {
    bool hasMemo = horse.userMemo?.predictionMemo != null && horse.userMemo!.predictionMemo!.isNotEmpty;
    return Row(
      children: [
        IconButton(
          icon: Icon(
            hasMemo ? Icons.speaker_notes : Icons.speaker_notes_off_outlined,
            color: hasMemo ? Colors.blueAccent : Colors.grey,
            size: 20,
          ),
          onPressed: horse.isScratched ? null : () => _showMemoDialog(horse),
        ),
        Expanded(
          child: Text(
            horse.userMemo?.predictionMemo ?? '',
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }

  /// 枠番表示を作成
  Widget _buildGateNumber(int gateNumber) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: _getGateColor(gateNumber),
        border: gateNumber == 1 ? Border.all(color: Colors.grey) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        gateNumber.toString(),
        style: TextStyle(
          color: _getTextColorForGate(gateNumber),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// 馬番表示を作成
  Widget _buildHorseNumber(int horseNumber, int gateNumber) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        border: Border.all(
          color: _getGateColor(gateNumber),
          width: 2.0,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        horseNumber.toString(),
        style: TextStyle(
          color: _getGateColor(gateNumber) == Colors.black ? Colors.black : Colors.black87,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }


  Widget _buildPastRaceDetailCard(HorseRaceRecord record, HorseResult? horseResult) {

    final isHighlighted = record.raceId.isNotEmpty && record.raceId == _highlightedRaceId;
    final textColor = isHighlighted ? Colors.white : Colors.black87;
    final rankInt = int.tryParse(record.rank);
    Color backgroundColor = Colors.transparent;
    if (isHighlighted) {
      backgroundColor = Colors.black54;
    } else if (rankInt != null) {
      if (rankInt == 1) backgroundColor = Colors.red.withAlpha(30);
      if (rankInt == 2) backgroundColor = Colors.blue.withAlpha(30);
      if (rankInt == 3) backgroundColor = Colors.yellow.withAlpha(80);
    }

    // 脚質を簡易判定
    final legStyle = RaceDataParser.getSimpleLegStyle(record.cornerPassage, record.numberOfHorses);

    String extractedGrade = '';
    final gradePattern = RegExp(r'\((J\.?G[I]{1,3}|G[I]{1,3})\)', caseSensitive: false);
    final match = gradePattern.firstMatch(record.raceName);
    if (match != null) extractedGrade = match.group(1)!;
    final gradeColor = getGradeColor(extractedGrade);

    // 2種類の着差を結合して表示用文字列を作成
    final timeDiffMargin = record.margin; // タイム差（例: "3.3"）
    final stringMargin = horseResult?.margin ?? ''; // 文字列着差（例: "ハナ"）
    String displayMargin = timeDiffMargin; // デフォルトはタイム差

    if (stringMargin.isNotEmpty && timeDiffMargin.isNotEmpty) {
      displayMargin = '$stringMargin / $timeDiffMargin';
    } else if (stringMargin.isNotEmpty) {
      displayMargin = stringMargin;
    }

    return GestureDetector(
      onTap: () {
        if (record.raceId.isNotEmpty) {
          setState(() {
            if (_highlightedRaceId == record.raceId) {
              _highlightedRaceId = null; // Toggle off
            } else {
              _highlightedRaceId = record.raceId; // Toggle on
            }
          });
        }
      },
      child: Container(
        width: 270,
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: gradeColor, width: 5.0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- 左列 (着順/印・人気・脚質) ---
            Container(
              width: 50,
              height: 80,
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border(right: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      FutureBuilder<UserMark?>(
                        future: _dbHelper.getUserMark(localUserId!, record.raceId, record.horseId),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data?.mark != null) {
                            return Text(
                              snapshot.data!.mark,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: isHighlighted ? Color.fromRGBO(255, 255, 255, 0.30) : Color.fromRGBO(0, 0, 0, 0.20),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            record.rank,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: ['1','2','3'].contains(record.rank)
                                  ? Colors.red
                                  : textColor,
                            ),
                          ),

                          Text(
                            '${record.popularity}人気',
                            style: TextStyle(fontSize: 11, color: textColor),
                          ),
                          Text(
                            legStyle,
                            style: TextStyle(fontSize: 11, color: textColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // --- 中央・右列 (レース詳細) ---
            Expanded(
              child: Container( // 背景色を適用するためにContainerでラップ
                color: backgroundColor,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 4.0, 4.0, 4.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('${record.venue.replaceAll(RegExp(r'\d'), '')} ${record.weather}/${record.trackCondition}/${record.numberOfHorses}頭', style: TextStyle(fontSize: 11, color: textColor), overflow: TextOverflow.ellipsis)),
                          Text(record.time, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('${record.raceName.replaceAll(RegExp(r'\((J\.?G[I]{1,3}|G[I]{1,3})\)', caseSensitive: false), '').trim()}/${record.distance}', style: TextStyle(fontSize: 11, color: textColor), overflow: TextOverflow.ellipsis)),
                          Text(record.agari, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text('${record.horseNumber}番 ${record.horseWeight} ${record.jockey}(${record.carriedWeight})', style: TextStyle(fontSize: 11, color: textColor), overflow: TextOverflow.ellipsis)),
                          Text(displayMargin, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 過去5走分のセルを作成
  List<DataCell> _buildPerformanceCells(String horseId) {
    // 競走成績と、それに紐づく全レース結果をまとめて非同期で取得するFutureを作成
    final futurePerformanceData = Future<_PerformanceData>(() async {
      final records = await _dbHelper.getHorsePerformanceRecords(horseId);
      final raceIds = records.map((r) => r.raceId).where((id) => id.isNotEmpty).toSet().toList();
      final raceResults = await _dbHelper.getMultipleRaceResults(raceIds);
      return _PerformanceData(records, raceResults);
    });

    final List<DataCell> cells = [];

    // 前走との間隔を表示するセル
    cells.add(DataCell(
      FutureBuilder<_PerformanceData>(
        future: futurePerformanceData,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.records.isNotEmpty) {
            final currentRace = _predictionRaceData!;
            final previousRace = snapshot.data!.records.first;
            final interval = RaceIntervalAnalyzer.formatRaceInterval(currentRace.raceDate, previousRace.date);
            final distanceChange = RaceIntervalAnalyzer.formatDistanceChange(currentRace.raceDetails1 ?? '', previousRace.distance);
            return _buildIntervalCell(interval, distanceChange);
          }
          return const SizedBox(width: 70);
        },
      ),
    ));

    // 過去5走分のセル
    for (int i = 0; i < 5; i++) {
      cells.add(DataCell(
        FutureBuilder<_PerformanceData>(
          future: futurePerformanceData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data!.records.length > i) {
              final record = snapshot.data!.records[i];
              final raceResult = snapshot.data!.raceResults[record.raceId];
              HorseResult? horseResultInRace;
              if (raceResult != null) {
                try {
                  horseResultInRace = raceResult.horseResults.firstWhere((hr) => hr.horseId == record.horseId);
                } catch (e) {
                  // just in case
                }
              }
              // 両方のデータをカード生成ウィジェットに渡す
              return _buildPastRaceDetailCard(record, horseResultInRace);
            }
            return const SizedBox(width: 250);
          },
        ),
      ));

      // 4走前までのレース間隔を表示
      if (i < 4) {
        cells.add(DataCell(
          FutureBuilder<_PerformanceData>(
            future: futurePerformanceData,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.records.length > i + 1) {
                final current = snapshot.data!.records[i];
                final previous = snapshot.data!.records[i + 1];
                final interval = RaceIntervalAnalyzer.formatRaceInterval(current.date, previous.date);
                final distanceChange = RaceIntervalAnalyzer.formatDistanceChange(current.distance, previous.distance);
                return _buildIntervalCell(interval, distanceChange);
              }
              return const SizedBox(width: 70);
            },
          ),
        ));
      }
    }
    return cells;
  }
  Widget _buildIntervalCell(String interval, String distanceChange) {
    Color distanceColor;
    switch (distanceChange) {
      case '延長': distanceColor = Colors.blue; break;
      case '短縮': distanceColor = Colors.red; break;
      default: distanceColor = Colors.black87;
    }
    return SizedBox(
      width: 70,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(interval, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          Text(distanceChange, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: distanceColor)),
        ],
      ),
    );
  }

  Color _getGateColor(int gateNumber) {
    switch (gateNumber) {
      case 1: return Colors.white;
      case 2: return Colors.black;
      case 3: return Colors.red;
      case 4: return Colors.blue;
      case 5: return Colors.yellow;
      case 6: return Colors.green;
      case 7: return Colors.orange;
      case 8: return Colors.pink.shade200;
      default: return Colors.grey;
    }
  }

  Color _getTextColorForGate(int gateNumber) {
    switch (gateNumber) {
      case 1:
      case 5:
        return Colors.black;
      default:
        return Colors.white;
    }
  }

  Widget _buildHelpIcon(String title, String content) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) =>
              AlertDialog(
                title: Text(title),
                content: Text(content),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('閉じる'),
                  ),
                ],
              ),
        );
      },
      child: const Padding(
        padding: EdgeInsets.only(left: 4.0),
        child: Icon(Icons.help_outline, color: Colors.grey, size: 16),
      ),
    );
  }
}