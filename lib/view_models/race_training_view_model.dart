// lib/view_models/race_training_view_model.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/netkeiba_training_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_preparation_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/training_repository.dart';
import 'package:hetaumakeiba_v2/logic/training_display.dart';
import 'package:hetaumakeiba_v2/logic/training_merge.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/netkeiba_training_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_preparation_status_model.dart';
import 'package:hetaumakeiba_v2/services/netkeiba_session_service.dart';
import 'package:hetaumakeiba_v2/services/netkeiba_training_service.dart';
import 'package:hetaumakeiba_v2/services/scraping_manager.dart';
import 'package:hetaumakeiba_v2/services/training_data_service.dart';
import 'package:hetaumakeiba_v2/utils/training_date_utils.dart';

// [追加] 馬詳細タブStep1: 調教タブ（training_tab.dart）の読み込み・取得の処理をここへ移した。
// 処理内容は移す前と同じ。馬詳細タブ（Step3）からも使う (v.2026.9.23+26092306)

/// 準備状態に応じた調教データの見出し文言を返す。
String trainingStatusLabel(RacePreparationStatus? status) {
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

/// 出馬表の調教表示で使う、1レース分の調教データ（pakara・netkeiba・過去成績）の読み込みと取得。
class RaceTrainingViewModel extends ChangeNotifier {
  final String raceId;
  final String raceDate;

  /// 表示中の出走馬（親の再描画で差し替わるため、画面側から更新する）
  List<PredictionHorseDetail> horses;

  RaceTrainingViewModel({
    required this.raceId,
    required this.raceDate,
    required this.horses,
  });

  final TrainingRepository _repository = TrainingRepository();
  final TrainingDataService _service = TrainingDataService();
  final RacePreparationRepository _preparationRepository = RacePreparationRepository();
  final NetkeibaTrainingRepository _netkeibaRepository = NetkeibaTrainingRepository();
  final HorseRepository _horseRepository = HorseRepository();

  Map<String, List<MergedTrainingEntry>> _entries = {};
  Map<String, NetkeibaTrainingReview> _raceReviews = {};
  Map<String, Map<String, NetkeibaTrainingReview>> _horseReviews = {};
  Map<String, List<HorseRaceRecord>> _pastRaces = {};
  final Set<String> _loadingHorseIds = {};
  bool _isLoggedIn = false;
  RacePreparationStatus? _preparationStatus;
  bool _isLoading = true;
  bool _disposed = false;

  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  String get raceYmd => toYyyymmdd(raceDate) ?? '';
  String get statusLabel => trainingStatusLabel(_preparationStatus);

  List<MergedTrainingEntry> entriesFor(String horseId) =>
      _entries[horseId] ?? const <MergedTrainingEntry>[];

  List<HorseRaceRecord> pastRacesFor(String horseId) =>
      _pastRaces[horseId] ?? const <HorseRaceRecord>[];

  /// このレースの評価（短評・A/B/C・厩舎コメント）
  NetkeibaTrainingReview? raceReviewFor(String horseId) => _raceReviews[horseId];

  bool isFetchingHorse(String horseId) => _loadingHorseIds.contains(horseId);

  /// レースごとのまとまりに表示する評価（今回はこのレースの評価、過去は競走馬ページ由来の評価）
  NetkeibaTrainingReview? reviewForGroup(String horseId, TrainingRaceGroup group) {
    NetkeibaTrainingReview? review;
    if (group.isCurrent) {
      review = _raceReviews[horseId];
    }
    final groupRaceId = group.raceId;
    if (review == null && groupRaceId != null) {
      review = _horseReviews[horseId]?[groupRaceId];
    }
    return review;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load({bool showSpinner = true}) async {
    if (showSpinner) {
      _isLoading = true;
      _notify();
    }
    final ymd = raceYmd;
    final entries = <String, List<MergedTrainingEntry>>{};
    final horseReviews = <String, Map<String, NetkeibaTrainingReview>>{};
    final pastRaces = <String, List<HorseRaceRecord>>{};
    for (final horse in horses) {
      // レース当日以降の調教を除外する
      final pakara = filterTrainingBeforeRace(
          await _repository.getTrainingTimesForHorse(horse.horseId),
          raceDate);
      var netkeiba =
          await _netkeibaRepository.getSessionsForHorse(horse.horseId);
      if (ymd.isNotEmpty) {
        netkeiba = netkeiba
            .where((s) => s.trainingDate.compareTo(ymd) < 0)
            .toList();
      }
      entries[horse.horseId] = mergeTrainingSources(pakara, netkeiba);
      final reviews =
          await _netkeibaRepository.getReviewsForHorse(horse.horseId);
      horseReviews[horse.horseId] = {for (final r in reviews) r.raceId: r};
      pastRaces[horse.horseId] =
          await _horseRepository.getHorsePerformanceRecords(horse.horseId);
    }
    final raceReviews = await _netkeibaRepository.getReviewsForRace(raceId);
    // 調教データの取得状態を読み、見出し文言に反映する
    final preparationStatus = await _preparationRepository.getStep(
        raceId, PreparationStep.training);
    final isLoggedIn = await NetkeibaSessionService.isLoggedIn();
    if (_disposed) return;
    _entries = entries;
    _raceReviews = raceReviews;
    _horseReviews = horseReviews;
    _pastRaces = pastRaces;
    _preparationStatus = preparationStatus;
    _isLoggedIn = isLoggedIn;
    _isLoading = false;
    _notify();
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

  /// 取得ボタン: pakara → netkeiba の最終追切・厩舎コメント → 全頭の競走馬調教ページ
  void fetchAll() {
    final formattedDate = _formatDateForApi(raceDate);
    final horseIds = horses.map((h) => h.horseId).toList();

    debugPrint('DEBUG: [Training API] Request Date: $formattedDate, RaceID: $raceId');

    ScrapingManager().addRequest('調教データ取得', () async {
      await _service.fetchAndSaveTrainingData(
        raceId: raceId,
        raceDate: formattedDate,
        horseIds: horseIds,
      );
      // netkeiba の最終追切・厩舎コメントも取得（ログイン中のみ）
      try {
        await NetkeibaTrainingService().fetchAndSaveRaceTraining(
          raceId: raceId,
          horseIds: horseIds,
        );
      } catch (e) {
        debugPrint('TrainingTab: netkeiba 調教の取得に失敗: $e');
      }
      // 全頭の競走馬調教ページを取り直す（ログイン中のみ）
      try {
        await NetkeibaTrainingService().fetchAndSaveHorseTrainings(
          horseIds: horseIds,
          raceId: raceId,
          force: true,
        );
      } catch (e) {
        debugPrint('TrainingTab: 競走馬調教ページの取得に失敗: $e');
      }
      if (!_disposed) {
        await load();
      }
    }, key: 'training:$raceId');
  }

  /// 馬を開いたとき、競走馬調教ページが未取得・古ければ取得する
  void fetchHorseTrainingIfNeeded(String horseId) {
    ScrapingManager().addRequest('競走馬の調教取得', () async {
      final service = NetkeibaTrainingService();
      if (!await service.needsHorseTrainingFetch(horseId, raceId: raceId)) {
        return;
      }
      if (!_disposed) {
        _loadingHorseIds.add(horseId);
        _notify();
      }
      final result = await service.fetchAndSaveHorseTraining(horseId);
      if (_disposed) return;
      _loadingHorseIds.remove(horseId);
      _notify();
      if (result != null) await load(showSpinner: false);
    }, key: 'training_nk_horse:$horseId');
  }

  /// レース日まで0〜7日で、このレースの最終追切の評価が未取得なら自動取得する。
  /// 追切の公開（水・木曜）より前にレース準備が済んだレースのため。同じレースで6時間に1回まで
  Future<void> autoFetchRaceTrainingIfNeeded() async {
    if (_disposed || !_isLoggedIn) return;
    final raceDay = DateTime.tryParse(raceYmd);
    if (raceDay == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = raceDay.difference(today).inDays;
    if (days < 0 || days > 7) return;
    final hasOikiri =
        _raceReviews.values.any((r) => r.rank != null || r.critic != null);
    if (hasOikiri) return;
    final prefs = await SharedPreferences.getInstance();
    final prefKey = 'nk_oikiri_auto_$raceId';
    final last = DateTime.tryParse(prefs.getString(prefKey) ?? '');
    if (last != null && now.difference(last) < const Duration(hours: 6)) {
      return;
    }
    await prefs.setString(prefKey, now.toIso8601String());
    final horseIds = horses.map((h) => h.horseId).toList();
    ScrapingManager().addRequest('最終追切の取得', () async {
      await NetkeibaTrainingService().fetchAndSaveRaceTraining(
        raceId: raceId,
        horseIds: horseIds,
      );
      if (!_disposed) await load(showSpinner: false);
    }, key: 'training_nk_race:$raceId');
  }
}
