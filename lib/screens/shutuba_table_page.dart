// lib/screens/shutuba_table_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart';
import 'package:hetaumakeiba_v2/services/shutuba_table_scraper_service.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/main.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:hetaumakeiba_v2/logic/ai_prediction_analyzer.dart';
import 'package:hetaumakeiba_v2/screens/ai_comprehensive_prediction_page.dart';
import 'package:hetaumakeiba_v2/screens/race_statistics_page.dart';
import 'package:hetaumakeiba_v2/utils/grade_utils.dart';
import 'package:hetaumakeiba_v2/screens/horse_stats_page.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:hetaumakeiba_v2/widgets/themed_tab_bar.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/screens/bulk_memo_edit_page.dart';
import 'package:hetaumakeiba_v2/models/shutuba_table_cache_model.dart';
import 'package:hetaumakeiba_v2/services/ai_prediction_service.dart';
import 'package:hetaumakeiba_v2/widgets/race_header_card.dart';
import 'package:hetaumakeiba_v2/models/complex_aptitude_model.dart';
import 'package:hetaumakeiba_v2/models/best_time_stats_model.dart';
import 'package:hetaumakeiba_v2/models/fastest_agari_stats_model.dart';

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
}


class ShutubaTablePage extends StatefulWidget {
  final String raceId;
  final RaceResult? raceResult;

  const ShutubaTablePage({super.key, required this.raceId, this.raceResult});

  @override
  State<ShutubaTablePage> createState() => _ShutubaTablePageState();
}

class _ShutubaTablePageState extends State<ShutubaTablePage> with SingleTickerProviderStateMixin {
  PredictionRaceData? _predictionRaceData;
  bool _isLoading = true;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ShutubaTableScraperService _scraperService = ShutubaTableScraperService();
  final AiPredictionService _predictionService = AiPredictionService();
  Map<String, double> _overallScores = {};
  Map<String, double> _expectedValues = {};
  Map<String, String> _legStyles = {};
  Map<String, ConditionFitResult> _conditionFits = {};

  SortableColumn _sortColumn = SortableColumn.horseNumber;
  bool _isAscending = true;
  late TabController _tabController;
  bool _isCardExpanded = true;


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
      if (widget.raceResult != null) {
        data = _createPredictionDataFromRaceResult(widget.raceResult!);
      } else {
        final cache = await _dbHelper.getShutubaTableCache(widget.raceId);
        if (cache != null && !refresh) {
          data = cache.predictionRaceData;
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

      if (data != null) {
        await _calculatePredictionScores(data);
      }
      if (mounted) {
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
      final updatedHorsesData = await _scraperService.scrapeDynamicData(widget.raceId);

      if (_predictionRaceData != null) {
        final staticDataMap = {for (var h in _predictionRaceData!.horses) h.horseId: h};

        // 1. 最新の出走馬リストを基準に、新しい馬リストを再構築
        final newHorsesList = updatedHorsesData.map((updatedHorse) {
          final oldHorseData = staticDataMap[updatedHorse.horseId];

          // 2. 最新の動的情報と、既存の静的情報を組み合わせて新しいオブジェクトを作成
          return PredictionHorseDetail(
            horseId: updatedHorse.horseId,
            horseNumber: updatedHorse.horseNumber,
            gateNumber: updatedHorse.gateNumber,
            horseName: updatedHorse.horseName,
            sexAndAge: updatedHorse.sexAndAge,
            jockey: updatedHorse.jockey,
            carriedWeight: updatedHorse.carriedWeight,
            trainerName: updatedHorse.trainerName,
            trainerAffiliation: updatedHorse.trainerAffiliation,
            isScratched: updatedHorse.isScratched,
            odds: updatedHorse.odds,
            popularity: updatedHorse.popularity,
            horseWeight: updatedHorse.horseWeight,
            userMark: oldHorseData?.userMark,
            userMemo: oldHorseData?.userMemo,
          );
        }).toList();

        // 3. 新しい馬リストを使って、レースデータ全体を新しく作成
        final newRaceData = PredictionRaceData(
          raceId: _predictionRaceData!.raceId,
          raceName: _predictionRaceData!.raceName,
          raceDate: _predictionRaceData!.raceDate,
          venue: _predictionRaceData!.venue,
          raceNumber: _predictionRaceData!.raceNumber,
          shutubaTableUrl: _predictionRaceData!.shutubaTableUrl,
          raceGrade: _predictionRaceData!.raceGrade,
          raceDetails1: _predictionRaceData!.raceDetails1,
          horses: newHorsesList, // 再構築した馬リストを使用
          racePacePrediction: _predictionRaceData!.racePacePrediction,
        );

        // 4. データベースキャッシュを更新
        final newCache = ShutubaTableCache(
          raceId: widget.raceId,
          predictionRaceData: newRaceData,
          lastUpdatedAt: DateTime.now(),
        );
        await _dbHelper.insertOrUpdateShutubaTableCache(newCache);

        // 5. 新しいオブジェクトで状態を丸ごと入れ替える
        setState(() {
          _predictionRaceData = newRaceData;
        });

        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('情報を更新しました。')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('情報の更新に失敗しました: $e')));
    }
  }


