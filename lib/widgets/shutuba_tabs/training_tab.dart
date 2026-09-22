// lib/widgets/shutuba_tabs/training_tab.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_preparation_status_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_preparation_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/training_repository.dart';
// [追加] 調教タブ改修Step5: netkeiba 調教・過去成績・表示用データ (v.2026.9.23+26092302)
import 'package:hetaumakeiba_v2/db/repositories/netkeiba_training_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/logic/training_merge.dart';
import 'package:hetaumakeiba_v2/logic/training_display.dart';
import 'package:hetaumakeiba_v2/services/netkeiba_session_service.dart';
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';
import 'package:hetaumakeiba_v2/services/training_data_service.dart';
// [追加] 調教タブ改修Step3: netkeiba の最終追切・厩舎コメント (v.2026.9.22+26092212)
import 'package:hetaumakeiba_v2/services/netkeiba_training_service.dart';
import 'package:hetaumakeiba_v2/services/scraping_manager.dart';
// [追加] 調教タブ改修Step1: レース日での絞り込みとラップ計算の共通関数 (v.2026.9.22+26092210)
import 'package:hetaumakeiba_v2/utils/training_date_utils.dart';

// [修正] 調教タブ改修Step5: netkeiba 調教（評価・短評・併せ馬・厩舎コメント）を加えて表示を作り直し。
// 「最終追い切り」（1頭1枚）と「中間追い切り含む」（レースごとのまとまり）を切り替える (v.2026.9.23+26092302)
class TrainingTabWidget extends StatefulWidget {
  final String raceId;
  final String raceDate;
  final List<PredictionHorseDetail> horses;

  const TrainingTabWidget({
    Key? key,
    required this.raceId,
    required this.raceDate,
    required this.horses,
  }) : super(key: key);

  @override
  State<TrainingTabWidget> createState() => _TrainingTabWidgetState();
}

class _TrainingTabWidgetState extends State<TrainingTabWidget> {
  final TrainingRepository _repository = TrainingRepository();
  final TrainingDataService _service = TrainingDataService();
  // [追加] Phase 4-C: 調教データの取得状態(未取得/取得中/取得済み0件等)の表示に使う (v.2026.9.5+26090503)
  final RacePreparationRepository _preparationRepository = RacePreparationRepository();
  // [追加] 調教タブ改修Step5: netkeiba 調教と過去成績（レースごとのまとまり用） (v.2026.9.23+26092302)
  final NetkeibaTrainingRepository _netkeibaRepository = NetkeibaTrainingRepository();
  final HorseRepository _horseRepository = HorseRepository();

  Map<String, List<MergedTrainingEntry>> _entries = {};
  Map<String, NetkeibaTrainingReview> _raceReviews = {};
  Map<String, Map<String, NetkeibaTrainingReview>> _horseReviews = {};
  Map<String, List<HorseRaceRecord>> _pastRaces = {};
  final Set<String> _loadingHorseIds = {};
  bool _showAll = false;
  bool _isLoggedIn = false;
  RacePreparationStatus? _preparationStatus;
  bool _isLoading = true;

  static const Color _tokeiColor1 = Color(0xFFFC855C);
  static const Color _tokeiColor2 = Color(0xFFFDF2C1);
  static const Color _rankBColor = Color(0xFF007EFF);
  static const double _gateBarWidth = 26;

  @override
  void initState() {
    super.initState();
    _loadTrainingData().then((_) => _autoFetchRaceTrainingIfNeeded());
  }

  String get _raceYmd => toYyyymmdd(widget.raceDate) ?? '';

