// lib/widgets/track_condition_ticker.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ★追加
import 'package:intl/intl.dart'; // ★追加: 時刻フォーマット用
import '../models/track_conditions_model.dart';
import '../db/database_helper.dart';
import '../services/track_conditions_scraper_service.dart';

class TrackConditionTicker extends StatefulWidget {
  const TrackConditionTicker({super.key});

  @override
  State<TrackConditionTicker> createState() => _TrackConditionTickerState();
}

class _TrackConditionTickerState extends State<TrackConditionTicker> {
  List<TrackConditionRecord> _records = [];
  bool _isSyncing = false;
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  int _currentIndex = 0;
  String _lastUpdatedTime = "--:--"; // ★追加: 最終取得時刻を保持する変数

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isSyncing = true);

    try {
      // ★SharedPreferencesから最終取得時刻を読み込む
      final prefs = await SharedPreferences.getInstance();
      final lastScrapedStr = prefs.getString('last_track_condition_scrape_time');
      if (lastScrapedStr != null) {
        final lastDate = DateTime.parse(lastScrapedStr);
        _lastUpdatedTime = DateFormat('HH:mm').format(lastDate);
      }

      final List<String> activeCourseNames = await TrackConditionsScraperService.getActiveCourseNames();
      final allLatestRecords = await DatabaseHelper().getLatestTrackConditionsForEachCourse();

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

    // （削除処理は消し、正しいスクレイパーだけを実行します）
    await TrackConditionsScraperService.scrapeAndSave();

    // 取得時刻を現在時刻で更新
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_track_condition_scrape_time', DateTime.now().toIso8601String());

    // ティッカーの表示データを再読み込み
    await _loadData();

    if (mounted) {
      setState(() => _isSyncing = false);
    }
  }

  void _startSequence() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
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
          SizedBox(
            width: 40,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Center(
                heightFactor: 1.0,
                child: _isSyncing
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
                )
                    : IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.refresh, color: Colors.orange, size: 18),
                  onPressed: _handleRefresh,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: VerticalDivider(color: Colors.white24, width: 1),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                final record = _records[index % _records.length];
                final courseName = _getCourseName(record.trackConditionId);
                final jpWeekday = _getJapaneseWeekday(record.weekDay);
                final dateFull = record.date.replaceAll("-", "/");

                return Container(
                  width: 380,
                  padding: const EdgeInsets.only(left: 8, right: 8, top: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // ブロック1: 開催場・日付・更新時刻
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${courseName}競馬場',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          Text('$dateFull $jpWeekday',
                              style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          // ★ここを変更: 動的な最終更新時刻を表示
                          Text('更新 $_lastUpdatedTime',
                              style: const TextStyle(color: Colors.white70, fontSize: 10)),
                        ],
                      ),

                      // ブロック2: 芝クッション値
                      Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('クッション値', style: TextStyle(color: Colors.white70, fontSize: 10)),
                          Text('${record.cushionValue ?? "-"}',
                              style: const TextStyle(color: Colors.greenAccent, fontSize: 22, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                        ],
                      ),

                      // ブロック3: 芝含水率
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

                      // ブロック4: ダート含水率
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