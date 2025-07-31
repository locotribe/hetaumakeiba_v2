// lib/screens/jyusyoichiran_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';
import 'package:hetaumakeiba_v2/screens/shutuba_table_page.dart';
import 'package:hetaumakeiba_v2/widgets/featured_race_list_item.dart';
import 'package:hetaumakeiba_v2/screens/race_result_page.dart';
import 'package:intl/intl.dart';

class JyusyoIchiranPage extends StatefulWidget {
  const JyusyoIchiranPage({super.key});

  @override
  State<JyusyoIchiranPage> createState() => _JyusyoIchiranPageState();
}

class _JyusyoIchiranPageState extends State<JyusyoIchiranPage> {
  List<FeaturedRace> _weeklyGradedRaces = [];
  List<FeaturedRace> _yearlyGradedRaces = [];
  bool _isLoading = true;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isHorseDataSynced = false;

  PageController _pageController = PageController();
  late int _currentMonth;
  List<int> _availableMonths = [];


  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now().month;
    _loadJyusyoIchiranPageData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadJyusyoIchiranPageData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final results = await Future.wait([
        ScraperService.scrapeFeaturedRaces(_dbHelper),
        ScraperService.scrapeMonthlyGradedRaces(),
      ]);

      final weeklyRaces = results[0];
      final yearlyRaces = results[1];

      weeklyRaces.sort((a, b) => _parseDateStringAsDateTime(a.raceDate).compareTo(_parseDateStringAsDateTime(b.raceDate)));
      yearlyRaces.sort((a, b) => _parseDateStringAsDateTime(a.raceDate).compareTo(_parseDateStringAsDateTime(b.raceDate)));

      final availableMonths = yearlyRaces.map((race) => _parseDateStringAsDateTime(race.raceDate).month).toSet().toList();
      availableMonths.sort();

      int initialPage = availableMonths.indexOf(_currentMonth);
      if (initialPage == -1) {
        initialPage = 0;
      }

      _pageController = PageController(initialPage: initialPage);

      if (!mounted) return;
      setState(() {
        _weeklyGradedRaces = weeklyRaces;
        _yearlyGradedRaces = yearlyRaces;
        _availableMonths = availableMonths;
        if (_availableMonths.isNotEmpty) {
          _currentMonth = _availableMonths[initialPage];
        }
        _isLoading = false;
      });

      if (!_isHorseDataSynced && _weeklyGradedRaces.isNotEmpty) {
        _isHorseDataSynced = true;
        ScraperService.syncNewHorseData(_weeklyGradedRaces, _dbHelper);
      }

      // 未来のレースは除外して同期処理に渡す
      final today = DateTime.now();
      final pastRaces = _yearlyGradedRaces.where((race) {
        final raceDate = _parseDateStringAsDateTime(race.raceDate);
        // レース開催日が今日より前の場合のみ同期対象とする
        return raceDate.isBefore(DateTime(today.year, today.month, today.day));
      }).toList();

