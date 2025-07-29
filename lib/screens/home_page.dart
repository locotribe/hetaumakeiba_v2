// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';
import 'package:hetaumakeiba_v2/widgets/featured_race_list_item.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<FeaturedRace> _weeklyGradedRaces = [];
  List<FeaturedRace> _monthlyGradedRaces = [];
  bool _isLoading = true;

  // ▼▼▼ ここから新規追加 ▼▼▼
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isHorseDataSynced = false; // データ取得処理を一度しか実行しないためのフラグ
  // ▲▲▲ ここまで新規追加 ▲▲▲

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
        ScraperService.scrapeFeaturedRaces(),      // 今週の重賞を取得
        ScraperService.scrapeMonthlyGradedRaces(), // 今月の重賞を取得
      ]);

      final weeklyRaces = results[0];
      final monthlyRaces = results[1];

      // 日付でソート
      weeklyRaces.sort((a, b) => a.raceDate.compareTo(b.raceDate));
      monthlyRaces.sort((a, b) => a.raceDate.compareTo(b.raceDate));

      setState(() {
        _weeklyGradedRaces = weeklyRaces;
        _monthlyGradedRaces = monthlyRaces;
        _isLoading = false;
      });

      // ▼▼▼ ここから新規追加 ▼▼▼
      // 初回読み込み時のみ、新規の競走馬データをバックグラウンドで取得
      if (!_isHorseDataSynced && _weeklyGradedRaces.isNotEmpty) {
        _isHorseDataSynced = true; // フラグを立てて再実行を防ぐ
        // UIをブロックしないようにawaitなしで呼び出す
        ScraperService.syncNewHorseData(_weeklyGradedRaces, _dbHelper);
      }
      // ▲▲▲ ここまで新規追加 ▲▲▲

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
                    return FeaturedRaceListItem(
                      race: race,
                      // ▼▼▼ ここから修正 ▼▼▼
                      onTap: () async {
                        final Uri url = Uri.parse(race.shutubaTableUrl);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        } else {
                          // エラーハンドリング（例: SnackBarでユーザーに通知）
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('URLを開けませんでした: ${race.shutubaTableUrl}')),
                          );
                        }
                      },
                      // ▲▲▲ ここまで修正 ▲▲▲
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
                    return FeaturedRaceListItem(
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