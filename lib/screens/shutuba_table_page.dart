// lib/screens/shutuba_table_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/models/prediction_race_data.dart';
import 'package:hetaumakeiba_v2/main.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:hetaumakeiba_v2/logic/prediction_analyzer.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hetaumakeiba_v2/logic/paste_parser.dart';
import 'package:hetaumakeiba_v2/screens/comprehensive_prediction_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hetaumakeiba_v2/screens/race_statistics_page.dart';
import 'package:hetaumakeiba_v2/utils/grade_utils.dart';
import 'package:hetaumakeiba_v2/screens/horse_stats_page.dart';
import 'package:hetaumakeiba_v2/models/prediction_analysis_model.dart';
import 'package:hetaumakeiba_v2/models/race_statistics_model.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:hetaumakeiba_v2/widgets/themed_tab_bar.dart';

// ソート対象の列を識別するためのenum
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
}


class ShutubaTablePage extends StatefulWidget {
  final String raceId;

  const ShutubaTablePage({super.key, required this.raceId});

  @override
  State<ShutubaTablePage> createState() => _ShutubaTablePageState();
}

// SingleTickerProviderStateMixin を追加
class _ShutubaTablePageState extends State<ShutubaTablePage> with SingleTickerProviderStateMixin {
  PredictionRaceData? _predictionRaceData;
  bool _isLoading = true;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  // 貼り付けられた動的データを一時的に保持するためのキャッシュ
  final Map<String, PasteParseResult> _pastedDataCache = {};
  Map<String, double> _overallScores = {};
  Map<String, double> _expectedValues = {};
  Map<String, String> _legStyles = {};
  Map<String, ConditionFitResult> _conditionFits = {};

  // テーブルのソート状態を管理する変数
  SortableColumn _sortColumn = SortableColumn.horseNumber; // デフォルトは馬番
  bool _isAscending = true;
  // タブコントローラー
  late TabController _tabController;
  // カードの開閉状態を管理する変数
  bool _isCardExpanded = true;


  @override
  void initState() {
    super.initState();
    // タブコントローラーの初期化
    _tabController = TabController(length: 6, vsync: this);
    _loadShutubaData();
  }

  @override
  void dispose() {
    _tabController.dispose(); // 不要になったコントローラーを破棄
    super.dispose();
  }


