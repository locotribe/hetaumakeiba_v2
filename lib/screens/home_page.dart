// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/models/home_page_data_model.dart';
import 'package:hetaumakeiba_v2/widgets/featured_race_list_item.dart';
import 'package:hetaumakeiba_v2/widgets/venue_races_card.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomePageData? _homePageData;
  bool _isLoading = true;

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
      final data = await ScraperService.scrapeHomePageData();

      // 重賞レースを日付でソート
      data.gradedRaces.sort((a, b) => a.raceDate.compareTo(b.raceDate));

      setState(() {
        _homePageData = data;
        _isLoading = false;
      });
    } catch (e) {
      print('ERROR: ホームページのデータロード中にエラーが発生しました: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _homePageData = HomePageData(gradedRaces: [], racesByVenue: []);
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
            : (_homePageData == null || (_homePageData!.gradedRaces.isEmpty && _homePageData!.racesByVenue.isEmpty))
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
                if (_homePageData!.gradedRaces.isNotEmpty) ...[
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
                  ..._homePageData!.gradedRaces.map((race) {
                    return FeaturedRaceListItem(
                      race: race,
                      onTap: () {
                        print('DEBUG: ${race.raceName} の詳細へ遷移: ${race.shutubaTableUrl}');
                      },
                    );
                  }).toList(),
                ],

                const SizedBox(height: 24),

                // --- セクション2: 開催場別レース一覧 ---
                if (_homePageData!.racesByVenue.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(bottom: 4.0, left: 4.0),
                    child: Text(
                      '開催場別レース一覧',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  ..._homePageData!.racesByVenue.map((venueRaces) {
                    return VenueRacesCard(venueRaces: venueRaces);
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
