// lib/widgets/shutuba_tabs/horse_detail_tab.dart

// [追加] 出走馬データ読み込み統一 Step4: 読み込み係の知らせの購読（StreamSubscription）と、レース日より前の戦績の読み込み (v.2026.10.16+26101621)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/services/race_entrant_data_service.dart';
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
// [追加] 馬詳細タブ 表示項目変更 Step2: 今回レースの芝/ダ（ヒートマップと同じ判定） (v.2026.10.15+26101501)
import 'package:hetaumakeiba_v2/logic/analysis/condition_ranking_builder.dart';
// [追加] 馬体重成長曲線 Step2: 情報・血統の最下部の成長曲線（期間の種類とセクション部品） (v.2026.10.1+26100102)
// [修正] 馬詳細タブ 表示項目変更 Step3追補: 成長曲線の縦軸をレース全体で決めるため、growth_curve_builder とレース日の読み取りを使う (v.2026.10.15+26101502)
import 'package:hetaumakeiba_v2/logic/growth_curve_builder.dart';
import 'package:hetaumakeiba_v2/utils/speed_index_date_parser.dart';
import 'package:hetaumakeiba_v2/widgets/horse_detail/growth_curve_section.dart';
// [追加] 陣営の本気度指数 実施順6: 情報・血統のいちばん下の「出走の意味」 (v.2026.10.3+26100308)
import 'package:hetaumakeiba_v2/logic/entry_meaning_snapshot.dart';
import 'package:hetaumakeiba_v2/widgets/horse_detail/entry_meaning_section.dart';

// [追加] 馬詳細タブStep3: 出馬表の「馬詳細」タブ。馬番順・1頭1ページで、左右スワイプ／◀▶／馬番チップで馬を切り替える (v.2026.9.23+26092308)
// [修正] 馬詳細タブStep4: チップの左端に「全」（全頭の最終追い切り一覧。PageView の1ページ目、開いたときの初期表示）を追加。
// 項目の開閉行をやめ、見出しの下の4つのボタン（情報・血統／最終追切／中間追切／メモ）で表示を切り替える (v.2026.9.23+26092309)

// [追加] AI分析データエクスポート Step4: exportAiData を追加 (v.2026.9.27+26092704)
// [修正] AI分析データ 過去データ分離 Step3: exportPastData（過去データを共有）を追加 (v.2026.10.14+26101403)
enum _HorseDetailMenuAction { fetchTraining, bulkEditMemos, importMemos, exportMemos, exportAiData, exportPastData }

/// 馬のページに表示する内容（ボタンで切り替え、馬を変えても保つ）
enum _HorseDetailView { info, finalTraining, interimTraining, memo, condition }

class HorseDetailTabWidget extends StatefulWidget {
  final String raceId;
  final PredictionRaceData predictionRaceData;
  final List<PredictionHorseDetail> horses;
  final Widget Function(PredictionHorseDetail) buildMarkDropdown;
  final void Function(PredictionHorseDetail horse, HorseMemo memo) onMemoSaved;
  final Future<void> Function() reloadMemos;

  // [追加] 陣営の本気度指数 実施順6: 出走の意味の計算結果・1回読み終わったか・レース結果があるレースか（出馬表から受け取る） (v.2026.10.3+26100308)
  final EntryMeaningSnapshot? entryMeaningSnapshot;
  final bool entryMeaningLoaded;
  final bool isResultView;

