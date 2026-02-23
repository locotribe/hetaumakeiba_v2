// lib/widgets/relative_battle_table.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/relative_evaluation_model.dart';
import 'package:hetaumakeiba_v2/logic/relative_battle_calculator.dart';
import 'package:hetaumakeiba_v2/services/jockey_analysis_service.dart';
import 'package:hetaumakeiba_v2/models/jockey_stats_model.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';

class RelativeBattleTable extends StatefulWidget {
  final List<PredictionHorseDetail> horses;
  final PredictionRaceData? raceData;

  const RelativeBattleTable({
    super.key,
    required this.horses,
    this.raceData,
  });

  @override
  State<RelativeBattleTable> createState() => _RelativeBattleTableState();
}

class _RelativeBattleTableState extends State<RelativeBattleTable> {
  List<RelativeEvaluationResult>? _results;
  Map<String, JockeyStats>? _jockeyStats;
  bool _isLoading = true;

  final Set<RacePace> _visiblePaces = {};
  int _sortColumnIndex = 1;
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _runSimulation();
  }

  Future<void> _runSimulation() async {
    await Future.delayed(Duration.zero);

    // 1. 騎手データの取得
    final jockeyIds = widget.horses.map((h) => h.jockeyId).where((id) => id.isNotEmpty).toList();
    final jockeyService = JockeyAnalysisService();
    final Map<String, JockeyStats> jockeyStats = await jockeyService.analyzeAllJockeys(
        jockeyIds,
        raceData: widget.raceData
    );

    // 2. 馬ごとの過去戦績の取得
    final _horseRepo = HorseRepository();
    final Map<String, List<HorseRaceRecord>> horsePerformanceMap = {};

    for (var horse in widget.horses) {
      final List<HorseRaceRecord> records = await _horseRepo.getHorsePerformanceRecords(horse.horseId);
      horsePerformanceMap[horse.horseId] = records;
    }

    // 3. 計算実行
    final calculator = RelativeBattleCalculator();
    final results = calculator.runSimulation(
      widget.horses,
      iterations: 100,
      jockeyStats: jockeyStats,
      horsePerformanceMap: horsePerformanceMap,
    );

    if (mounted) {
      setState(() {
        _results = results;
        _jockeyStats = jockeyStats;
        _results!.sort((a, b) => b.winRate.compareTo(a.winRate));
        _isLoading = false;
      });
    }
  }

// ★追加: 場所を確実に特定するメソッド
  String _resolveVenue(PredictionRaceData? data) {
    if (data == null) return '';

    // 1. データに場所が入っていればそれを使う
    if (data.venue.isNotEmpty) return data.venue;

    // 2. レースIDから抽出 (例: 202505... -> 05 -> 東京)
    if (data.raceId.length >= 12) {
      final code = data.raceId.substring(4, 6);
      // racecourseDict は logic/parse.dart に定義されています。
      // 未インポートの場合は import 'package:hetaumakeiba_v2/logic/parse.dart'; を追加してください
      if (racecourseDict.containsKey(code)) {
        return racecourseDict[code]!;
      }
    }

    // 3. 詳細テキストから抽出 (例: "1回 東京 4日目")
    final details = data.raceDetails1 ?? '';
    if (details.isNotEmpty) {
      for (final val in racecourseDict.values) {
        if (details.contains(val)) {
          return val;
        }
      }
    }

    return '';
  }

  // ★追加: 距離抽出メソッド
  String _extractDistance(String raceInfo) {
    final distanceMatch = RegExp(r'(芝|ダ|障)[^0-9]*?(\d+)m').firstMatch(raceInfo);
    if (distanceMatch != null) {
      return '${distanceMatch.group(1)}${distanceMatch.group(2)}m';
    }
    return '';
  }

  void _sort<T>(Comparable<T> Function(RelativeEvaluationResult d) getField, int columnIndex, bool ascending) {
    if (_results == null) return;

    setState(() {
      _sortColumnIndex = columnIndex;
      _sortAscending = ascending;
      _results!.sort((a, b) {
        final aValue = getField(a);
        final bValue = getField(b);
        return ascending ? Comparable.compare(aValue, bValue) : Comparable.compare(bValue, aValue);
      });
    });
  }

  int _getRankInList<T extends Comparable>(T value, T Function(RelativeEvaluationResult) getField, {bool descending = true}) {
    if (_results == null || _results!.isEmpty) return 999;
    final values = _results!.map((e) => getField(e)).toList();
    values.removeWhere((v) => v == null);
    if (descending) {
      values.sort((a, b) => b.compareTo(a));
    } else {
      values.sort((a, b) => a.compareTo(b));
    }
    return values.indexOf(value) + 1;
  }

  Color? _getRankColor(int rank) {
    switch (rank) {
      case 1: return Colors.red.withOpacity(0.3);
      case 2: return Colors.deepOrange.withOpacity(0.3);
      case 3: return Colors.orange.withOpacity(0.3);
      case 4: return Colors.lime.withOpacity(0.4);
      case 5: return Colors.yellow.withOpacity(0.3);
      default: return null;
    }
  }

