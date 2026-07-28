import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:hetaumakeiba_v2/services/track_conditions_scraper_service.dart';
import 'package:hetaumakeiba_v2/services/cloud_sync_service.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/widgets/track_condition_card.dart';

// [修正] 馬場状態をカードリストで表示する専用ページ。開催ごとのトレンドグラフ対応のため保持データをMapに変更 (v.2026.7.28+26072809)
class TrackConditionPage extends StatefulWidget {
  const TrackConditionPage({super.key});

  @override
  State<TrackConditionPage> createState() => _TrackConditionPageState();
}

class _TrackConditionPageState extends State<TrackConditionPage> {
  final TrackConditionRepository _trackConditionRepo = TrackConditionRepository();
  // [修正] 会場名をキーに、同一開催の全履歴リストを保持するよう変更（トレンドグラフ表示用） (v.2026.7.28+26072809)
  Map<String, List<TrackConditionRecord>> _meetingRecords = {};
  bool _isSyncing = false;
  bool _needsCloudSync = false;
  String _lastUpdatedTime = "--:--";

  @override
  void initState() {
    super.initState();
    _checkAndAutoScrape();
  }

  Future<void> _checkAndAutoScrape() async {
    if (!mounted) return;
    setState(() => _isSyncing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastScraped = prefs.getString('last_track_condition_scrape_time');
      final localVersion = prefs.getInt('track_condition_csv_version') ?? 0;
      final now = DateTime.now();

      if (localVersion == 0 && lastScraped == null) {
        final cloudSyncService = CloudSyncService();
        await cloudSyncService.importFromCloud();
        await prefs.setString('last_track_condition_scrape_time', now.toIso8601String());
      } else {
        bool shouldScrape = false;
        if (lastScraped == null) {
          shouldScrape = true;
        } else {
          final lastDate = DateTime.parse(lastScraped);
          if (now.difference(lastDate).inHours >= 2) {
            shouldScrape = true;
          }
        }
        if (shouldScrape) {
          await TrackConditionsScraperService.scrapeAndSave();
          await prefs.setString('last_track_condition_scrape_time', now.toIso8601String());
        }
      }
    } finally {
      await loadData();
    }
  }

  Future<void> loadData() async {
    if (!mounted) return;
    setState(() => _isSyncing = true);

    try {
      final cloudSyncService = CloudSyncService();
      final needsSync = await cloudSyncService.checkSyncRequired();

      final prefs = await SharedPreferences.getInstance();
      final lastScrapedStr = prefs.getString('last_track_condition_scrape_time');
      if (lastScrapedStr != null) {
        final lastDate = DateTime.parse(lastScrapedStr);
        _lastUpdatedTime = DateFormat('HH:mm').format(lastDate);
      }

      final List<String> activeCourseNames = await TrackConditionsScraperService.getActiveCourseNames();
      final allLatestRecords = await _trackConditionRepo.getLatestTrackConditionsForEachCourse();

      // [修正] 各会場の最新レコードから開催prefix8(YYYYCCKK)を求め、同一開催の全履歴を取得するよう変更（トレンドグラフ表示用） (v.2026.7.28+26072809)
      final Map<String, List<TrackConditionRecord>> meetingRecords = {};
      for (var name in activeCourseNames) {
        try {
          final latest = allLatestRecords.firstWhere(
                  (r) => _getCourseName(r.trackConditionId) == name
          );
          final prefix8 = latest.trackConditionId.toString().substring(0, 8);
          final history = await _trackConditionRepo.getTrackConditionsByMeeting(prefix8);
          if (history.isNotEmpty) {
            meetingRecords[name] = history;
          }
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _needsCloudSync = needsSync;
          _meetingRecords = meetingRecords;
          _isSyncing = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleRefresh() async {
    if (!mounted) return;
    setState(() => _isSyncing = true);

    try {
      if (_needsCloudSync) {
        final cloudSyncService = CloudSyncService();
        final success = await cloudSyncService.importFromCloud();
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('クラウドから過去データを補完しました'), backgroundColor: Colors.green),
          );
        }
      } else {
        await TrackConditionsScraperService.scrapeAndSave();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_track_condition_scrape_time', DateTime.now().toIso8601String());

      await loadData();
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _needsCloudSync = false;
        });
      }
    }
  }

  String _getCourseName(int id) {
    String idStr = id.toString();
    if (idStr.length < 6) return "不明";
    String cc = idStr.substring(4, 6);
    final Map<String, String> codes = {
      '01': '札幌', '02': '函館', '03': '福島', '04': '新潟', '05': '東京',
      '06': '中山', '07': '中京', '08': '京都', '09': '阪神', '10': '小倉',
    };
    return codes[cc] ?? "他";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('馬場状態'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Text(
                '最終更新: $_lastUpdatedTime',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          ),
          if (_isSyncing)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    _needsCloudSync ? Icons.cloud_download : Icons.refresh,
                    color: _needsCloudSync ? Colors.redAccent : Colors.white,
                  ),
                  onPressed: _handleRefresh,
                ),
                if (_needsCloudSync)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomBackground(
              overallBackgroundColor: Color.fromRGBO(231, 234, 234, 1.0),
              stripeColor: Color.fromRGBO(219, 234, 234, 0.6),
              fillColor: Color.fromRGBO(172, 234, 231, 1.0),
            ),
          ),
          if (_meetingRecords.isEmpty && !_isSyncing)
            const Center(
              child: Text(
                '現在開催中の馬場状態データがありません',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            RefreshIndicator(
              onRefresh: _handleRefresh,
              child: Builder(
                builder: (context) {
                  // [修正] Mapの値(開催ごとの履歴リスト)を順序保持のままリスト化してカードへ渡す (v.2026.7.28+26072809)
                  final meetingHistories = _meetingRecords.values.toList();
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    itemCount: meetingHistories.length,
                    itemBuilder: (context, index) {
                      return TrackConditionCard(
                        meetingHistory: meetingHistories[index],
                        lastUpdatedTime: _lastUpdatedTime,
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