  Future<void> _loadShutubaData({bool refresh = false}) async {
    if (!refresh) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final data = await _fetchDataWithUserMarks();
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

  Future<void> _calculatePredictionScores(PredictionRaceData raceData) async {
    final prefs = await SharedPreferences.getInstance();
    final customWeights = {
      'legType': prefs.getDouble('legTypeWeight') ?? 20.0,
      'courseFit': prefs.getDouble('courseFitWeight') ?? 20.0,
      'trackCondition': prefs.getDouble('trackConditionWeight') ?? 15.0,
      'humanFactor': prefs.getDouble('humanFactorWeight') ?? 15.0,
      'condition': prefs.getDouble('conditionWeight') ?? 10.0,
      'earlySpeed': prefs.getDouble('earlySpeedWeight') ?? 5.0,
      'finishingKick': prefs.getDouble('finishingKickWeight') ?? 10.0,
      'stamina': prefs.getDouble('staminaWeight') ?? 5.0,
    };

    final Map<String, double> scores = {};
    final Map<String, List<HorseRaceRecord>> allPastRecords = {};
    final Map<String, String> legStyles = {};
    final Map<String, ConditionFitResult> conditionFits = {};
    RaceStatistics? raceStats;
    try {
      // 統計データの取得を試みる
      raceStats = await _dbHelper.getRaceStatistics(widget.raceId);
    } catch (e) {
      // テーブルが存在しない等のエラーが発生しても処理を続行する
      print('レース統計データの取得に失敗しました (テーブル未作成の可能性があります): $e');
      raceStats = null; // エラー時はnullとして扱う
    }
    // まず全馬の過去成績を取得し、総合適性スコアと脚質を計算
    for (var horse in raceData.horses) {
      final pastRecords = await _dbHelper.getHorsePerformanceRecords(horse.horseId);
      allPastRecords[horse.horseId] = pastRecords;
      scores[horse.horseId] = PredictionAnalyzer.calculateOverallAptitudeScore(
        horse,
        raceData,
        pastRecords,
        customWeights: customWeights,
      );
      legStyles[horse.horseId] = PredictionAnalyzer.getRunningStyle(pastRecords);
      conditionFits[horse.horseId] = PredictionAnalyzer.analyzeConditionFit(
        horse: horse,
        raceData: raceData,
        pastRecords: pastRecords,
        raceStats: raceStats,
      );
    }

    // 全馬のスコア合計を算出
    final double totalScore = scores.values.fold(0.0, (sum, score) => sum + score);

    final Map<String, double> expectedValues = {};
    // 各馬の期待値を計算
    for (var horse in raceData.horses) {
      final score = scores[horse.horseId] ?? 0.0;
      final odds = horse.odds ?? 0.0;
      expectedValues[horse.horseId] = PredictionAnalyzer.calculateExpectedValue(
        score,
        odds,
        totalScore,
      );
    }

    if (mounted) {
      setState(() {
        _overallScores = scores;
        _expectedValues = expectedValues;
        _legStyles = legStyles;
        _conditionFits = conditionFits;
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
      return await ScraperService.scrapeFullPredictionData(widget.raceId);
    }

    final raceData = await ScraperService.scrapeFullPredictionData(widget.raceId);

    // 更新前に、キャッシュに保持されているオッズ・人気情報を新しいデータにマージする
    if (_pastedDataCache.isNotEmpty) {
      for (var horse in raceData.horses) {
        if (_pastedDataCache.containsKey(horse.horseName)) {
          final cachedData = _pastedDataCache[horse.horseName]!;
          horse.odds = cachedData.odds;
          horse.popularity = cachedData.popularity;
        }
      }
    }

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
        // DBから読み込んだメモにオッズ・人気情報があれば、表示データに反映
        if (memosMap[horse.horseId]!.odds != null) {
          horse.odds = memosMap[horse.horseId]!.odds;
        }
        if (memosMap[horse.horseId]!.popularity != null) {
          horse.popularity = memosMap[horse.horseId]!.popularity;
        }
      }
      final pastRecords = await _dbHelper.getHorsePerformanceRecords(horse.horseId);
      allPastRecords[horse.horseId] = pastRecords;
    }

    raceData.racePacePrediction = PredictionAnalyzer.predictRacePace(raceData.horses, allPastRecords);

    return raceData;
  }

  Future<void> _launchNetkeibaUrl() async {
    if (_predictionRaceData == null) return;
    final url = Uri.parse(_predictionRaceData!.shutubaTableUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('URLを開けませんでした: ${url.toString()}')),
        );
      }
    }
  }

  Future<void> _showPasteAndUpdateDialog() async {
    final clipboardText = await PasteParser.getTextFromClipboard();
    final textController = TextEditingController(text: clipboardText);

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('出馬表を貼り付け'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('netkeiba.comの出馬表ページでコピーした内容を貼り付けてください。'),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  maxLines: 10,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'ここに貼り付け',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('キャンセル'),
            ),
            ElevatedButton(
              onPressed: () {
                _updateOddsFromPastedText(textController.text);
                Navigator.of(context).pop();
              },
              child: const Text('オッズを更新'),
            ),
          ],
        );
      },
    );
  }

  void _updateOddsFromPastedText(String text) async {
    if (_predictionRaceData == null) return;
    final userId = localUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です。')),
      );
      return;
    }

    final parsedResults = PasteParser.parseDataByHorseName(text, _predictionRaceData!.horses);

    if (parsedResults.isEmpty) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('有効なデータを抽出できませんでした。コピーする範囲を確認してください。')),
        );
      }
      return;
    }

    int updatedCount = 0;
    for (var horse in _predictionRaceData!.horses) {
      if (parsedResults.containsKey(horse.horseName)) {
        final result = parsedResults[horse.horseName]!;

        // 既存のメモを取得（なければ新規作成）
        final existingMemo = horse.userMemo ?? HorseMemo(
          userId: userId,
          raceId: widget.raceId,
          horseId: horse.horseId,
          timestamp: DateTime.now(),
        );

        // 新しいオッズと人気で上書きしてDBに保存
        final newMemo = HorseMemo(
          id: existingMemo.id,
          userId: userId,
          raceId: widget.raceId,
          horseId: horse.horseId,
          predictionMemo: existingMemo.predictionMemo,
          reviewMemo: existingMemo.reviewMemo,
          odds: result.odds,
          popularity: result.popularity,
          timestamp: DateTime.now(),
        );
        await _dbHelper.insertOrUpdateHorseMemo(newMemo);
        updatedCount++;
      }
    }

    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$updatedCount頭の情報を更新しました。')),
      );
      // データを再読み込みしてUIを更新
      _loadShutubaData();
    }
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
    final userId = localUserId; // FirebaseAuthからlocalUserIdに変更
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
              maxLines: null, // 複数行の入力を許可
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
                    // 既存のメモがあればそのIDと総評メモを引き継ぐ
                    id: horse.userMemo?.id,
                    userId: userId,
                    raceId: widget.raceId,
                    horseId: horse.horseId,
                    predictionMemo: memoController.text,
                    reviewMemo: horse.userMemo?.reviewMemo, // 既存の総評メモを保持
                    odds: horse.userMemo?.odds,
                    popularity: horse.userMemo?.popularity,
                    timestamp: DateTime.now(),
                  );
                  await _dbHelper.insertOrUpdateHorseMemo(newMemo);
                  Navigator.of(context).pop();
                  _loadShutubaData(); // データを再読み込みしてUIを更新
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
    final userId = localUserId; // FirebaseAuthからlocalUserIdに変更
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
        return; // ユーザーがファイル選択をキャンセル
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
      _loadShutubaData(); // データを再読み込み

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
      stats = null; // エラーが発生しても処理を続行できるようnullをセット
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('出馬表'),
        actions: [
          // 既存のIconButtonをPopupMenuButtonに集約
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert), // 3点リーダーアイコン
            onSelected: (value) {
              // メニュー項目が選択されたときに、既存の各機能を呼び出します
              switch (value) {
                case 'netkeiba':
                  _launchNetkeibaUrl();
                  break;
                case 'paste':
                  _showPasteAndUpdateDialog();
                  break;
                case 'import':
                  _importMemosFromCsv();
                  break;
                case 'export':
                  if (_predictionRaceData != null) {
                    _exportMemosAsCsv(_predictionRaceData!);
                  }
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              // 1. netkeibaで最新情報を確認
              const PopupMenuItem<String>(
                value: 'netkeiba',
                child: ListTile(
                  leading: Icon(Icons.open_in_browser),
                  title: Text('netkeibaで最新情報を確認'),
                ),
              ),
              // 2. コピーした情報を貼り付け
              const PopupMenuItem<String>(
                value: 'paste',
                child: ListTile(
                  leading: Icon(Icons.paste),
                  title: Text('コピーした情報を貼り付け'),
                ),
              ),
              const PopupMenuDivider(), // 区切り線
              // 3. メモをインポート
              const PopupMenuItem<String>(
                value: 'import',
                child: ListTile(
                  leading: Icon(Icons.file_download),
                  title: Text('メモをインポート'),
                ),
              ),
              // 4. メモをエクスポート (データがある場合のみ有効化)
              PopupMenuItem<String>(
                value: 'export',
                enabled: _predictionRaceData != null, // データがなければ非活性
                child: const ListTile(
                  leading: Icon(Icons.ios_share),
                  title: Text('メモをエクスポート'),
                ),
              ),
            ],
          ),
        ],
      ),
      // === ▼▼▼ 修正箇所 ▼▼▼ ===
      // 全体のレイアウトをColumnに変更
      body: _isLoading
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
          // 折りたたみ可能なレース情報カード
          _buildCollapsibleRaceInfoCard(_predictionRaceData!),
          // タブとテーブルの領域
          Expanded(
            child: IgnorePointer(
              // カードが展開されているときは下のテーブル操作を無効化
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
      ),
      // === ▲▲▲ 修正箇所 ▲▲▲ ===
    );
  }

  /// 折りたたみ可能なレース情報カードを構築する
  Widget _buildCollapsibleRaceInfoCard(PredictionRaceData race) {
    return InkWell(
      onTap: () {
        setState(() {
          _isCardExpanded = !_isCardExpanded;
        });
      },
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
          child: AnimatedSize( // AnimatedSizeでラップしてサイズ変更をアニメーション化
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _isCardExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              firstChild: _buildExpandedCardContent(race),
              secondChild: _buildCollapsedCardContent(race),
              firstCurve: Curves.easeIn,
              secondCurve: Curves.easeOut,
              sizeCurve: Curves.easeInOut,
            ),
          ),
        ),
      ),
    );
  }

  /// 展開時のカード内容
  Widget _buildExpandedCardContent(PredictionRaceData race) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '${race.raceDate} ${race.venue} ${race.raceNumber}R',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const Icon(Icons.expand_less),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          race.raceName,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(race.raceDetails1 ?? ''),
        const Divider(height: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('展開予想', style: TextStyle(fontWeight: FontWeight.bold)),
            if (race.racePacePrediction != null)
              Text(
                  '${race.racePacePrediction!.predictedPace} (${race.racePacePrediction!.advantageousStyle})'),
            const SizedBox(height: 8),
          ],
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
        ListTile(
          dense: true,
          leading: const Icon(Icons.delete_sweep_outlined, color: Colors.red),
          title: const Text('分析キャッシュをクリア', style: TextStyle(color: Colors.red, fontSize: 13)),
          onTap: () async {
            await _dbHelper.clearRaceStatistics();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('分析キャッシュをクリアしました。')),
              );
            }
          },
        ),
      ],
    );
  }

  /// 折りたたみ時のカード内容
  Widget _buildCollapsedCardContent(PredictionRaceData race) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible( // ExpandedをFlexibleに変更し、レイアウトエラーを解消
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

    // 各適性を数値化 (excellent:4, good:3, average:2, poor:1, unknown:0)
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

    // 平均スコアを算出
    final avgScore = totalScore / validRatings;

    // 平均スコアをS, A, B, Cランクに変換
    String rank;
    if (avgScore >= 3.5) {
      rank = 'S';
    } else if (avgScore >= 3.0) rank = 'A';
    else if (avgScore >= 2.5) rank = 'B';
    else if (avgScore >= 2.0) rank = 'C';
    else rank = 'D';

    return Text(rank, style: const TextStyle(fontWeight: FontWeight.bold));
  }


  // ソート用のコールバック関数
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
      minWidth: 800,
      fixedTopRows: 1, // ヘッダー行を固定
      sortColumnIndex: columns.indexWhere((c) => (c.onSort != null)), // 現在ソート中の列を見つける
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
        DataCell(Text(horse.trainer)),
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
        const DataColumn2(label: Text('複合適性'), fixedWidth: 80,),
      ],
      horses: horses,
      cellBuilder: (horse) {
        final score = _overallScores[horse.horseId] ?? 0.0;
        final rank = _getRankFromScore(score);
        final fitResult = _conditionFits[horse.horseId];
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
    return _buildDataTableForTab(
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
      // 項目が選択されたときの処理
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
      // メニュー全体のパディングを削除
      padding: EdgeInsets.zero,
      // セル内に表示するウィジェット
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

                // レース名からグレードを抽出
                String extractedGrade = '';
                // 半角括弧と、J.GおよびGの後に続くローマ数字 (I, II, III) に対応する正規表現
                // 例: (GII), (J.GI), (GIII)
                final gradePattern = RegExp(r'\((J\.?G[I]{1,3}|G[I]{1,3})\)', caseSensitive: false);
                final match = gradePattern.firstMatch(record.raceName);
                if (match != null) {
                  extractedGrade = match.group(1)!; // 例: "GII", "J.GI"
                }

                // グレードに応じた色を取得
                final gradeColor = getGradeColor(extractedGrade); // grade_utils.dart からの関数を使用

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
                      color: backgroundColor, // 既存の着順による背景色
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
