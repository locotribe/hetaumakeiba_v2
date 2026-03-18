// lib/widgets/track_condition_ticker.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import '../services/track_conditions_scraper_service.dart';
import '../services/cloud_sync_service.dart'; // ★追加

final GlobalKey<TrackConditionTickerState> trackConditionTickerKey = GlobalKey<TrackConditionTickerState>();

class TrackConditionTicker extends StatefulWidget {
  TrackConditionTicker({Key? key}) : super(key: key ?? trackConditionTickerKey);

  @override
  State<TrackConditionTicker> createState() => TrackConditionTickerState();
}

class TrackConditionTickerState extends State<TrackConditionTicker> {
  final TrackConditionRepository _trackConditionRepo = TrackConditionRepository();
  List<TrackConditionRecord> _records = [];
  bool _isSyncing = false;
  bool _needsCloudSync = false; // ★追加: クラウド同期が必要かどうかのフラグ
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  int _currentIndex = 0;
  String _lastUpdatedTime = "--:--";

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    if (!mounted) return;
    setState(() => _isSyncing = true);

    try {
      // ★追加: クラウド同期の必要性をチェック
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

      final List<TrackConditionRecord> filteredRecords = [];
      for (var name in activeCourseNames) {
        try {
          final record = allLatestRecords.firstWhere(
                  (r) => _getCourseName(r.trackConditionId) == name
          );
          filteredRecords.add(record);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _needsCloudSync = needsSync; // ★追加
          _records = filteredRecords;
          _isSyncing = false;
        });
        if (_records.isNotEmpty) {
          _startSequence();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleRefresh() async {
    setState(() => _isSyncing = true);

    if (_needsCloudSync) {
      // ★追加: クラウドからのインポートを実行
      final cloudSyncService = CloudSyncService();
      final success = await cloudSyncService.importFromCloud();
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('クラウドから過去データを補完しました'), backgroundColor: Colors.green),
        );
      }
    } else {
      // 従来のスクレイピング
      await TrackConditionsScraperService.scrapeAndSave();
    }

    // 取得時刻を現在時刻で更新
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_track_condition_scrape_time', DateTime.now().toIso8601String());

    // ティッカーの表示データを再読み込み
    await loadData();

    if (mounted) {
      setState(() {
        _isSyncing = false;
        _needsCloudSync = false; // ★追加: リフレッシュ後はフラグを落とす
      });
    }
  }
  void _startSequence() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!mounted) return;
      // 画面幅が足りているか（全会場が一度に表示できるか）を判定
      // 1会場の幅380 + 左の更新ボタン等の幅約50
      final double requiredWidth = 380.0 * _records.length + 50.0;
      if (MediaQuery.of(context).size.width >= requiredWidth) return;

      if (_scrollController.hasClients && _records.length > 1) {
        _currentIndex++;
        _scrollController.animateTo(
          _currentIndex * 380.0,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
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

  String _getJapaneseWeekday(String weekDayCode) {
    final Map<String, String> weekdays = {
      'mo': '月', 'tu': '火', 'we': '水', 'th': '木',
      'fr': '金', 'sa': '土', 'su': '日',
    };
    return weekdays[weekDayCode.toLowerCase()] ?? "";
  }

  @override
  Widget build(BuildContext context) {
    if (_records.isEmpty && !_isSyncing) return const SizedBox.shrink();

    return Container(
      height: 64,
      color: Colors.black.withOpacity(0.85),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ★変更: 更新ボタンのUIを必要性に応じて切り替え
          Container(
            width: 48,
            height: 64,
            alignment: Alignment.center,
            child: _isSyncing
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.orange,
              ),
            )
                : Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                      _needsCloudSync ? Icons.cloud_download : Icons.refresh,
                      color: _needsCloudSync ? Colors.redAccent : Colors.orange,
                      size: 22
                  ),
                  onPressed: _handleRefresh,
                ),
                if (_needsCloudSync)
                  Positioned(
                    right: 4,
                    top: 12,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: const VerticalDivider(color: Colors.white24, width: 1),
          ),

          Expanded(
            child: _records.isEmpty
                ? Center(
              child: Text(
                _isSyncing ? '最新データを取得中...' : 'データがありません',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: MediaQuery.of(context).size.width >= (380.0 * _records.length + 50.0) ? _records.length : null,

              itemBuilder: (context, index) {
                final record = _records[index % _records.length];
                final courseName = _getCourseName(record.trackConditionId);
                final jpWeekday = _getJapaneseWeekday(record.weekDay);
                final dateFull = record.date.replaceAll("-", "/");

                return Container(
                  width: 380,
                  padding: const EdgeInsets.only(left: 8, right: 16, top: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${courseName}競馬場',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          Text('$dateFull $jpWeekday',
                              style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          Text('更新 $_lastUpdatedTime',
                              style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('クッション値', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          Text('${record.cushionValue ?? "-"}',
                              style: const TextStyle(color: Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('芝含水率', style: TextStyle(color: Colors.white70, fontSize: 9)),
                          Row(
                            children: [
                              const SizedBox(width: 19, child: Text('G:', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace'))),
                              Text('${record.moistureTurfGoal ?? "-"}%', style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace')),
                            ],
                          ),
                          Row(
                            children: [
                              const SizedBox(width: 19, child: Text('4C:', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace'))),
                              Text('${record.moistureTurf4c ?? "-"}%', style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontFamily: 'monospace')),
                            ],
                          ),
                        ],
                      ),
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('ダ含水率', style: TextStyle(color: Colors.white70, fontSize: 9)),
                          Row(
                            children: [
                              const SizedBox(width: 20, child: Text('G:', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontFamily: 'monospace'))),
                              Text('${record.moistureDirtGoal ?? "-"}%', style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontFamily: 'monospace')),
                            ],
                          ),
                          Row(
                            children: [
                              const SizedBox(width: 20, child: Text('4C:', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontFamily: 'monospace'))),
                              Text('${record.moistureDirt4c ?? "-"}%', style: const TextStyle(color: Colors.orangeAccent, fontSize: 10, fontFamily: 'monospace')),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}