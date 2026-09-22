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

// [追加] 馬詳細タブStep3: 出馬表の「馬詳細」タブ。馬番順・1頭1ページで、左右スワイプ／◀▶／馬番チップで馬を切り替える。
// 項目は基本情報・血統・調教・メモ（旧メモタブ・旧調教タブをまとめた。設計書 3-2） (v.2026.9.23+26092308)

enum _HorseDetailMenuAction { fetchTraining, bulkEditMemos, importMemos, exportMemos }

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

  final HorseRepository _horseRepo = HorseRepository();
  final PageController _pageController = PageController();
  final ScrollController _chipScrollController = ScrollController();
  late List<PredictionHorseDetail> _horses;
  late final RaceTrainingViewModel _trainingViewModel;
  int _currentIndex = 0;
  String? _currentHorseId;
  HorseDetailTrainingMode _trainingMode = HorseDetailTrainingMode.finalOnly;

  /// 4項目の開閉（馬を切り替えても保つ）
  final Map<String, bool> _expanded = {
    'basic': true,
    'pedigree': true,
    'training': true,
    'memo': true,
  };

  /// ページを表示したときに1頭1回だけ読む（通信なし）
  final Map<String, Future<HorseProfile?>> _profileFutures = {};
  final Map<String, Future<List<PastMemoDetail>>> _pastMemoFutures = {};

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _horses = orderHorsesForDetail(widget.horses);
    _currentHorseId = _horses.isNotEmpty ? _horses.first.horseId : null;
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
    if (_horses.isEmpty) {
      _currentIndex = 0;
      _currentHorseId = null;
      return;
    }
    // 親の再描画で馬のリストが作り直されても、表示中の馬を保つ
    var index = _horses.indexWhere((h) => h.horseId == _currentHorseId);
    if (index < 0) index = 0;
    _currentHorseId = _horses[index].horseId;
    if (index != _currentIndex) {
      _currentIndex = index;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(_currentIndex);
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

  void _goTo(int index, {bool animate = true}) {
    if (index < 0 || index >= _horses.length) return;
    if (!_pageController.hasClients) return;
    if (animate && (index - _currentIndex).abs() == 1) {
      _pageController.animateToPage(index,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    } else {
      _pageController.jumpToPage(index);
    }
  }

  void _onPageChanged(int index) {
    if (index < 0 || index >= _horses.length) return;
    final horse = _horses[index];
    setState(() {
      _currentIndex = index;
      _currentHorseId = horse.horseId;
    });
    _scrollChipIntoView(index);
    // 「中間追い切り含む」の表示中は、その馬のページを表示したときに競走馬調教ページを取得（必要なときだけ）
    if (_trainingMode == HorseDetailTrainingMode.withInterim) {
      _trainingViewModel.fetchHorseTrainingIfNeeded(horse.horseId);
    }
  }

  void _scrollChipIntoView(int index) {
    if (!_chipScrollController.hasClients) return;
    final position = _chipScrollController.position;
    final target = _chipListPadding +
        index * (_chipWidth + _chipSpacing) -
        (position.viewportDimension - _chipWidth) / 2;
    _chipScrollController.animateTo(
      target.clamp(0.0, position.maxScrollExtent).toDouble(),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _onTrainingModeChanged(HorseDetailTrainingMode mode) {
    setState(() => _trainingMode = mode);
    final horseId = _currentHorseId;
    if (mode == HorseDetailTrainingMode.withInterim && horseId != null) {
      _trainingViewModel.fetchHorseTrainingIfNeeded(horseId);
    }
  }

  /// 全頭一覧でカードをタップしたとき: その馬のページへ移り、切替を「最終追い切り」に戻す
  void _selectHorseFromList(PredictionHorseDetail horse) {
    final index = _horses.indexWhere((h) => h.horseId == horse.horseId);
    if (index < 0) return;
    setState(() => _trainingMode = HorseDetailTrainingMode.finalOnly);
    _goTo(index, animate: false);
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
    }
  }

  Widget _buildChip(int index) {
    final horse = _horses[index];
    final hasGate = horse.gateNumber > 0;
    final isSelected = index == _currentIndex;
    return GestureDetector(
      onTap: () => _goTo(index, animate: false),
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
                itemCount: _horses.length,
                itemBuilder: (context, index) => _buildChip(index),
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                _currentIndex > 0 ? () => _goTo(_currentIndex - 1) : null,
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
            onPressed: _currentIndex < _horses.length - 1
                ? () => _goTo(_currentIndex + 1)
                : null,
          ),
        ],
      ),
    );
  }

  /// 見出しのタップで開閉する項目（開閉状態は _expanded で全ページ共通）
  Widget _buildSection(String key, String title, Widget Function() childBuilder) {
    final isExpanded = _expanded[key] ?? true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded[key] = !isExpanded),
          child: Container(
            color: Colors.grey.shade200,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                ),
                Icon(isExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 20),
              ],
            ),
          ),
        ),
        if (isExpanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
            child: childBuilder(),
          ),
      ],
    );
  }

  Widget _buildHorsePage(PredictionHorseDetail horse) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _buildSection(
          'basic',
          '基本情報',
          () => FutureBuilder<HorseProfile?>(
            future: _profileFor(horse.horseId),
            builder: (context, snapshot) =>
                BasicInfoSection(horse: horse, profile: snapshot.data),
          ),
        ),
        _buildSection(
          'pedigree',
          '血統',
          () => FutureBuilder<HorseProfile?>(
            future: _profileFor(horse.horseId),
            builder: (context, snapshot) =>
                PedigreeSection(horse: horse, profile: snapshot.data),
          ),
        ),
        _buildSection(
          'training',
          '調教',
          () => AnimatedBuilder(
            animation: _trainingViewModel,
            builder: (context, _) => TrainingSection(
              horse: horse,
              allHorses: _horses,
              viewModel: _trainingViewModel,
              raceId: widget.raceId,
              mode: _trainingMode,
              onModeChanged: _onTrainingModeChanged,
              onSelectHorse: _selectHorseFromList,
            ),
          ),
        ),
        _buildSection(
          'memo',
          'メモ',
          () => MemoSection(
            horse: horse,
            pastMemosFuture: _pastMemosFor(horse.horseId),
            onEdit: () => _editMemo(horse),
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
    final currentHorse = _horses[_currentIndex];
    return Column(
      children: [
        _buildChipBar(),
        _buildHeader(currentHorse),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: _horses.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) => _buildHorsePage(_horses[index]),
          ),
        ),
      ],
    );
  }
}
