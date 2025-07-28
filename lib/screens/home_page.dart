// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart'; // ★★★★★ 追加：DatabaseHelperをインポート ★★★★★
import 'package:hetaumakeiba_v2/services/scraper_service.dart'; // ★★★★★ 追加：ScraperServiceをインポート ★★★★★
import 'package:hetaumakeiba_v2/models/featured_race_model.dart'; // ★★★★★ 追加：FeaturedRaceモデルをインポート ★★★★★
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart'; // ★★★★★ 追加：HorsePerformanceモデルをインポート ★★★★★

// StatelessWidgetからStatefulWidgetに変更
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<FeaturedRace> _featuredRaces = [];
  bool _isLoading = true;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadFeaturedRaces();
  }

  /// 注目レースのデータをロードし、必要に応じてスクレイピングと保存を行います。
  Future<void> _loadFeaturedRaces() async {
    setState(() {
      _isLoading = true;
    });

    try {
      List<FeaturedRace> cachedRaces = await _dbHelper.getAllFeaturedRaces();

      // キャッシュされたデータが古すぎるか、存在しない場合はスクレイピング
      // 例: 最終スクレイピングから1日以上経過している場合
      bool shouldScrape = cachedRaces.isEmpty ||
          cachedRaces.any((race) =>
          DateTime.now().difference(race.lastScraped).inHours > 24);

      if (shouldScrape) {
        print('DEBUG: 注目レース情報をスクレイピングします。');
        final newFeaturedRaces = await ScraperService.scrapeFeaturedRaces();

        if (newFeaturedRaces.isNotEmpty) {
          // 古いデータを全て削除し、新しいデータを保存
          await _dbHelper.deleteAllFeaturedRaces();
          for (final race in newFeaturedRaces) {
            await _dbHelper.insertOrUpdateFeaturedRace(race);

            // 注目レースの出走馬のホースIDを取得し、競走成績をスクレイピング
            final horseIds = await ScraperService.extractHorseIdsFromShutubaPage(race.shutubaTableUrl);
            for (final horseId in horseIds) {
              final latestRecord = await _dbHelper.getLatestHorsePerformanceRecord(horseId);
              // 最新のデータがまだ存在しない、または日付が異なる場合にのみスクレイピング
              // 注目レースの馬はまだレースが開催されていない可能性があるので、
              // 日付比較ではなく、単純にデータが存在しない場合にスクレイピングする
              if (latestRecord == null) {
                try {
                  final horseRecords = await ScraperService.scrapeHorsePerformance(horseId);
                  for (final record in horseRecords) {
                    await _dbHelper.insertOrUpdateHorsePerformance(record);
                  }
                  // 過度なリクエストを防ぐため、各馬のスクレイピング後に短い遅延を入れる
                  await Future.delayed(const Duration(milliseconds: 500));
                } catch (e) {
                  print('ERROR: 注目レースの競走馬ID $horseId の成績スクレイピングまたは保存中にエラーが発生しました: $e');
                }
              } else {
                print('DEBUG: 注目レースの競走馬ID $horseId の成績は既に存在します。スキップします。');
              }
            }
          }
          cachedRaces = newFeaturedRaces; // 新しいデータを表示用に設定
        } else {
          print('DEBUG: 注目レースのスクレイピング結果が空でした。');
        }
      } else {
        print('DEBUG: 注目レース情報は最新です。キャッシュを使用します。');
      }

      setState(() {
        _featuredRaces = cachedRaces;
        _isLoading = false;
      });
    } catch (e) {
      print('ERROR: 注目レースのロード中にエラーが発生しました: $e');
      setState(() {
        _isLoading = false;
        // エラー発生時は空のリストを表示するか、エラーメッセージを表示
        _featuredRaces = [];
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
        _isLoading
            ? const Center(
          child: CircularProgressIndicator(), // ロード中はインジケーターを表示
        )
            : _featuredRaces.isEmpty
            ? const Center(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              '今週の注目レース情報はありません。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        )
            : ListView.builder(
          padding: const EdgeInsets.all(16.0),
          itemCount: _featuredRaces.length,
          itemBuilder: (context, index) {
            final race = _featuredRaces[index];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              elevation: 2.0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${race.raceDate} ${race.venue} ${race.raceNumber}R',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4.0),
                    Text(
                      '${race.raceName} (${race.raceGrade})',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueAccent,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    // ここに、必要に応じて出走馬リストや詳細へのリンクを追加できます
                    Align(
                      alignment: Alignment.bottomRight,
                      child: TextButton(
                        onPressed: () {
                          // 注目レースの詳細ページへ遷移するロジック（例: 出馬表URLを開く）
                          // Navigator.push(context, MaterialPageRoute(builder: (context) => RaceDetailsPage(raceId: race.raceId)));
                          print('DEBUG: ${race.raceName} の詳細へ遷移: ${race.shutubaTableUrl}');
                          // TODO: 必要に応じて、race.shutubaTableUrl を使って詳細ページへ遷移する
                        },
                        child: const Text('詳細を見る'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
