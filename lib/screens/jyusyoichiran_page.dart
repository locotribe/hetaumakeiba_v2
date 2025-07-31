// lib/screens/jyusyoichiran_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';
import 'package:hetaumakeiba_v2/screens/shutuba_table_page.dart';
import 'package:hetaumakeiba_v2/widgets/featured_race_list_item.dart';
import 'package:intl/intl.dart';

class JyusyoIchiranPage extends StatefulWidget {
  const JyusyoIchiranPage({super.key});

  @override
  State<JyusyoIchiranPage> createState() => _JyusyoIchiranPageState();
}

class _JyusyoIchiranPageState extends State<JyusyoIchiranPage> {
  // --- State Variables ---
  List<FeaturedRace> _weeklyGradedRaces = [];
  // ★ RENAME: 月間から年間に変更
  List<FeaturedRace> _yearlyGradedRaces = [];
  bool _isLoading = true;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isHorseDataSynced = false;

  // ★ ADD: PageView制御用
  PageController _pageController = PageController();
  // ★ ADD: 表示中の月
  late int _currentMonth;
  // ★ ADD: データが存在する月のリスト
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
      // 2つのスクレイピング処理を並行して実行
      final results = await Future.wait([
        ScraperService.scrapeFeaturedRaces(_dbHelper),
        // ★ CHANGE: 年間データを取得する（関数名は変更なし）
        ScraperService.scrapeMonthlyGradedRaces(),
      ]);

      final weeklyRaces = results[0];
      // ★ CHANGE: 年間データを格納
      final yearlyRaces = results[1];

      // 日付でソート
      weeklyRaces.sort((a, b) => _parseDateStringAsDateTime(a.raceDate).compareTo(_parseDateStringAsDateTime(b.raceDate)));
      yearlyRaces.sort((a, b) => _parseDateStringAsDateTime(a.raceDate).compareTo(_parseDateStringAsDateTime(b.raceDate)));

      // ★ ADD: 利用可能な月を抽出してソート
      final availableMonths = yearlyRaces.map((race) => _parseDateStringAsDateTime(race.raceDate).month).toSet().toList();
      availableMonths.sort();

      // ★ ADD: 現在の月に最も近い初期ページを計算
      int initialPage = availableMonths.indexOf(_currentMonth);
      if (initialPage == -1) {
        initialPage = 0; // 現在の月のデータがない場合は最初の月を表示
      }

      // ★ ADD: PageControllerを初期化
      _pageController = PageController(initialPage: initialPage);


      if (!mounted) return;
      setState(() {
        _weeklyGradedRaces = weeklyRaces;
        // ★ CHANGE: Stateを更新
        _yearlyGradedRaces = yearlyRaces;
        _availableMonths = availableMonths;
        // 最初のページに対応する月をセット
        if (_availableMonths.isNotEmpty) {
          _currentMonth = _availableMonths[initialPage];
        }
        _isLoading = false;
      });

      if (!_isHorseDataSynced && _weeklyGradedRaces.isNotEmpty) {
        _isHorseDataSynced = true;
        ScraperService.syncNewHorseData(_weeklyGradedRaces, _dbHelper);
      }

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

  // ★ UPDATE: 'M/d' 形式の日付文字列もパースできるように修正
  DateTime _parseDateStringAsDateTime(String dateText) {
    try {
      // "yyyy年M月d日" 形式
      final yearMonthDayMatch = RegExp(r'(\d+)年(\d+)月(\d+)日').firstMatch(dateText);
      if (yearMonthDayMatch != null) {
        final year = int.parse(yearMonthDayMatch.group(1)!);
        final month = int.parse(yearMonthDayMatch.group(2)!);
        final day = int.parse(yearMonthDayMatch.group(3)!);
        return DateTime(year, month, day);
      }
      // "M月d日" 形式
      final monthDayMatch = RegExp(r'(\d+)月(\d+)日').firstMatch(dateText);
      if (monthDayMatch != null) {
        final month = int.parse(monthDayMatch.group(1)!);
        final day = int.parse(monthDayMatch.group(2)!);
        return DateTime(DateTime.now().year, month, day);
      }
      // "M/d(曜日)" 形式
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

  // ★★★ UI BUILD METHOD ★★★
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
                // --- セクション1: 今週の重賞 (変更なし) ---
                _buildWeeklyRaces(),

                const SizedBox(height: 24),

                // --- ★★★ セクション2: 月別重賞レース一覧 (新UI) ★★★ ---
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

  // 「今週の重賞」を構築するウィジェット (変更なし)
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

  // ★★★ ADD: 月別重賞レースの新しいUIを構築するウィジェット ★★★
  Widget _buildMonthlyRacesPageView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ヘッダー (月表示とナビゲーション)
        _buildMonthSelectorHeader(),
        const SizedBox(height: 8),
        // PageView
        SizedBox(
          height: 400, // 高さを指定 (必要に応じて調整)
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

  // ★ ADD: 月選択ヘッダー
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

  // ★ ADD: 特定の月のレースリストを構築
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
          onTap: () {}, // タップしても何もしない
        );
      },
    );
  }
}