  const HorseDetailTabWidget({
    Key? key,
    required this.raceId,
    required this.predictionRaceData,
    required this.horses,
    required this.buildMarkDropdown,
    required this.onMemoSaved,
    required this.reloadMemos,
    this.entryMeaningSnapshot,
    this.entryMeaningLoaded = false,
    this.isResultView = false,
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

  // [追加] 基本情報整理と本賞金照合 Step1: 「情報・血統」の基本情報と血統の開閉（全馬共通・初期は開。馬を切り替えても保つ） (v.2026.10.15+26101504)
  bool _basicInfoExpanded = true;

  // [削除] 馬詳細タブ 表示項目変更 Step3: 成長曲線の期間スイッチを廃止したので、表示期間の状態（_growthRange）を削除 (v.2026.10.15+26101502)

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
    // [追加] 出走馬データ読み込み統一 Step4: このレースの戦績を読み込み係が捨てたら（戦績・調教の取り直しなど）、
    // 好走条件・成長曲線の読み込みをやり直す (v.2026.10.16+26101621)
    _entrantDataSubscription =
        RaceEntrantDataService.instance.changes.listen((raceId) {
      if (!mounted || raceId != widget.raceId) return;
      setState(() {
        _allPastRecordsFuture = null;
        _recordsFutures.clear();
        _trackCondFutures.clear();
      });
    });
  }

  // [追加] 出走馬データ読み込み統一 Step4: 読み込み係の知らせの購読 (v.2026.10.16+26101621)
  StreamSubscription<String>? _entrantDataSubscription;

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
    // [追加] 出走馬データ読み込み統一 Step4: 読み込み係の知らせの購読を止める (v.2026.10.16+26101621)
    _entrantDataSubscription?.cancel();
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

  // [追加] 馬体重成長曲線 Step2: 成長曲線用に、表示した馬の過去走を1頭1回だけ読む（通信なし）。
  // 結果が空のときは保持せず、次に表示したときに読み直す（レース準備で戦績が後から入る場合に備える） (v.2026.10.1+26100102)
  final Map<String, Future<List<HorseRaceRecord>>> _recordsFutures = {};

  // [修正] 出走馬データ読み込み統一 Step4: 全馬の戦績（読み込み係のレース日より前の走）からその馬の分を取り出す (v.2026.10.16+26101621)
  Future<List<HorseRaceRecord>> _recordsFor(String horseId) {
    return _recordsFutures.putIfAbsent(horseId, () async {
      final all = await _allPastRecords();
      final records = all[horseId] ?? const <HorseRaceRecord>[];
      if (records.isEmpty) {
        _recordsFutures.remove(horseId);
      }
      return records;
    });
  }

  // [追加] 馬詳細タブ 表示項目変更 Step3追補: 成長曲線の縦軸をレース全体で1つに決める。取消の馬を除く全出走馬の
  // 全期間の体重（レース日より前の走＋発表済みなら当日体重）の最小−10kg〜最大+10kg。出馬表を更新して取消が変われば計算し直される (v.2026.10.15+26101502)
  GrowthWeightWindow _raceWeightWindow(Map<String, List<HorseRaceRecord>> all) {
    final raceDate = parseRaceDateForSpeedIndex(widget.predictionRaceData.raceDate);
    return GrowthCurveBuilder.raceWeightWindow([
      for (final h in _horses)
        if (!h.isScratched)
          GrowthCurveBuilder.buildPoints(
            records: all[h.horseId] ?? const <HorseRaceRecord>[],
            raceDate: raceDate,
            currentHorseWeight: h.horseWeight,
          ),
    ]);
  }

  // [追加] 好走条件 馬詳細移植 StepA-2: 全馬の過去走を1回だけ読む（対戦成績用。好走条件を初めて開いたときに実行） (v.2026.9.25+26092506)
  Future<Map<String, List<HorseRaceRecord>>>? _allPastRecordsFuture;

  Future<Map<String, List<HorseRaceRecord>>> _allPastRecords() {
    return _allPastRecordsFuture ??= _loadAllPastRecords();
  }

  // [修正] 出走馬データ読み込み統一 Step4: 全馬の戦績は読み込み係が1回だけ読んだ、今回のレース日より前の走（そのレース自身の行も除く）を使う。
  // 過去のレースを開いたとき、好走条件にそのレースや後の走が入っていた (v.2026.10.16+26101621)
  Future<Map<String, List<HorseRaceRecord>>> _loadAllPastRecords() async {
    final entrantData =
        await RaceEntrantDataService.instance.load(widget.predictionRaceData);
    return {
      for (final h in _horses) h.horseId: entrantData.recordsOf(h.horseId),
    };
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

  // [追加] 馬詳細タブ 表示項目変更 Step2: 今回レースの当日の馬場データ（クッション値/含水率）を1回だけ引く。当日の測定が無ければ null (v.2026.10.15+26101501)
  Future<TrackConditionRecord?>? _currentTrackConditionFuture;

  Future<TrackConditionRecord?> _currentTrackCondition() {
    return _currentTrackConditionFuture ??= _trackConditionRepo.getTrackConditionForRace(
      raceId: widget.raceId,
      raceDate: widget.predictionRaceData.raceDate,
    );
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
      // [追加] AI分析データ 過去データ分離 Step3 (v.2026.10.14+26101403)
      case _HorseDetailMenuAction.exportPastData:
        await exportPastRaceDataAsMarkdown(
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
              // [追加] AI分析データ 過去データ分離 Step3: 過去の同じレースの結果を出す (v.2026.10.14+26101403)
              PopupMenuItem(
                value: _HorseDetailMenuAction.exportPastData,
                child: Text('過去データを共有'),
              ),
              // [追加] AI分析データエクスポート Step4 (v.2026.9.27+26092704)
              // [修正] AI分析データ 過去データ分離 Step2: 文言を「追加データを共有」にする (v.2026.10.14+26101402)
              PopupMenuItem(
                value: _HorseDetailMenuAction.exportAiData,
                child: Text('追加データを共有'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // [修正] 基本情報整理と本賞金照合 Step1: B だけの印から、馬柱（starters_tab の _buildNewspaperMarkChip）と同じ見た目の印（外・地・B）にした (v.2026.10.15+26101504)
  Widget _buildMarkChip(String label, {bool isRed = false}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      decoration: BoxDecoration(
        color: isRed ? Colors.red : Colors.black,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // [追加] 馬詳細タブ 表示項目変更 Step4: 出走の意味のバッジ1つ。色は左端のラベルのグループごと
  // （クラス=青・遠征=紫・間隔=緑・騎手=橙・同陣営=青灰） (v.2026.10.15+26101503)
  Widget _buildMeaningBadge(EntryMeaningBadge badge) {
    final Color color;
    switch (badge.group) {
      case 'クラス':
        color = Colors.blue.shade700;
        break;
      case '遠征':
        color = Colors.purple.shade600;
        break;
      case '間隔':
        color = Colors.green.shade700;
        break;
      case '騎手':
        color = Colors.orange.shade800;
        break;
      case '同陣営':
        color = Colors.blueGrey.shade600;
        break;
      default:
        color = Colors.grey.shade700;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        badge.label,
        style: TextStyle(
            fontSize: 10,
            height: 1.2,
            color: color,
            fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildHeader(PredictionHorseDetail horse) {
    final hasGate = horse.gateNumber > 0;
    // [追加] 馬詳細タブ 表示項目変更 Step4: 馬名の下（騎手・斤量・人気の行の下）に出走の意味のバッジ。無ければ行を出さない (v.2026.10.15+26101503)
    final badges = entryMeaningBadgesOf(
        widget.entryMeaningSnapshot?.horseOf(horse.horseId));
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
                    // [修正] 基本情報整理と本賞金照合 Step1: 馬柱と同じ並び（馬名の後ろにB、性齢の後ろに外・地） (v.2026.10.15+26101504)
                    if (horse.isBlinker)
                      _buildMarkChip('B', isRed: horse.isFirstBlinker),
                    const SizedBox(width: 6),
                    Text(horse.sexAndAge,
                        style: const TextStyle(fontSize: 12)),
                    if (horse.isMaruGai) _buildMarkChip('外'),
                    if (horse.isMaruChi) _buildMarkChip('地'),
                  ],
                ),
                Text(
                  subLine,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                if (badges.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Wrap(
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        for (final badge in badges) _buildMeaningBadge(badge),
                      ],
                    ),
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

  // [追加] 基本情報整理と本賞金照合 Step1: 「基本情報」の見出し。行全体のタップで基本情報と血統を開閉する（右端に開閉の矢印） (v.2026.10.15+26101504)
  Widget _buildBasicInfoHeader() {
    return InkWell(
      onTap: () => setState(() => _basicInfoExpanded = !_basicInfoExpanded),
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 4),
        child: Row(
          children: [
            const Text('基本情報',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            const Spacer(),
            Icon(
              _basicInfoExpanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: Colors.grey.shade700,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoView(PredictionHorseDetail horse) {
    return FutureBuilder<HorseProfile?>(
      future: _profileFor(horse.horseId),
      builder: (context, snapshot) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // [修正] 基本情報整理と本賞金照合 Step1: 基本情報（netkeibaの馬ページと同じ項目）と血統をまとめて折りたためるようにした (v.2026.10.15+26101504)
          _buildBasicInfoHeader(),
          if (_basicInfoExpanded) ...[
            BasicInfoSection(horse: horse, profile: snapshot.data),
            const SizedBox(height: 8),
            _sectionLabel('血統'),
            PedigreeSection(horse: horse, profile: snapshot.data),
          ],
          // [追加] 馬体重成長曲線 Step2: 血統表の下に成長曲線（馬体重の推移＋人気・着順） (v.2026.10.1+26100102)
          const SizedBox(height: 12),
          _sectionLabel('成長曲線（馬体重・人気・着順）'),
          // [修正] 馬詳細タブ 表示項目変更 Step3追補: 全馬の過去走（好走条件と同じ読み込み）も読んで、レース全体の縦軸を渡す。
          // 取消の馬を開いたときは、その馬の体重だけで縦軸を決める (v.2026.10.15+26101502)
          FutureBuilder<Map<String, List<HorseRaceRecord>>>(
            future: _allPastRecords(),
            builder: (context, allSnapshot) {
              if (allSnapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              final all = allSnapshot.data ??
                  const <String, List<HorseRaceRecord>>{};
              return FutureBuilder<List<HorseRaceRecord>>(
                future: _recordsFor(horse.horseId),
                builder: (context, recordSnapshot) {
                  if (recordSnapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return GrowthCurveSection(
                    horse: horse,
                    records: recordSnapshot.data ?? const <HorseRaceRecord>[],
                    raceDate: widget.predictionRaceData.raceDate,
                    // 全馬の読み込みが空でも、この馬の過去走は必ず縦軸に入れる
                    window: horse.isScratched
                        ? null
                        : _raceWeightWindow({
                            ...all,
                            horse.horseId: recordSnapshot.data ??
                                const <HorseRaceRecord>[],
                          }),
                  );
                },
              );
            },
          ),
          // [追加] 陣営の本気度指数 実施順6: 成長曲線の下（いちばん下）に「出走の意味」 (v.2026.10.3+26100308)
          const SizedBox(height: 12),
          _sectionLabel('出走の意味'),
          EntryMeaningSection(
            horse: horse,
            snapshot: widget.entryMeaningSnapshot,
            loaded: widget.entryMeaningLoaded,
            isResultView: widget.isResultView,
          ),
          const SizedBox(height: 16),
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
                // [修正] 馬詳細タブ 表示項目変更 Step2: 今回レースの当日の馬場データも読んでから表示し、今回の芝/ダと一緒に渡す (v.2026.10.15+26101501)
                return FutureBuilder<TrackConditionRecord?>(
                  future: _currentTrackCondition(),
                  builder: (context, currentSnapshot) {
                    if (currentSnapshot.connectionState != ConnectionState.done) {
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
                      currentSurface:
                          ConditionRankingBuilder.conditionsOf(widget.predictionRaceData).surface,
                      currentTrackCondition: currentSnapshot.data,
                    );
                  },
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
            // [追加] 馬詳細タブ 表示項目変更 Step3: 横スワイプで馬を切り替えない（成長曲線の横スクロールとぶつけない）。
            // 馬の切り替えは馬番チップ・◀ ▶・全頭一覧のカードで行う (v.2026.10.15+26101502)
            physics: const NeverScrollableScrollPhysics(),
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
