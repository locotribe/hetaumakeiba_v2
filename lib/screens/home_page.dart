// lib/screens/home_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';
import 'package:hetaumakeiba_v2/screens/shutuba_table_page.dart'; // ★追加
import 'package:hetaumakeiba_v2/widgets/featured_race_list_item.dart'; // ★追加
import 'package:intl/intl.dart'; // ★追加

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<FeaturedRace> _weeklyGradedRaces = [];
  List<FeaturedRace> _monthlyGradedRaces = [];
  bool _isLoading = true;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isHorseDataSynced = false;

  @override
  void initState() {
    super.initState();
    _loadHomePageData();
  }

  Future<void> _loadHomePageData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      // 2つのスクレイピング処理を並行して実行
      final results = await Future.wait([
        ScraperService.scrapeFeaturedRaces(_dbHelper),      // ★修正：dbHelperを渡す
        ScraperService.scrapeMonthlyGradedRaces(), // 今月の重賞を取得
      ]);

      final weeklyRaces = results[0];
      final monthlyRaces = results[1];

      // 日付でソート
      weeklyRaces.sort((a, b) => _parseDateStringAsDateTime(a.raceDate).compareTo(_parseDateStringAsDateTime(b.raceDate))); // ★修正：StringをDateTimeに変換して比較
      monthlyRaces.sort((a, b) => _parseDateStringAsDateTime(a.raceDate).compareTo(_parseDateStringAsDateTime(b.raceDate))); // ★修正：StringをDateTimeに変換して比較

      setState(() {
        _weeklyGradedRaces = weeklyRaces;
        _monthlyGradedRaces = monthlyRaces;
        _isLoading = false;
      });

      if (!_isHorseDataSynced && _weeklyGradedRaces.isNotEmpty) {
        _isHorseDataSynced = true;
        // UIをブロックしないようにawaitなしで呼び出す
        ScraperService.syncNewHorseData(_weeklyGradedRaces, _dbHelper);
      }

    } catch (e) {
      print('ERROR: ホームページのデータロード中にエラーが発生しました: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _weeklyGradedRaces = [];
          _monthlyGradedRaces = [];
        });
      }
    }
  }

  // ★追加：String形式の日付をDateTimeに変換するヘルパーメソッド
  DateTime _parseDateStringAsDateTime(String dateText) {
    try {
      final parts = RegExp(r'(\d+)年(\d+)月(\d+)日').firstMatch(dateText);
      if (parts != null && parts.groupCount >= 3) {
        final year = int.parse(parts.group(1)!);
        final month = int.parse(parts.group(2)!);
        final day = int.parse(parts.group(3)!);
        return DateTime(year, month, day);
      }
      final currentYear = DateTime.now().year;
      final monthDayParts = RegExp(r'(\d+)月(\d+)日').firstMatch(dateText);
      if (monthDayParts != null && monthDayParts.groupCount >= 2) {
        final month = int.parse(monthDayParts.group(1)!);
        final day = int.parse(monthDayParts.group(2)!);
        return DateTime(currentYear, month, day);
      }
      return DateTime.now();
    } catch (e) {
      print('Date parsing error in HomePage: $dateText, Error: $e');
      return DateTime.now();
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
        _isLoading
            ? const Center(child: CircularProgressIndicator())
            : (_weeklyGradedRaces.isEmpty && _monthlyGradedRaces.isEmpty)
            ? Center(
          child: RefreshIndicator(
            onRefresh: _loadHomePageData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.8,
                alignment: Alignment.center,
                child: const Text(
                  '今週のレース情報はありません。',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        )
            : RefreshIndicator(
          onRefresh: _loadHomePageData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- セクション1: 今週の重賞 ---
                if (_weeklyGradedRaces.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0, bottom: 4.0, left: 4.0),
                    child: Text(
                      '今週の重賞レース',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  ..._weeklyGradedRaces.map((race) {
                    return FeaturedRaceListItem( // ★修正：FeaturedRaceListItemを使用
                      race: race,
                      onTap: () {
                        // ★修正：出馬表ページへの遷移
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ShutubaTablePage(raceId: race.raceId),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ],

                const SizedBox(height: 24),

                // --- セクション2: 今月の重賞レース一覧 ---
                if (_monthlyGradedRaces.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4.0, left: 4.0),
                    child: Text(
                      '今月の重賞レース',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  ..._monthlyGradedRaces.map((race) {
                    return FeaturedRaceListItem( // ★修正：FeaturedRaceListItemを使用
                      race: race,
                      onTap: () {}, // タップしても何もしないように空の関数を設定
                    );
                  }).toList(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}