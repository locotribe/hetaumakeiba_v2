// lib/widgets/shutuba_tabs/horse_detail_tab.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/logic/horse_detail_order.dart';
import 'package:hetaumakeiba_v2/models/horse_memo_model.dart';
import 'package:hetaumakeiba_v2/models/horse_profile_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/screens/bulk_memo_edit_page.dart';
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';
import 'package:hetaumakeiba_v2/view_models/race_training_view_model.dart';
import 'package:hetaumakeiba_v2/widgets/horse_detail/basic_info_section.dart';
import 'package:hetaumakeiba_v2/widgets/horse_detail/memo_section.dart';
import 'package:hetaumakeiba_v2/widgets/horse_detail/pedigree_section.dart';
import 'package:hetaumakeiba_v2/widgets/horse_detail/training_section.dart';
import 'package:hetaumakeiba_v2/widgets/memo/horse_memo_parts.dart';
// [追加] 好走条件 馬詳細移植 StepA-2: 好走条件ビュー用 (v.2026.9.25+26092506)
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/widgets/horse_detail/condition_section.dart';
// [追加] 好走条件 馬詳細移植 StepA-3: 馬場データ取得（クッション値/含水率） (v.2026.9.25+26092507)
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';

// [追加] 馬詳細タブStep3: 出馬表の「馬詳細」タブ。馬番順・1頭1ページで、左右スワイプ／◀▶／馬番チップで馬を切り替える (v.2026.9.23+26092308)
// [修正] 馬詳細タブStep4: チップの左端に「全」（全頭の最終追い切り一覧。PageView の1ページ目、開いたときの初期表示）を追加。
// 項目の開閉行をやめ、見出しの下の4つのボタン（情報・血統／最終追切／中間追切／メモ）で表示を切り替える (v.2026.9.23+26092309)

// [追加] AI分析データエクスポート Step4: exportAiData を追加 (v.2026.9.27+26092704)
enum _HorseDetailMenuAction { fetchTraining, bulkEditMemos, importMemos, exportMemos, exportAiData }

/// 馬のページに表示する内容（ボタンで切り替え、馬を変えても保つ）
enum _HorseDetailView { info, finalTraining, interimTraining, memo, condition }

class HorseDetailTabWidget extends StatefulWidget {
  final String raceId;
  final PredictionRaceData predictionRaceData;
  final List<PredictionHorseDetail> horses;
  final Widget Function(PredictionHorseDetail) buildMarkDropdown;
  final void Function(PredictionHorseDetail horse, HorseMemo memo) onMemoSaved;
  final Future<void> Function() reloadMemos;

  const HorseDetailTabWidget({
    Key? key,
    required this.raceId,
    required this.predictionRaceData,
    required this.horses,
    required this.buildMarkDropdown,
    required this.onMemoSaved,
    required this.reloadMemos,
  }) : super(key: key);

  @override
  State<HorseDetailTabWidget> createState() => _HorseDetailTabWidgetState();
}