// ダイアログ表示メソッド
  void _showJockeyDetails(BuildContext context, RelativeEvaluationResult result) {
    final details = result.jockeyDetails;
    if (details == null) return;

    // コース情報の生成
    String courseInfo = "全場成績";
    String venueName = "";
    String distanceStr = "";

    if (widget.raceData != null) {
      // 以前定義した _resolveVenue メソッドを使用
      venueName = _resolveVenue(widget.raceData);
      // 以前定義した _extractDistance メソッドを使用
      distanceStr = _extractDistance(widget.raceData!.raceDetails1 ?? "");

      if (venueName.isNotEmpty && distanceStr.isNotEmpty) {
        courseInfo = "$venueName$distanceStr 実績";
      } else if (venueName.isNotEmpty) {
        courseInfo = "$venueName 実績";
      } else if (distanceStr.isNotEmpty) {
        courseInfo = "$distanceStr 実績";
      }
    }

    // 騎手データの取得
    JockeyStats? fullStats;
    if (_jockeyStats != null) {
      try {
        final horse = widget.horses.firstWhere((h) => h.horseName == result.horseName);
        fullStats = _jockeyStats![horse.jockeyId];
      } catch (_) {}
    }

    List<Widget> content = [];

    // --- 【上段】本コース実績セクション ---
    // ここで使用するデータ(cs)は JockeyStatsModel 由来のため、
    // winRate 等は既にパーセント値(例: 18.6)になっています。 => *100 不要
    if (venueName.isNotEmpty && distanceStr.isNotEmpty) {
      content.add(Text("【本コース ($venueName$distanceStr)】",
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)));

      if (fullStats != null && fullStats.courseStats != null && fullStats.courseStats!.raceCount > 0) {
        final cs = fullStats.courseStats!;

        // 着度数の正しい計算 (累積値から算出)
        final win = cs.winCount;
        final second = cs.placeCount - cs.winCount;
        final third = cs.showCount - cs.placeCount;
        final unplaced = cs.raceCount - cs.showCount;
        final record = "$win-$second-$third-$unplaced";

        content.add(_detailRow("着度数", record));
        // ★修正: cs.winRate は既にパーセント値なのでそのまま表示
        content.add(_detailRow("勝率", "${cs.winRate.toStringAsFixed(1)}%"));
        content.add(_detailRow("連対率", "${cs.placeRate.toStringAsFixed(1)}%"));
        content.add(_detailRow("複勝率", "${cs.showRate.toStringAsFixed(1)}%"));
      } else {
        content.add(_detailRow("着度数", "0-0-0-0"));
        content.add(_detailRow("勝率", "0.0%"));
        content.add(_detailRow("連対率", "0.0%"));
        content.add(_detailRow("複勝率", "0.0%"));
      }
      content.add(const Divider());
    }

    // --- 【下段】評価採用データセクション ---
    // ここで使用するデータ(details)は RelativeBattleCalculator 由来のため、
    // winRate 等は比率(例: 0.186)になっています。 => *100 必要
    content.add(const Text("【評価採用データ】", style: TextStyle(fontWeight: FontWeight.bold)));
    content.add(_detailRow("採用元", details['source']));
    content.add(_detailRow("騎乗回数", "${details['raceCount']}回"));

    // ★修正: details['winRate'] は比率なので、100倍してパーセント表示にする
    content.add(_detailRow("勝率", "${(details['winRate'] * 100).toStringAsFixed(1)}%"));
    content.add(_detailRow("ボーナス", details['bonus'].toString()));

    _showScoreDetailsDialog(
        context,
        horseName: '${details['jockeyName']} 騎手',
        subTitle: courseInfo,
        score: details['score'] as int,
        content: content
    );
  }

