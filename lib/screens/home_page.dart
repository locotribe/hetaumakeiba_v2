// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/feed_model.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/widgets/feed_card_widget.dart';
import 'package:hetaumakeiba_v2/screens/home_settings_page.dart';
import 'package:hetaumakeiba_v2/main.dart';
import 'package:hetaumakeiba_v2/widgets/track_condition_ticker.dart'; // 追加
import 'package:hetaumakeiba_v2/services/track_conditions_scraper_service.dart'; // 追加
import 'package:shared_preferences/shared_preferences.dart'; // 追加

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  late Future<List<Feed>> _feedsFuture;

  @override
  void initState() {
    super.initState();
    _refreshFeeds();
    _checkAndAutoScrape(); // 自動更新チェック
  }

  /// 馬場情報の自動取得ロジック
  Future<void> _checkAndAutoScrape() async {
    final prefs = await SharedPreferences.getInstance();
    final lastScraped = prefs.getString('last_track_condition_scrape_time');
    final now = DateTime.now();

    bool shouldScrape = false;
    if (lastScraped == null) {
      shouldScrape = true;
    } else {
      final lastDate = DateTime.parse(lastScraped);
      // 2時間以上経過していれば更新
      if (now.difference(lastDate).inHours >= 2) {
        shouldScrape = true;
      }
    }

    if (shouldScrape) {
      await TrackConditionsScraperService.scrapeAndSave();
      await prefs.setString('last_track_condition_scrape_time', now.toIso8601String());
      // setStateを呼ぶことで、子の TrackConditionTicker が initState を経由して loadData を再実行します
      if (mounted) {
        setState(() {
          _refreshFeeds(); // ついでにフィードも更新
        });
      }
    }
  }

  void _refreshFeeds() {
    if (mounted) {
      setState(() {
        final userId = localUserId;
        if (userId == null) {
          _feedsFuture = Future.value([]);
        } else {
          _feedsFuture = _dbHelper.getAllFeeds(userId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: CustomBackground(
            overallBackgroundColor: Color.fromRGBO(231, 234, 234, 1.0),
            stripeColor: Color.fromRGBO(219, 234, 234, 0.6),
            fillColor: Color.fromRGBO(172, 234, 231, 1.0),
          ),
        ),
        Column(
          children: [
            // ティッカーのみを追加
            TrackConditionTicker(),
            Expanded(
              child: FutureBuilder<List<Feed>>(
                future: _feedsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('エラーが発生しました: ${snapshot.error}'));
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return _buildEmptyState();
                  }

                  final feeds = snapshot.data!;
                  return RefreshIndicator(
                    onRefresh: () async => _refreshFeeds(),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                      itemCount: feeds.length,
                      itemBuilder: (context, index) {
                        return FeedCard(feed: feeds[index]);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_link, size: 60, color: Colors.black38),
          const SizedBox(height: 16),
          const Text(
            'ニュースフィードが登録されていません。',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.settings),
            label: const Text('設定画面から追加する'),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const HomeSettingsPage(),
                ),
              );
              _refreshFeeds();
            },
          ),
        ],
      ),
    );
  }
}