  Future<void> _calculatePredictionScores(PredictionRaceData raceData) async {
    final scores = await _predictionService.calculatePredictionScores(
      raceData,
      widget.raceId,
    );

    if (mounted) {
      setState(() {
        _overallScores = scores.overallScores;
        _expectedValues = scores.expectedValues;
        _legStyles = scores.legStyles;
        _conditionFits = scores.conditionFits;
      });
    }
  }

  // ランク表示用のヘルパー関数
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
      // 複合適性分析を実行し、結果をセットする
      horse.complexAptitudeStats = AiPredictionAnalyzer.analyzeComplexAptitude(
        raceData: raceData,
        pastRecords: pastRecords,
      );
      horse.bestTimeStats = AiPredictionAnalyzer.analyzeBestTime(
        raceData: raceData,
        pastRecords: pastRecords,
      );
      horse.fastestAgariStats = AiPredictionAnalyzer.analyzeFastestAgari(
        pastRecords: pastRecords,
      );
    }

    raceData.racePacePrediction = AiPredictionAnalyzer.predictRacePace(raceData.horses, allPastRecords);

    return raceData;
  }

  /// 過去レースの詳細情報をポップアップで表示するメソッド
  void _showPastRaceDetailsPopup(BuildContext context, HorseRaceRecord record) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(record.raceName),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                _buildDetailRow('日付:', record.date),
                _buildDetailRow('開催:', record.venue),
                _buildDetailRow('天候/馬場:', '${record.weather} / ${record.trackCondition}'),
                _buildDetailRow('R:', record.raceNumber),
                _buildDetailRow('頭数:', record.numberOfHorses),
                _buildDetailRow('枠/馬:', '${record.frameNumber} / ${record.horseNumber}'),
                _buildDetailRow('人気/オッズ:', '${record.popularity}番人気 / ${record.odds}倍'),
                _buildDetailRow('着順:', record.rank),
                _buildDetailRow('騎手/斤量:', '${record.jockey} / ${record.carriedWeight}kg'),
                _buildDetailRow('距離:', record.distance),
                _buildDetailRow('タイム/着差:', '${record.time} / ${record.margin}'),
                _buildDetailRow('通過:', record.cornerPassage),
                _buildDetailRow('ペース/上り:', '${record.pace} / ${record.agari}'),
                _buildDetailRow('馬体重:', record.horseWeight),
                _buildDetailRow('勝ち馬:', record.winnerOrSecondHorse),
                _buildDetailRow('賞金:', record.prizeMoney),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('閉じる'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  /// ポップアップ内の詳細表示用のヘルパーウィジェット
  Widget _buildDetailRow(String label, String value) {
    if (value.trim().isEmpty || value.trim() == '-') {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
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
                  _loadShutubaData();
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
    // ヘッダー行
    rows.add(['raceId', 'horseId', 'horseNumber', 'horseName', 'predictionMemo', 'reviewMemo']);

    // データ行
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
      // ヘッダーの検証
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

  Future<void> _navigateToStatisticsPage() async {
    RaceStatistics? stats;
    try {
      stats = await _dbHelper.getRaceStatistics(widget.raceId);
    } catch (e) {
      print('統計データの読み込みに失敗: $e');
      stats = null;
    }
    if (stats == null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('過去データの取得'),
          content: const Text('このレースの過去10年分のデータを取得しますか？\nデータ量に応じて時間がかかる場合があります。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('取得する'),
            ),
          ],
        ),
      );

      if (confirm != true || !mounted) return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RaceStatisticsPage(
          raceId: widget.raceId,
          raceName: _predictionRaceData!.raceName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        _buildCollapsibleRaceInfoCard(_predictionRaceData!),
        Expanded(
          child: IgnorePointer(
            ignoring: _isCardExpanded,
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
                        // ソート処理
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
        ),
      ],
    );
  }

  /// 折りたたみ可能なレース情報カードを構築する
  Widget _buildCollapsibleRaceInfoCard(PredictionRaceData race) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _isCardExpanded = !_isCardExpanded;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _isCardExpanded
                ? _buildExpandedCardContent(race)
                : _buildCollapsedCardContent(race),
          ),
        ),
      ),
    );
  }

  /// 展開時のカード内容
  Widget _buildExpandedCardContent(PredictionRaceData race) {
    String title = race.raceName;
    String details = race.raceGrade ?? '';
    if (widget.raceResult != null) {
      title = widget.raceResult!.raceTitle;
      details = widget.raceResult!.raceGrade;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.expand_less),
          ],
        ),
        // 共通ヘッダーウィジェット
        RaceHeaderCard(
          title: title,
          detailsLine1: '${race.raceDate} ${race.venue}',
          detailsLine2: race.raceDetails1 ?? details,
        ),
        if (widget.raceResult == null)
          ElevatedButton.icon(
            onPressed: _updateDynamicData,
            icon: const Icon(Icons.refresh),
            label: const Text('出馬表更新'),
          ),
        const Divider(),
        ListTile(
          visualDensity: const VisualDensity(vertical: -4.0),
          leading: Icon(Icons.analytics_outlined, color: Theme.of(context).primaryColor),
          title: Text(
            'AI総合予測を見る',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
              fontSize: 14.0,
            ),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ComprehensivePredictionPage(
                  raceData: _predictionRaceData!,
                  overallScores: _overallScores,
                  expectedValues: _expectedValues,
                ),
              ),
            );
          },
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.history),
          title: const Text(
            '過去データ分析',
            style: TextStyle(fontSize: 14.0),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: _navigateToStatisticsPage,
        ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.group),
          title: const Text(
            '全出走馬データ分析',
            style: TextStyle(fontSize: 14.0),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            if (_predictionRaceData != null) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => HorseStatsPage(
                    raceId: widget.raceId,
                    raceName: _predictionRaceData!.raceName,
                    horses: _predictionRaceData!.horses,
                  ),
                ),
              );
            }
          },
        ),
        const Divider(),
      ],
    );
  }

  /// 折りたたみ時のカード内容
  Widget _buildCollapsedCardContent(PredictionRaceData race) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            race.raceName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const Icon(Icons.expand_more),
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
      minWidth: 800,
      fixedTopRows: 1,
      sortColumnIndex: columns.indexWhere((c) => (c.onSort != null)),
      sortAscending: _isAscending,
      columnSpacing: 8.0,
      headingRowHeight: 40,
      dataRowHeight: 48,
      columns: columns,
      rows: horses.map((horse) => DataRow(cells: cellBuilder(horse))).toList(),
    );
  }

  /// 出走馬タブ
  Widget _buildStartersTab(List<PredictionHorseDetail> horses) {
    return _buildDataTableForTab(
      columns: [
        DataColumn2(label: const Text('印'), fixedWidth: 50, onSort: (i, asc) => _onSort(SortableColumn.mark)),
        DataColumn2(label: const Text('枠'), fixedWidth: 45, onSort: (i, asc) => _onSort(SortableColumn.gateNumber)),
        DataColumn2(label: const Text('番'), fixedWidth: 45, onSort: (i, asc) => _onSort(SortableColumn.horseNumber)),
        DataColumn2(label: const Text('馬名'), fixedWidth: 150, onSort: (i, asc) => _onSort(SortableColumn.horseName)), // 馬名の幅を150pxに固定
        DataColumn2(label: const Text('人気'), fixedWidth: 50, numeric: true, onSort: (i, asc) => _onSort(SortableColumn.popularity)),
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
      ],
    );
  }

  /// 情報タブ
  Widget _buildInfoTab(List<PredictionHorseDetail> horses) {
    return _buildDataTableForTab(
      columns: [
        DataColumn2(label: const Text('印'), fixedWidth: 50, onSort: (i, asc) => _onSort(SortableColumn.mark)),
        DataColumn2(label: const Text('馬名'), fixedWidth: 150,  onSort: (i, asc) => _onSort(SortableColumn.horseName)),
        DataColumn2(label: const Text('オッズ'), fixedWidth: 70, numeric: true, onSort: (i, asc) => _onSort(SortableColumn.odds)),
        const DataColumn2(label: Text('性齢'), fixedWidth: 40,),
        DataColumn2(label: const Text('斤量'), fixedWidth: 50, onSort: (i, asc) => _onSort(SortableColumn.carriedWeight)),
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
        DataCell(Text(horse.odds?.toString() ?? '--')),
        DataCell(Text(horse.sexAndAge)),
        DataCell(Text(horse.carriedWeight.toString())),
      ],
    );
  }

  /// 騎手・調教師タブ
  Widget _buildJockeyTrainerTab(List<PredictionHorseDetail> horses) {
    return _buildDataTableForTab(
      columns: [
        DataColumn2(label: const Text('印'), fixedWidth: 50, onSort: (i, asc) => _onSort(SortableColumn.mark)),
        DataColumn2(label: const Text('馬名'), fixedWidth: 150, onSort: (i, asc) => _onSort(SortableColumn.horseName)),
        const DataColumn2(label: Text('騎手'), fixedWidth: 70,),
        const DataColumn2(label: Text('所属'), fixedWidth: 50,),
        const DataColumn2(label: Text('調教師'), fixedWidth: 70,),
        DataColumn2(label: const Text('馬体重'), fixedWidth: 70, onSort: (i, asc) => _onSort(SortableColumn.horseWeight)),
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
        DataCell(Text(horse.trainerAffiliation)),
        DataCell(Text(horse.trainerName)),
        DataCell(Text(horse.horseWeight ?? '--')),
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
        const DataColumn2(label: Text('複合適性'), fixedWidth: 80,),
      ],
      horses: horses,
      cellBuilder: (horse) {
        final score = _overallScores[horse.horseId] ?? 0.0;
        final rank = _getRankFromScore(score);
        final fitResult = _conditionFits[horse.horseId];
        final complexStats = horse.complexAptitudeStats;
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
            Tooltip(
              message: '複勝率: ${complexStats?.showRate.toStringAsFixed(1) ?? '0.0'}%',
              child: Text(
                (complexStats == null || complexStats.raceCount == 0) ? '-' : complexStats.recordString,
                style: const TextStyle(fontWeight: FontWeight.bold),
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
        const DataColumn2(label: Text('記録時馬場'), fixedWidth: 80),
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
            Tooltip(
              message: bestTime != null ? '${bestTime.date}\n${bestTime.raceName}' : 'データなし',
              child: Text(bestTime?.formattedTime ?? '-'),
            ),
          ),
          DataCell(Text(bestTime?.trackCondition ?? '-')),
          DataCell(
            Tooltip(
              message: fastestAgari != null ? '${fastestAgari.date}\n${fastestAgari.raceName}\n馬場: ${fastestAgari.trackCondition}' : 'データなし',
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
        const DataColumn2(label: SizedBox(width: 120, child: Text('前走'))),
        const DataColumn2(label: SizedBox(width: 120, child: Text('前々走'))),
        const DataColumn2(label: SizedBox(width: 120, child: Text('3走前'))),
        const DataColumn2(label: SizedBox(width: 120, child: Text('4走前'))),
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
        ..._buildPastRaceCells(horse.horseId),
      ],
    );
  }

  /// メモタブ
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
              const DataColumn2(label: Text('メモ'), fixedWidth: 50,),
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

  /// 印のポップアップメニューを作成
  Widget _buildMarkDropdown(PredictionHorseDetail horse) {
    return PopupMenuButton<String>(
      // セル内に表示するウィジェット
      constraints: const BoxConstraints(
        minWidth: 2.0 * 24.0, // 最小幅を指定
        maxWidth: 2.0 * 24.0,  // 最大幅を指定
      ),

      // ポップアップメニューの項目
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
      ],
      onSelected: (String newValue) async {
        final userId = localUserId;
        if (userId != null) {
          final userMark = UserMark(
            userId: userId,
            raceId: widget.raceId,
            horseId: horse.horseId,
            mark: newValue,
            timestamp: DateTime.now(),
          );
          await _dbHelper.insertOrUpdateUserMark(userMark);
          setState(() {
            horse.userMark = userMark;
          });
        }
      },
      padding: EdgeInsets.zero,
      child: Center(
        child: Text(
          horse.userMark?.mark ?? '--', // 選択されていれば印、なければ空白
          style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildMemoCell(PredictionHorseDetail horse) {
    bool hasMemo = horse.userMemo?.predictionMemo != null && horse.userMemo!.predictionMemo!.isNotEmpty;
    return IconButton(
      icon: Icon(
        hasMemo ? Icons.speaker_notes : Icons.speaker_notes_off_outlined,
        color: hasMemo ? Colors.blueAccent : Colors.grey,
        size: 20,
      ),
      onPressed: horse.isScratched ? null : () => _showMemoDialog(horse),
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

  /// 過去5走分のセルを作成
  List<DataCell> _buildPastRaceCells(String horseId) {
    return [
      for (int i = 0; i < 5; i++)
        DataCell(
          FutureBuilder<List<HorseRaceRecord>>(
            future: _dbHelper.getHorsePerformanceRecords(horseId),
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.length > i) {
                final record = snapshot.data![i];

                String extractedGrade = '';
                final gradePattern = RegExp(r'\((J\.?G[I]{1,3}|G[I]{1,3})\)', caseSensitive: false);
                final match = gradePattern.firstMatch(record.raceName);
                if (match != null) {
                  extractedGrade = match.group(1)!;
                }

                final gradeColor = getGradeColor(extractedGrade);

                Color backgroundColor = Colors.transparent;
                bool isTopThree = false;

                switch (record.rank) {
                  case '1':
                    backgroundColor = Colors.red.withAlpha((0.4 * 255).toInt()); // 赤 40% 不透明
                    isTopThree = true;
                    break;
                  case '2':
                    backgroundColor = Colors.grey.withAlpha((0.5 * 255).toInt()); // グレー 50% 不透明
                    isTopThree = true;
                    break;
                  case '3':
                    backgroundColor = Colors.yellow.withAlpha((0.5 * 255).toInt()); // 黄 50% 不透明
                    isTopThree = true;
                    break;
                  default:
                    backgroundColor = Colors.transparent;
                    isTopThree = false;
                }

                return InkWell(
                  onTap: () => _showPastRaceDetailsPopup(context, record),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      border: Border(
                        left: BorderSide(
                          color: gradeColor, // グレードに応じた色を左ボーダーに適用
                          width: 5.0, // 左ボーダーの幅
                        ),
                      ),
                    ),
                    // 固定幅のコンテナでラップ
                    child: SizedBox(
                      width: 100, // 過去レースの列の固定幅
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isTopThree)
                          // 着順を背景に大きく表示する
                            Center(
                              child: Text(
                                record.rank,
                                style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                            ),
                          // レース名を5文字に制限し、オーバーフロー時に省略記号を表示
                          Text(
                            record.raceName.length > 5
                                ? record.raceName.substring(0, 5)
                                : record.raceName,
                            style: const TextStyle(color: Colors.black, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1, // 1行に制限
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox(
                width: 100, // 固定幅の空のコンテナ
                child: Text(''),
              );
            },
          ),
        ),
    ];
  }


  // 枠番の色分けロジック
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
}