// lib/widgets/relative_battle_table.dart

  void _showCompatibilityDetails(BuildContext context, RelativeEvaluationResult result) {
    final details = result.compatibilityDetails;
    if (details == null) return;

    final bool isFirstRide = details['isFirstRide'] as bool;
    final int score = details['score'] as int;
    final String jockeyName = result.jockeyDetails?['jockeyName'] ?? '騎手情報なし';

    _showScoreDetailsDialog(
        context,
        horseName: result.horseName,
        subTitle: '$jockeyName 騎手との相性',
        score: score,
        content: isFirstRide
            ? [const Padding(padding: EdgeInsets.all(16.0), child: Center(child: Text("初コンビ")))]
            : [
          _detailRow("コンビ結成", "継続"),
          _detailRow("騎乗回数", "${details['rideCount']}回"),

          // 勝率は小数のため *100 が必要（そのまま）
          _detailRow("コンビ勝率", "${(details['winRate'] * 100).toStringAsFixed(1)}%"),

          // ★修正箇所: 連対率は既にパーセント値のため *100 を削除
          _detailRow("連対率", "${details['placeRate'].toStringAsFixed(1)}%"),
        ]
    );
  }

  void _showGateDetails(BuildContext context, RelativeEvaluationResult result) {
    final details = result.gateDetails;
    if (details == null) return;

    final int score = details['score'] as int;
    final bool isDetermined = details['isDetermined'] as bool;
    final int horseNumber = details['gateNumber'] ?? 0;
    final String zone = details['zone'] ?? '-';
    final Map<String, dynamic> tendency = details['tendency'] ?? {};

    String zoneLabel = '-';
    if (zone == 'inner') zoneLabel = '内枠 (Inner)';
    if (zone == 'middle') zoneLabel = '中枠 (Middle)';
    if (zone == 'outer') zoneLabel = '外枠 (Outer)';

    _showScoreDetailsDialog(
        context,
        horseName: result.horseName,
        subTitle: isDetermined ? '馬番 $horseNumber番 ($zoneLabel)' : '馬番未定',
        score: score,
        content: [
          if (!isDetermined)
            const Padding(padding: EdgeInsets.all(16.0), child: Center(child: Text("枠順確定前のため集計対象外"))),
          if (isDetermined) ...[
            _detailRow("現在の馬番", "$horseNumber番"),
            const Divider(),
            const Text("過去の傾向 (勝率)", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _tendencyRow("内枠 (〜33%)", tendency['inner']),
            _tendencyRow("中枠 (〜66%)", tendency['middle']),
            _tendencyRow("外枠 (67%〜)", tendency['outer']),
            const SizedBox(height: 8),
            Text(
              "※今回の$zoneLabel適性がスコアに反映されています",
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ]
        ]
    );
  }

  Widget _tendencyRow(String label, Map<String, dynamic>? data) {
    if (data == null) return _detailRow(label, "-");
    double winRate = data['winRate'] ?? 0.0;
    double count = data['count'] ?? 0.0;
    return _detailRow(label, "${(winRate * 100).toStringAsFixed(1)}% (${count.toInt()}走)");
  }

  void _showScoreDetailsDialog(BuildContext context, {
    required String horseName,
    required String subTitle,
    required int score,
    required List<Widget> content
  }) {
    String rankStr = 'C';
    Color rankColor = Colors.grey;
    if (score >= 45) { rankStr = 'SS'; rankColor = Colors.red.shade900; }
    else if (score >= 35) { rankStr = 'S'; rankColor = Colors.red; }
    else if (score >= 25) { rankStr = 'A'; rankColor = Colors.orange; }
    else if (score >= 15) { rankStr = 'B'; rankColor = Colors.amber; }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(horseName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black), maxLines: 1),
            const SizedBox(height: 4),
            Text(subTitle, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: Colors.black87)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text("評価ランク: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: rankColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: Text("$rankStr ($score点)", style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 18)),
                ),
              ],
            ),
            const Divider(height: 24),
            ...content,
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("閉じる")),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black87)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_results == null || _results!.isEmpty) return const Center(child: Text("データがありません"));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Wrap(
            spacing: 8.0,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text("展開シミュ: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              FilterChip(
                label: const Text("S"),
                selected: _visiblePaces.contains(RacePace.slow),
                onSelected: (selected) => setState(() => selected ? _visiblePaces.add(RacePace.slow) : _visiblePaces.remove(RacePace.slow)),
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(fontSize: 11),
              ),
              FilterChip(
                label: const Text("M"),
                selected: _visiblePaces.contains(RacePace.middle),
                onSelected: (selected) => setState(() => selected ? _visiblePaces.add(RacePace.middle) : _visiblePaces.remove(RacePace.middle)),
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(fontSize: 11),
              ),
              FilterChip(
                label: const Text("H"),
                selected: _visiblePaces.contains(RacePace.high),
                onSelected: (selected) => setState(() => selected ? _visiblePaces.add(RacePace.high) : _visiblePaces.remove(RacePace.high)),
                visualDensity: VisualDensity.compact,
                labelStyle: const TextStyle(fontSize: 11),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortAscending,
                columnSpacing: 12.0,
                headingRowColor: MaterialStateProperty.all(Colors.grey.shade200),
                columns: _buildColumns(),
                rows: _results!.map((result) => _buildRow(result)).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<DataColumn> _buildColumns() {
    List<DataColumn> columns = [
      DataColumn(
        label: const Text('馬名', style: TextStyle(fontWeight: FontWeight.bold)),
        onSort: (idx, asc) => _sort((r) => r.horseName, idx, asc),
      ),
      DataColumn(
        label: const Text('総合勝率', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.winRate, idx, asc),
      ),
      DataColumn(
        label: const Text('人気', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.popularity ?? 999, idx, asc),
      ),
      DataColumn(
        label: const Text('オッズ', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.odds, idx, asc),
      ),
    ];

    if (_visiblePaces.contains(RacePace.slow)) {
      columns.add(DataColumn(
        label: const Text('S勝率', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.scenarioWinRates[RacePace.slow] ?? 0.0, idx, asc),
      ));
    }
    if (_visiblePaces.contains(RacePace.middle)) {
      columns.add(DataColumn(
        label: const Text('M勝率', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.scenarioWinRates[RacePace.middle] ?? 0.0, idx, asc),
      ));
    }
    if (_visiblePaces.contains(RacePace.high)) {
      columns.add(DataColumn(
        label: const Text('H勝率', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.scenarioWinRates[RacePace.high] ?? 0.0, idx, asc),
      ));
    }

    columns.addAll([
      DataColumn(
        label: const Text('逆転', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.reversalScore, idx, asc),
      ),
      DataColumn(
        label: const Text('基礎', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.factorScores['base'] ?? 0, idx, asc),
      ),
      DataColumn(
        label: const Text('騎手', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.factorScores['jockey'] ?? 0, idx, asc),
      ),
      DataColumn(
        label: const Text('相性', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.factorScores['compatibility'] ?? 0, idx, asc),
      ),
      DataColumn(
        label: const Text('枠順', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.factorScores['gate'] ?? 0, idx, asc),
      ),
      DataColumn(
        label: const Text('妙味', style: TextStyle(fontWeight: FontWeight.bold)),
        numeric: true,
        onSort: (idx, asc) => _sort((r) => r.factorScores['value'] ?? 0, idx, asc),
      ),
      const DataColumn(
        label: Text('評価短評', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    ]);

    return columns;
  }

  DataRow _buildRow(RelativeEvaluationResult result) {
    final winRateRank = _getRankInList(result.winRate, (r) => r.winRate, descending: true);
    final popRank = _getRankInList(result.popularity ?? 999, (r) => r.popularity ?? 999, descending: false);
    final revRank = _getRankInList(result.reversalScore, (r) => r.reversalScore, descending: true);
    final baseRank = _getRankInList(result.factorScores['base'] ?? 0, (r) => r.factorScores['base'] ?? 0, descending: true);
    final valueRank = _getRankInList(result.factorScores['value'] ?? 0, (r) => r.factorScores['value'] ?? 0, descending: true);
    final jockeyRank = _getRankInList(result.factorScores['jockey'] ?? 0, (r) => r.factorScores['jockey'] ?? 0, descending: true);
    final compRank = _getRankInList(result.factorScores['compatibility'] ?? 0, (r) => r.factorScores['compatibility'] ?? 0, descending: true);

    // ★修正: 枠順ランク (isDeterminedがfalseなら色を付けない)
    final gateRank = _getRankInList(result.factorScores['gate'] ?? 0, (r) => r.factorScores['gate'] ?? 0, descending: true);
    final bool isGateDetermined = result.gateDetails?['isDetermined'] ?? false;
    final Color? gateColor = isGateDetermined ? _getRankColor(gateRank) : null;

    final bool isRedOdds = result.odds < 10.0 && result.odds > 0;
    final TextStyle oddsStyle = isRedOdds
        ? const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)
        : const TextStyle(fontWeight: FontWeight.normal, color: Colors.black);

    List<DataCell> cells = [
      DataCell(Text(result.horseName)),
      DataCell(
        Container(
          color: _getRankColor(winRateRank),
          alignment: Alignment.centerRight,
          child: Text(
            '${(result.winRate * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontWeight: winRateRank <= 3 ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ),
      DataCell(
        Container(
          color: _getRankColor(popRank),
          alignment: Alignment.center,
          child: Text(
            result.popularity != null ? '${result.popularity}人' : '-',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
      DataCell(
        Container(
          alignment: Alignment.centerRight,
          child: Text(
            result.odds > 0 ? result.odds.toStringAsFixed(1) : '-',
            style: oddsStyle,
          ),
        ),
      ),
    ];

    if (_visiblePaces.contains(RacePace.slow)) {
      double rate = result.scenarioWinRates[RacePace.slow] ?? 0.0;
      final sRank = _getRankInList(rate, (r) => r.scenarioWinRates[RacePace.slow] ?? 0.0, descending: true);
      cells.add(DataCell(
        Container(
          color: _getRankColor(sRank),
          alignment: Alignment.centerRight,
          child: Text(
            '${(rate * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontWeight: sRank <= 3 ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ));
    }
    if (_visiblePaces.contains(RacePace.middle)) {
      double rate = result.scenarioWinRates[RacePace.middle] ?? 0.0;
      final mRank = _getRankInList(rate, (r) => r.scenarioWinRates[RacePace.middle] ?? 0.0, descending: true);
      cells.add(DataCell(
        Container(
          color: _getRankColor(mRank),
          alignment: Alignment.centerRight,
          child: Text(
            '${(rate * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontWeight: mRank <= 3 ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ));
    }
    if (_visiblePaces.contains(RacePace.high)) {
      double rate = result.scenarioWinRates[RacePace.high] ?? 0.0;
      final hRank = _getRankInList(rate, (r) => r.scenarioWinRates[RacePace.high] ?? 0.0, descending: true);
      cells.add(DataCell(
        Container(
          color: _getRankColor(hRank),
          alignment: Alignment.centerRight,
          child: Text(
            '${(rate * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontWeight: hRank <= 3 ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ));
    }

    cells.addAll([
      DataCell(
        Container(
          color: _getRankColor(revRank),
          alignment: Alignment.center,
          child: Text(result.reversalScore.toStringAsFixed(1)),
        ),
      ),
      DataCell(
        Container(
          color: _getRankColor(baseRank),
          alignment: Alignment.center,
          child: Text((result.factorScores['base'] ?? 0).toStringAsFixed(0)),
        ),
      ),
      DataCell(
        InkWell(
          onTap: () => _showJockeyDetails(context, result),
          child: Container(
            color: _getRankColor(jockeyRank),
            alignment: Alignment.center,
            child: Text(
              (result.factorScores['jockey'] ?? 0).toStringAsFixed(0),
              style: const TextStyle(decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dotted),
            ),
          ),
        ),
      ),
      DataCell(
        InkWell(
          onTap: () => _showCompatibilityDetails(context, result),
          child: Container(
            color: _getRankColor(compRank),
            alignment: Alignment.center,
            child: Text(
              (result.factorScores['compatibility'] ?? 0).toStringAsFixed(0),
              style: const TextStyle(decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dotted),
            ),
          ),
        ),
      ),
      // ★修正: 枠順スコア (確定前は色なし)
      DataCell(
        InkWell(
          onTap: () => _showGateDetails(context, result),
          child: Container(
            color: gateColor, // 色判定結果を適用
            alignment: Alignment.center,
            child: Text(
              (result.factorScores['gate'] ?? 0).toStringAsFixed(0),
              style: const TextStyle(decoration: TextDecoration.underline, decorationStyle: TextDecorationStyle.dotted),
            ),
          ),
        ),
      ),
      DataCell(
        Container(
          color: _getRankColor(valueRank),
          alignment: Alignment.center,
          child: Text((result.factorScores['value'] ?? 0).toStringAsFixed(0)),
        ),
      ),
      DataCell(
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 200),
          child: Text(
            result.evaluationComment,
            style: const TextStyle(fontSize: 12),
            softWrap: true,
          ),
        ),
      ),
    ]);

    return DataRow(cells: cells);
  }
}