class _HorseDetailTabWidgetState extends State<HorseDetailTabWidget>
    with AutomaticKeepAliveClientMixin {
  static const double _chipWidth = 36;
  static const double _chipSpacing = 4;
  static const double _chipListPadding = 8;
  static const double _viewButtonHeight = 30;

  final HorseRepository _horseRepo = HorseRepository();
  final PageController _pageController = PageController();
  final ScrollController _chipScrollController = ScrollController();
  late List<PredictionHorseDetail> _horses;
  late final RaceTrainingViewModel _trainingViewModel;

  /// 表示中のページ（0 = 全頭一覧、1 以降 = _horses[page - 1]）
  int _currentPage = 0;

  /// 表示中の馬（全頭一覧のときは null）
  String? _currentHorseId;
  _HorseDetailView _view = _HorseDetailView.finalTraining;

  /// ページを表示したときに1頭1回だけ読む（通信なし）
  final Map<String, Future<HorseProfile?>> _profileFutures = {};
  final Map<String, Future<List<PastMemoDetail>>> _pastMemoFutures = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _horses = orderHorsesForDetail(widget.horses);
    _trainingViewModel = RaceTrainingViewModel(
      raceId: widget.raceId,
      raceDate: widget.predictionRaceData.raceDate,
      horses: _horses,
    );
    _trainingViewModel
        .load()
        .then((_) => _trainingViewModel.autoFetchRaceTrainingIfNeeded());
  }

  @override
  void didUpdateWidget(covariant HorseDetailTabWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _horses = orderHorsesForDetail(widget.horses);
    _trainingViewModel.horses = _horses;
    // 親の再描画で馬のリストが作り直されても、表示中の馬（または全頭一覧）を保つ
    int page = 0;
    if (_currentHorseId != null) {
      final index = _horses.indexWhere((h) => h.horseId == _currentHorseId);
      if (index >= 0) {
        page = index + 1;
      } else {
        _currentHorseId = null;
      }
    }
    if (page != _currentPage) {
      _currentPage = page;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(_currentPage);
        }
      });
    }
  }

  @override
  void dispose() {
    _trainingViewModel.dispose();
    _pageController.dispose();
    _chipScrollController.dispose();
    super.dispose();
  }

  PredictionHorseDetail? get _currentHorse =>
      _currentPage > 0 && _currentPage <= _horses.length
          ? _horses[_currentPage - 1]
          : null;

  Future<HorseProfile?> _profileFor(String horseId) {
    return _profileFutures.putIfAbsent(
        horseId, () => _horseRepo.getHorseProfile(horseId));
  }

  Future<List<PastMemoDetail>> _pastMemosFor(String horseId) {
    return _pastMemoFutures.putIfAbsent(
        horseId,
        () => fetchPastMemoDetails(
              horseId: horseId,
              currentRaceId: widget.raceId,
            ));
  }

  // [追加] 好走条件 馬詳細移植 StepA-2: 全馬の過去走を1回だけ読む（対戦成績用。好走条件を初めて開いたときに実行） (v.2026.9.25+26092506)
  Future<Map<String, List<HorseRaceRecord>>>? _allPastRecordsFuture;

  Future<Map<String, List<HorseRaceRecord>>> _allPastRecords() {
    return _allPastRecordsFuture ??= _loadAllPastRecords();
  }

  Future<Map<String, List<HorseRaceRecord>>> _loadAllPastRecords() async {
    final Map<String, List<HorseRaceRecord>> map = {};
    for (final h in _horses) {
      map[h.horseId] = await _horseRepo.getHorsePerformanceRecords(h.horseId);
    }
    return map;
  }

  // [追加] 好走条件 馬詳細移植 StepA-3: 好走条件を開いた馬の過去走ごとに馬場データ（クッション値/含水率）を引く（馬柱と同じ getTrackConditionForRace） (v.2026.9.25+26092507)
  final TrackConditionRepository _trackConditionRepo = TrackConditionRepository();
  final Map<String, Future<Map<String, TrackConditionRecord?>>> _trackCondFutures = {};

  Future<Map<String, TrackConditionRecord?>> _trackCondsFor(
      String horseId, Map<String, List<HorseRaceRecord>> all) {
    return _trackCondFutures.putIfAbsent(horseId, () async {
      final Map<String, TrackConditionRecord?> map = {};
      for (final r in (all[horseId] ?? const <HorseRaceRecord>[])) {
        if (r.raceId.length >= 10) {
          map[r.raceId] = await _trackConditionRepo.getTrackConditionForRace(
            raceId: r.raceId,
            raceDate: r.date,
          );
        }
      }
      return map;
    });
  }

  void _goToPage(int page, {bool animate = true}) {
    if (page < 0 || page > _horses.length) return;
    if (!_pageController.hasClients) return;
    if (animate && (page - _currentPage).abs() == 1) {
      _pageController.animateToPage(page,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _pageController.jumpToPage(page);
    }
  }

  void _onPageChanged(int page) {
    if (page < 0 || page > _horses.length) return;
    setState(() {
      _currentPage = page;
      _currentHorseId = page == 0 ? null : _horses[page - 1].horseId;
    });
    _scrollChipIntoView(page);
    // 「中間追切」を選んでいるときは、その馬のページを表示したときに競走馬調教ページを取得（必要なときだけ）
    final horseId = _currentHorseId;
    if (horseId != null && _view == _HorseDetailView.interimTraining) {
      _trainingViewModel.fetchHorseTrainingIfNeeded(horseId);
    }
  }

  void _scrollChipIntoView(int page) {
    if (!_chipScrollController.hasClients) return;
    final position = _chipScrollController.position;
    final target = _chipListPadding +
        page * (_chipWidth + _chipSpacing) -
        (position.viewportDimension - _chipWidth) / 2;
    _chipScrollController.animateTo(
      target.clamp(0.0, position.maxScrollExtent).toDouble(),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _onViewChanged(_HorseDetailView view) {
    setState(() => _view = view);
    final horseId = _currentHorseId;
    if (view == _HorseDetailView.interimTraining && horseId != null) {
      _trainingViewModel.fetchHorseTrainingIfNeeded(horseId);
    }
  }

  /// 全頭一覧でカードをタップしたとき: その馬のページへ移り、表示を「最終追切」にする
  void _selectHorseFromList(PredictionHorseDetail horse) {
    final index = _horses.indexWhere((h) => h.horseId == horse.horseId);
    if (index < 0) return;
    setState(() => _view = _HorseDetailView.finalTraining);
    _goToPage(index + 1, animate: false);
  }

  Future<void> _editMemo(PredictionHorseDetail horse) async {
    final memo = await showPredictionMemoDialog(
      context,
      horse: horse,
      raceId: widget.raceId,
    );
    if (memo != null && mounted) {
      widget.onMemoSaved(horse, memo);
    }
  }

  Future<void> _onMenuSelected(_HorseDetailMenuAction action) async {
    switch (action) {
      case _HorseDetailMenuAction.fetchTraining:
        _trainingViewModel.fetchAll();
        break;
      case _HorseDetailMenuAction.bulkEditMemos:
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (context) => BulkMemoEditPage(
              horses: widget.predictionRaceData.horses,
              raceId: widget.raceId,
            ),
          ),
        );
        if (result == true && mounted) {
          await widget.reloadMemos();
        }
        break;
      case _HorseDetailMenuAction.importMemos:
        final count = await importMemosFromCsv(context, raceId: widget.raceId);
        if (count != null && mounted) {
          await widget.reloadMemos();
        }
        break;
      case _HorseDetailMenuAction.exportMemos:
        await exportMemosAsCsv(
          raceId: widget.raceId,
          raceData: widget.predictionRaceData,
        );
        break;
      // [追加] AI分析データエクスポート Step4 (v.2026.9.27+26092704)
      case _HorseDetailMenuAction.exportAiData:
        await exportAiRaceDataAsMarkdown(
          context,
          raceId: widget.raceId,
          raceData: widget.predictionRaceData,
        );
        break;
    }
  }

  /// 「全」チップ
  Widget _buildAllChip() {
    final isSelected = _currentPage == 0;
    return GestureDetector(
      onTap: () => _goToPage(0, animate: false),
      child: Container(
        width: _chipWidth,
        margin: const EdgeInsets.only(right: _chipSpacing),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.green.shade800,
          border: Border.all(
            color: isSelected ? Colors.red : Colors.grey.shade500,
            width: isSelected ? 3 : 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Text(
          '全',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildHorseChip(int horseIndex) {
    final horse = _horses[horseIndex];
    final hasGate = horse.gateNumber > 0;
    final isSelected = _currentPage == horseIndex + 1;
    return GestureDetector(
      onTap: () => _goToPage(horseIndex + 1, animate: false),
      child: Opacity(
        opacity: horse.isScratched ? 0.4 : 1.0,
        child: Container(
          width: _chipWidth,
          margin: const EdgeInsets.only(right: _chipSpacing),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: hasGate
                ? horse.gateNumber.gateBackgroundColor
                : Colors.grey.shade400,
            border: Border.all(
              color: isSelected ? Colors.red : Colors.grey.shade500,
              width: isSelected ? 3 : 1,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            horse.horseNumber > 0 ? '${horse.horseNumber}' : '-',
            style: TextStyle(
              color: hasGate ? horse.gateNumber.gateTextColor : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChipBar() {
    return Container(
      color: Colors.grey.shade100,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: _chipWidth,
              child: ListView.builder(
                controller: _chipScrollController,
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: _chipListPadding),
                itemCount: _horses.length + 1,
                itemBuilder: (context, index) => index == 0
                    ? _buildAllChip()
                    : _buildHorseChip(index - 1),
              ),
            ),
          ),
          PopupMenuButton<_HorseDetailMenuAction>(
            icon: const Icon(Icons.more_vert),
            onSelected: _onMenuSelected,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _HorseDetailMenuAction.fetchTraining,
                child: Text('調教データを取得（全頭）'),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _HorseDetailMenuAction.bulkEditMemos,
                child: Text('メモの一括編集'),
              ),
              PopupMenuItem(
                value: _HorseDetailMenuAction.importMemos,
                child: Text('メモをインポート'),
              ),
              PopupMenuItem(
                value: _HorseDetailMenuAction.exportMemos,
                child: Text('メモをエクスポート'),
              ),
              // [追加] AI分析データエクスポート Step4 (v.2026.9.27+26092704)
              PopupMenuItem(
                value: _HorseDetailMenuAction.exportAiData,
                child: Text('AI分析用データを共有'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBlinkerChip(bool isRed) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: isRed ? Colors.red : Colors.black,
        borderRadius: BorderRadius.circular(3),
      ),
      child: const Text(
        'B',
        style: TextStyle(
            fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildHeader(PredictionHorseDetail horse) {
    final hasGate = horse.gateNumber > 0;
    final subLine = '${horse.jockey} ${horse.carriedWeight.toStringAsFixed(1)}'
        '  ${horse.popularity ?? '--'}人気 ${horse.odds?.toString() ?? '--'}倍';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 2),
      color: Colors.white,
      child: Row(
        children: [
          // 1番の馬の ◀ は全頭一覧へ戻る
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _goToPage(_currentPage - 1),
          ),
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: hasGate
                  ? horse.gateNumber.gateBackgroundColor
                  : Colors.grey.shade400,
              border: Border.all(color: Colors.grey),
            ),
            child: Text(
              horse.horseNumber > 0 ? '${horse.horseNumber}' : '-',
              style: TextStyle(
                color: hasGate ? horse.gateNumber.gateTextColor : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        horse.horseName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: horse.isScratched
                              ? TextDecoration.lineThrough
                              : null,
                          color: horse.isScratched
                              ? Colors.grey
                              : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(horse.sexAndAge,
                        style: const TextStyle(fontSize: 12)),
                    if (horse.isBlinker)
                      _buildBlinkerChip(horse.isFirstBlinker),
                  ],
                ),
                Text(
                  subLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 48,
            height: 36,
            child: horse.isScratched
                ? const Center(
                    child: Text('取消',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  )
                : widget.buildMarkDropdown(horse),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _currentPage < _horses.length
                ? () => _goToPage(_currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }

  /// 表示を切り替える4つのボタン（同じ幅で1行）
  Widget _buildViewButtons() {
    const labels = {
      _HorseDetailView.info: '情報・血統',
      _HorseDetailView.finalTraining: '最終追切',
      _HorseDetailView.interimTraining: '中間追切',
      _HorseDetailView.memo: 'メモ',
      _HorseDetailView.condition: '好走条件',
    };
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 6),
      child: Row(
        children: [
          for (final view in _HorseDetailView.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: InkWell(
                  onTap: () => _onViewChanged(view),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: _viewButtonHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _view == view
                          ? Colors.green.shade100
                          : Colors.white,
                      border: Border.all(
                        color: _view == view
                            ? Colors.green.shade700
                            : Colors.grey.shade400,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labels[view]!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: _view == view
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _view == view
                              ? Colors.green.shade900
                              : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Text(text,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildInfoView(PredictionHorseDetail horse) {
    return FutureBuilder<HorseProfile?>(
      future: _profileFor(horse.horseId),
      builder: (context, snapshot) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionLabel('基本情報'),
          BasicInfoSection(horse: horse, profile: snapshot.data),
          const SizedBox(height: 12),
          _sectionLabel('血統'),
          PedigreeSection(horse: horse, profile: snapshot.data),
        ],
      ),
    );
  }

  Widget _buildHorsePage(PredictionHorseDetail horse) {
    late final Widget content;
    switch (_view) {
      case _HorseDetailView.info:
        content = _buildInfoView(horse);
        break;
      case _HorseDetailView.finalTraining:
        content = AnimatedBuilder(
          animation: _trainingViewModel,
          builder: (context, _) => TrainingFinalView(
            horse: horse,
            viewModel: _trainingViewModel,
            raceId: widget.raceId,
          ),
        );
        break;
      case _HorseDetailView.interimTraining:
        content = AnimatedBuilder(
          animation: _trainingViewModel,
          builder: (context, _) => TrainingInterimView(
            horse: horse,
            viewModel: _trainingViewModel,
            raceId: widget.raceId,
          ),
        );
        break;
      case _HorseDetailView.memo:
        content = MemoSection(
          horse: horse,
          pastMemosFuture: _pastMemosFor(horse.horseId),
          onEdit: () => _editMemo(horse),
        );
        break;
      case _HorseDetailView.condition:
        content = FutureBuilder<Map<String, List<HorseRaceRecord>>>(
          future: _allPastRecords(),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final all = snapshot.data ?? const <String, List<HorseRaceRecord>>{};
            // [追加] 好走条件 馬詳細移植 StepA-3: 馬場データ（クッション値/含水率）を読んでから表示 (v.2026.9.25+26092507)
            return FutureBuilder<Map<String, TrackConditionRecord?>>(
              future: _trackCondsFor(horse.horseId, all),
              builder: (context, tcSnapshot) {
                if (tcSnapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return ConditionSection(
                  horse: horse,
                  allPastRecords: all,
                  currentRaceHorses: _horses,
                  trackConditions: tcSnapshot.data ?? const {},
                );
              },
            );
          },
        );
        break;
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      children: [content],
    );
  }

  Widget _buildAllHorsesPage() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
      children: [
        AnimatedBuilder(
          animation: _trainingViewModel,
          builder: (context, _) => TrainingAllHorsesView(
            horses: _horses,
            viewModel: _trainingViewModel,
            raceId: widget.raceId,
            onSelectHorse: _selectHorseFromList,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_horses.isEmpty) {
      return const Center(child: Text('出走馬がありません'));
    }
    final currentHorse = _currentHorse;
    return Column(
      children: [
        _buildChipBar(),
        if (currentHorse != null) ...[
          _buildHeader(currentHorse),
          _buildViewButtons(),
        ],
        Container(height: 1, color: Colors.grey.shade300),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _horses.length + 1,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, page) => page == 0
                ? _buildAllHorsesPage()
                : _buildHorsePage(_horses[page - 1]),
          ),
        ),
      ],
    );
  }
}