  Future<void> _loadTrainingData({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() { _isLoading = true; });
    }
    final raceYmd = _raceYmd;
    final entries = <String, List<MergedTrainingEntry>>{};
    final horseReviews = <String, Map<String, NetkeibaTrainingReview>>{};
    final pastRaces = <String, List<HorseRaceRecord>>{};
    for (final horse in widget.horses) {
      // [修正] 調教タブ改修Step1: レース当日以降の調教を除外する (v.2026.9.22+26092210)
      final pakara = filterTrainingBeforeRace(
          await _repository.getTrainingTimesForHorse(horse.horseId),
          widget.raceDate);
      var netkeiba =
          await _netkeibaRepository.getSessionsForHorse(horse.horseId);
      if (raceYmd.isNotEmpty) {
        netkeiba = netkeiba
            .where((s) => s.trainingDate.compareTo(raceYmd) < 0)
            .toList();
      }
      entries[horse.horseId] = mergeTrainingSources(pakara, netkeiba);
      final reviews =
          await _netkeibaRepository.getReviewsForHorse(horse.horseId);
      horseReviews[horse.horseId] = {for (final r in reviews) r.raceId: r};
      pastRaces[horse.horseId] =
          await _horseRepository.getHorsePerformanceRecords(horse.horseId);
    }
    final raceReviews =
        await _netkeibaRepository.getReviewsForRace(widget.raceId);
    // [追加] Phase 4-C: 調教データの取得状態を読み、見出し文言に反映する (v.2026.9.5+26090503)
    final preparationStatus = await _preparationRepository.getStep(
        widget.raceId, PreparationStep.training);
    final isLoggedIn = await NetkeibaSessionService.isLoggedIn();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _raceReviews = raceReviews;
      _horseReviews = horseReviews;
      _pastRaces = pastRaces;
      _preparationStatus = preparationStatus;
      _isLoggedIn = isLoggedIn;
      _isLoading = false;
    });
  }

  // [追加] Phase 4-C: 準備状態に応じた調教データの見出し文言を返す (v.2026.9.5+26090503)
  String _trainingStatusLabel() {
    final status = _preparationStatus;
    if (status == null) return '※調教データ未取得';

    switch (status.state) {
      case PreparationState.pending:
        return '※調教データ未取得';
      case PreparationState.running:
        return '※調教データ取得中...';
      case PreparationState.done:
        return status.itemCount == 0
            ? '※このレースの調教データは提供されていません'
            : '※直近の調教タイム・ラップ';
      case PreparationState.failed:
        return '※調教データの取得に失敗しました';
      case PreparationState.skipped:
        return '※直近の調教タイム・ラップ';
    }
  }

  // どんな日付形式でもAPIが求める 'YYYYMMDD' (8桁) に変換する
  String _formatDateForApi(String rawDate) {
    final RegExp regExp = RegExp(r'(\d{4})[年/\-]\s*(\d{1,2})[月/\-]\s*(\d{1,2})');
    final match = regExp.firstMatch(rawDate);
    if (match != null) {
      final y = match.group(1)!;
      final m = match.group(2)!.padLeft(2, '0');
      final d = match.group(3)!.padLeft(2, '0');
      return '$y$m$d';
    }
    return rawDate.replaceAll(RegExp(r'[^0-9]'), '');
  }

  void _fetchFromApi() {
    final formattedDate = _formatDateForApi(widget.raceDate);
    final horseIds = widget.horses.map((h) => h.horseId).toList();

    debugPrint('DEBUG: [Training API] Request Date: $formattedDate, RaceID: ${widget.raceId}');

    // [修正] Phase 2: keyによる重複排除を追加 (v.2026.9.4+26090405)
    ScrapingManager().addRequest('調教データ取得', () async {
      await _service.fetchAndSaveTrainingData(
        raceId: widget.raceId,
        raceDate: formattedDate,
        horseIds: horseIds,
      );
      // [追加] 調教タブ改修Step3: netkeiba の最終追切・厩舎コメントも取得（ログイン中のみ） (v.2026.9.22+26092212)
      try {
        await NetkeibaTrainingService().fetchAndSaveRaceTraining(
          raceId: widget.raceId,
          horseIds: horseIds,
        );
      } catch (e) {
        debugPrint('TrainingTab: netkeiba 調教の取得に失敗: $e');
      }
      // [追加] 調教タブ改修Step4: 全頭の競走馬調教ページを取り直す（ログイン中のみ） (v.2026.9.23+26092301)
      try {
        await NetkeibaTrainingService().fetchAndSaveHorseTrainings(
          horseIds: horseIds,
          raceId: widget.raceId,
          force: true,
        );
      } catch (e) {
        debugPrint('TrainingTab: 競走馬調教ページの取得に失敗: $e');
      }
      if (mounted) {
        await _loadTrainingData();
      }
    }, key: 'training:${widget.raceId}');
  }

  // [追加] 調教タブ改修Step4: 馬のカードを開いたとき、競走馬調教ページが未取得・古ければ取得する (v.2026.9.23+26092301)
  // [修正] 調教タブ改修Step5: 取得中の表示と、取得後の再読み込み（スピナーなし）を追加 (v.2026.9.23+26092302)
  void _fetchHorseTrainingIfNeeded(String horseId) {
    ScrapingManager().addRequest('競走馬の調教取得', () async {
      final service = NetkeibaTrainingService();
      if (!await service.needsHorseTrainingFetch(horseId,
          raceId: widget.raceId)) {
        return;
      }
      if (mounted) setState(() => _loadingHorseIds.add(horseId));
      final result = await service.fetchAndSaveHorseTraining(horseId);
      if (!mounted) return;
      setState(() => _loadingHorseIds.remove(horseId));
      if (result != null) await _loadTrainingData(showSpinner: false);
    }, key: 'training_nk_horse:$horseId');
  }

  // [追加] 調教タブ改修Step5: レース日まで0〜7日で、このレースの最終追切の評価が未取得なら自動取得する。
  // 追切の公開（水・木曜）より前にレース準備が済んだレースのため。同じレースで6時間に1回まで (v.2026.9.23+26092302)
  Future<void> _autoFetchRaceTrainingIfNeeded() async {
    if (!mounted || !_isLoggedIn) return;
    final raceDay = DateTime.tryParse(_raceYmd);
    if (raceDay == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = raceDay.difference(today).inDays;
    if (days < 0 || days > 7) return;
    final hasOikiri =
        _raceReviews.values.any((r) => r.rank != null || r.critic != null);
    if (hasOikiri) return;
    final prefs = await SharedPreferences.getInstance();
    final prefKey = 'nk_oikiri_auto_${widget.raceId}';
    final last = DateTime.tryParse(prefs.getString(prefKey) ?? '');
    if (last != null && now.difference(last) < const Duration(hours: 6)) {
      return;
    }
    await prefs.setString(prefKey, now.toIso8601String());
    final horseIds = widget.horses.map((h) => h.horseId).toList();
    ScrapingManager().addRequest('最終追切の取得', () async {
      await NetkeibaTrainingService().fetchAndSaveRaceTraining(
        raceId: widget.raceId,
        horseIds: horseIds,
      );
      if (mounted) await _loadTrainingData(showSpinner: false);
    }, key: 'training_nk_race:${widget.raceId}');
  }

  // [削除] 調教タブ改修Step5: 旧表示の _formatDateJP / _formatTimeJP / _buildTimeAndLapRow は
  // 表示用データ（logic/training_display.dart）と以下の新しい部品に置き換えた (v.2026.9.23+26092302)

  Color? _cellColor(int color) {
    if (color == 1) return _tokeiColor1;
    if (color == 2) return _tokeiColor2;
    return null;
  }

  Color _rankColor(String rank) {
    switch (rank) {
      case 'A':
        return Colors.red;
      case 'B':
        return _rankBColor;
      case 'C':
        return Colors.black87;
      default:
        return Colors.grey;
    }
  }

  /// 厩舎コメントの評価アイコン番号 → 印（判明分のみ）
  String? _stableMarkLabel(String? code) {
    if (code == '02') return '○';
    return null;
  }

  /// 左端の枠色の帯と馬番（枠順確定前・馬番0は灰色）
  Widget _buildGateBar(PredictionHorseDetail horse) {
    final hasGate = horse.gateNumber > 0 && horse.horseNumber > 0;
    final background =
        hasGate ? horse.gateNumber.gateBackgroundColor : Colors.grey.shade400;
    final foreground =
        hasGate ? horse.gateNumber.gateTextColor : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: background,
        border: Border(right: BorderSide(color: Colors.grey.shade300)),
      ),
      alignment: Alignment.center,
      child: Text(
        horse.horseNumber > 0 ? '${horse.horseNumber}' : '-',
        style: TextStyle(
            color: foreground, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildHorseName(PredictionHorseDetail horse) {
    return Text(
      horse.horseName,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        decoration: horse.isScratched ? TextDecoration.lineThrough : null,
        color: horse.isScratched ? Colors.grey : null,
      ),
    );
  }

  Widget _buildShortReview(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(text,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
    );
  }

  Widget _buildStableComment(NetkeibaTrainingReview review) {
    final mark = _stableMarkLabel(review.stableMark);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text.rich(
        TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          children: [
            TextSpan(
              text: '厩舎 ',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.green.shade800),
            ),
            if (mark != null)
              TextSpan(
                  text: '$mark ',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: review.stableComment ?? ''),
            if (review.stableSpeaker != null)
              TextSpan(
                text: '〈${review.stableSpeaker}〉',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
          ],
        ),
      ),
    );
  }

  /// 調教1本（見出し行＋時計5マス＋脚色(位置)＋併せ馬）
  Widget _buildSessionBlock(TrainingRowView row) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.grey.shade200,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(row.headerLabel,
                    style:
                        const TextStyle(fontSize: 12, color: Colors.black87)),
              ),
              if (row.isBestTime)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.orange.shade700),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text('一番時計',
                      style: TextStyle(
                          fontSize: 10, color: Colors.orange.shade800)),
                ),
              if (row.critic != null)
                Text(row.critic!,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.bold)),
              if (row.rank != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    row.rank!,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _rankColor(row.rank!),
                    ),
                  ),
                ),
            ],
          ),
        ),
        _buildTimeGrid(row),
        for (final partner in row.partners)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(partner.fullText,
                style: TextStyle(fontSize: 12, color: Colors.blue.shade800)),
          ),
      ],
    );
  }

  /// 時計5マス（累計＋ラップ、netkeiba の色）と脚色(位置)。最後の1Fのラップは加速=赤・減速=青
  Widget _buildTimeGrid(TrainingRowView row) {
    final borderColor = Colors.grey.shade300;
    final lastLapIndex = row.cells.lastIndexWhere((c) => c.lap != null);
    final trend = row.lastLapTrend;
    final trendColor = trend < 0
        ? Colors.red
        : (trend > 0 ? Colors.blue : Colors.grey.shade700);
    return Container(
      decoration: BoxDecoration(border: Border.all(color: borderColor)),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < row.cells.length; i++)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _cellColor(row.cells[i].color),
                    border: Border(right: BorderSide(color: borderColor)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        row.cells[i].time?.toStringAsFixed(1) ?? '-',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        row.cells[i].lap != null
                            ? '(${row.cells[i].lap!.toStringAsFixed(1)})'
                            : '',
                        style: TextStyle(
                          fontSize: 10,
                          color: i == lastLapIndex
                              ? trendColor
                              : Colors.grey.shade700,
                          fontWeight: i == lastLapIndex
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(
              width: 56,
              child: Center(
                child: Text(row.loadLabel ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 最終追い切り（1頭1枚）
  Widget _buildFinalCard(PredictionHorseDetail horse) {
    final entries = _entries[horse.horseId] ?? const <MergedTrainingEntry>[];
    final finalEntry = pickFinalEntry(entries, widget.raceId);
    final review = _raceReviews[horse.horseId];
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(_gateBarWidth + 8, 8, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHorseName(horse),
                if (review?.shortReview != null)
                  _buildShortReview(review!.shortReview!),
                const SizedBox(height: 6),
                if (finalEntry == null)
                  Text('調教データなし',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600))
                else
                  _buildSessionBlock(buildTrainingRowView(finalEntry)),
                if (review?.stableComment != null)
                  _buildStableComment(review!),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _gateBarWidth,
            child: _buildGateBar(horse),
          ),
        ],
      ),
    );
  }

  /// 中間追い切り含む（馬ごとの折りたたみ、レースごとのまとまり）
  Widget _buildAllCard(PredictionHorseDetail horse) {
    final entries = _entries[horse.horseId] ?? const <MergedTrainingEntry>[];
    final finalEntry = pickFinalEntry(entries, widget.raceId);
    final finalRow =
        finalEntry == null ? null : buildTrainingRowView(finalEntry);
    final review = _raceReviews[horse.horseId];
    final groups = groupTrainingByRace(
      entries: entries,
      pastRaces: _pastRaces[horse.horseId] ?? const <HorseRaceRecord>[],
      currentRaceId: widget.raceId,
      currentRaceYmd: _raceYmd,
    );
    final isFetching = _loadingHorseIds.contains(horse.horseId);
    final summary = finalRow == null
        ? '調教データなし'
        : [finalRow.dateLabel, finalRow.courseLabel, finalRow.critic, finalRow.rank]
            .whereType<String>()
            .join(' ');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: _gateBarWidth),
            child: ExpansionTile(
              key: PageStorageKey<String>('training_all_${horse.horseId}'),
              // [追加] 調教タブ改修Step4: 開いたときに競走馬調教ページを取得（必要なときだけ） (v.2026.9.23+26092301)
              onExpansionChanged: (expanded) {
                if (expanded) _fetchHorseTrainingIfNeeded(horse.horseId);
              },
              title: _buildHorseName(horse),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (review?.shortReview != null)
                    _buildShortReview(review!.shortReview!),
                  Text('最終: $summary',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black87)),
                ],
              ),
              childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isFetching) const LinearProgressIndicator(minHeight: 2),
                if (groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text('調教データなし',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  )
                else
                  ...groups.map((group) => _buildRaceGroup(horse, group)),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _gateBarWidth,
            child: _buildGateBar(horse),
          ),
        ],
      ),
    );
  }

  /// レースごとのまとまり（見出し・着順・短評・調教）
  Widget _buildRaceGroup(PredictionHorseDetail horse, TrainingRaceGroup group) {
    NetkeibaTrainingReview? review;
    if (group.isCurrent) {
      review = _raceReviews[horse.horseId];
    }
    final raceId = group.raceId;
    if (review == null && raceId != null) {
      review = _horseReviews[horse.horseId]?[raceId];
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            color: group.isCurrent
                ? Colors.green.shade100
                : Colors.blueGrey.shade50,
            child: Row(
              children: [
                Expanded(
                  child: Text(group.title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                ),
                if (group.result != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade200,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(group.result!,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          if (review?.shortReview != null)
            _buildShortReview(review!.shortReview!),
          for (final entry in group.entries)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _buildSessionBlock(buildTrainingRowView(entry)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(_trainingStatusLabel(),
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _fetchFromApi,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('調教データを取得'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
          child: Row(
            children: [
              ToggleButtons(
                isSelected: [!_showAll, _showAll],
                onPressed: (index) => setState(() => _showAll = index == 1),
                borderRadius: BorderRadius.circular(6),
                constraints:
                    const BoxConstraints(minHeight: 32, minWidth: 110),
                children: const [
                  Text('最終追い切り', style: TextStyle(fontSize: 12)),
                  Text('中間追い切り含む', style: TextStyle(fontSize: 12)),
                ],
              ),
              if (!_isLoggedIn)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '※netkeiba未ログインのため評価・コメントは表示されません',
                      maxLines: 2,
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: widget.horses.length,
                  itemBuilder: (context, index) {
                    final horse = widget.horses[index];
                    return _showAll
                        ? _buildAllCard(horse)
                        : _buildFinalCard(horse);
                  },
                ),
        ),
      ],
    );
  }
}