      ScraperService.syncPastMonthlyRaceResults(pastRaces, _dbHelper);

    } catch (e) {
      print('ERROR: 重賞一覧ページのデータロード中にエラーが発生しました: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _weeklyGradedRaces = [];
          _yearlyGradedRaces = [];
        });
      }
    }
  }

  DateTime _parseDateStringAsDateTime(String dateText) {
    try {
      final yearMonthDayMatch = RegExp(r'(\d+)年(\d+)月(\d+)日').firstMatch(dateText);
      if (yearMonthDayMatch != null) {
        final year = int.parse(yearMonthDayMatch.group(1)!);
        final month = int.parse(yearMonthDayMatch.group(2)!);
        final day = int.parse(yearMonthDayMatch.group(3)!);
        return DateTime(year, month, day);
      }
      final monthDayMatch = RegExp(r'(\d+)月(\d+)日').firstMatch(dateText);
      if (monthDayMatch != null) {
        final month = int.parse(monthDayMatch.group(1)!);
        final day = int.parse(monthDayMatch.group(2)!);
        return DateTime(DateTime.now().year, month, day);
      }
      final slashDateMatch = RegExp(r'(\d+)/(\d+)').firstMatch(dateText);
      if (slashDateMatch != null) {
        final month = int.parse(slashDateMatch.group(1)!);
        final day = int.parse(slashDateMatch.group(2)!);
        return DateTime(DateTime.now().year, month, day);
      }
      return DateTime.now();
    } catch (e) {
      print('Date parsing error in JyusyoIchiranPage: $dateText, Error: $e');
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
            : (_weeklyGradedRaces.isEmpty && _yearlyGradedRaces.isEmpty)
            ? _buildEmptyState()
            : RefreshIndicator(
          onRefresh: _loadJyusyoIchiranPageData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWeeklyRaces(),
                const SizedBox(height: 24),
                if (_yearlyGradedRaces.isNotEmpty)
                  _buildMonthlyRacesPageView(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: RefreshIndicator(
        onRefresh: _loadJyusyoIchiranPageData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.8,
            alignment: Alignment.center,
            child: const Text(
              'レース情報はありません。',
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
    );
  }

  Widget _buildWeeklyRaces() {
    if (_weeklyGradedRaces.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            onTap: () {
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
    );
  }

  Widget _buildMonthlyRacesPageView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMonthSelectorHeader(),
        const SizedBox(height: 8),
        SizedBox(
          height: 400,
          child: PageView.builder(
            controller: _pageController,
            itemCount: _availableMonths.length,
            onPageChanged: (index) {
              setState(() {
                _currentMonth = _availableMonths[index];
              });
            },
            itemBuilder: (context, index) {
              final month = _availableMonths[index];
              return _buildMonthlyRaceList(month);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthSelectorHeader() {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0, right: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '重賞レース一覧',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_left),
                onPressed: () {
                  if (_pageController.page! > 0) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.ease,
                    );
                  }
                },
              ),
              Text(
                '${DateTime.now().year}年 $_currentMonth月',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_right),
                onPressed: () {
                  if (_pageController.page! < _availableMonths.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.ease,
                    );
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyRaceList(int month) {
    final racesForMonth = _yearlyGradedRaces.where((race) {
      return _parseDateStringAsDateTime(race.raceDate).month == month;
    }).toList();

    if (racesForMonth.isEmpty) {
      return const Center(
        child: Text('この月のレース情報はありません。'),
      );
    }

    return ListView.builder(
      itemCount: racesForMonth.length,
      itemBuilder: (context, index) {
        final race = racesForMonth[index];
        return FeaturedRaceListItem(
          race: race,
          // ▼▼▼ ステップ4でonTapのロジックを実装 ▼▼▼
          onTap: () async {
            final today = DateTime.now();
            final raceDate = _parseDateStringAsDateTime(race.raceDate);
            // 未来のレース（今日以降）はタップしても何もしない
            if (!raceDate.isBefore(DateTime(today.year, today.month, today.day))) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('このレースはまだ確定していません。')),
              );
              return;
            }
            if (race.shutubaTableUrl.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('このレースの詳細情報はありません。')),
              );
              return;
            }

            // 処理中であることをユーザーに示す（任意）
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('レース結果を取得中...')),
            );

            // 正式なレースIDを取得
            final officialRaceId = await ScraperService.getOfficialRaceId(race.shutubaTableUrl);

            ScaffoldMessenger.of(context).hideCurrentSnackBar();

            if (mounted && officialRaceId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  // 馬券データ(qrData)は渡さずにページを開く
                  builder: (context) => RaceResultPage(raceId: officialRaceId),
                ),
              );
            } else if(mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('レース結果の取得に失敗しました。')),
              );
            }
          },
        );
      },
    );
  }
}