// lib/screens/saved_tickets_list_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/ticket_repository.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/services/user_session.dart';
import 'package:hetaumakeiba_v2/screens/race_page.dart';
import 'package:hetaumakeiba_v2/models/ticket_list_item.dart';
import 'package:hetaumakeiba_v2/logic/ticket_aggregator.dart';
import 'package:hetaumakeiba_v2/logic/ticket_data_logic.dart';
import 'package:hetaumakeiba_v2/screens/qr_scanner_page.dart';
import 'package:hetaumakeiba_v2/screens/gallery_qr_scanner_page.dart';

class SavedTicketsListPage extends StatefulWidget {
  const SavedTicketsListPage({super.key});

  @override
  State<SavedTicketsListPage> createState() => SavedTicketsListPageState();
}

class SavedTicketsListPageState extends State<SavedTicketsListPage> {
  List<TicketListItem> _allTicketItems = [];
  List<TicketListItem> _filteredTicketItems = [];

  bool _isYearSummaryExpanded = false;
  bool _isMonthTypeStatsExpanded = false;

  // [追加] 1つにまとめたスクロールの制御と、縮んだ月サマリーを出すかの判定 (v.2026.11.23+26112301)
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollAreaKey = GlobalKey();
  final GlobalKey _monthBannerKey = GlobalKey();
  bool _showCompactMonthSummary = false;
  final Set<String> _expandedRaceIds = {}; // [追加] 展開しているレース（複数枚のレースのカード） (v.2026.11.23+26112301)
  static const double _monthHeaderHeight = 48.0;
  static const Color _pageBackgroundColor = Color.fromRGBO(231, 234, 234, 1.0);

  int? _selectedYear;
  int? _selectedMonth;
  Map<int, Set<int>> _monthsWithData = {};

  late PageController _pageController;
  static const int _initialPage = 10000;
  int _baseYear = DateTime.now().year;

  bool _isLoading = true;
  final TicketRepository _ticketRepository = TicketRepository();
  final TicketDataLogic _ticketLogic = TicketDataLogic();

  static const List<String> _englishMonths = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _initialPage,
      viewportFraction: 0.33,
    );
    _scrollController.addListener(_onScroll); // [追加] 縮んだ月サマリーの表示判定 (v.2026.11.23+26112301)
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.removeListener(_onScroll); // [追加] (v.2026.11.23+26112301)
    _scrollController.dispose(); // [追加] (v.2026.11.23+26112301)
    super.dispose();
  }

  // [追加] 月バナーの下端が固定した月セレクタの下まで流れたら、縮んだ月サマリーを出す (v.2026.11.23+26112301)
  void _onScroll() {
    bool show = false;
    final bannerObject = _monthBannerKey.currentContext?.findRenderObject();
    final areaObject = _scrollAreaKey.currentContext?.findRenderObject();
    if (bannerObject is RenderBox && areaObject is RenderBox && bannerObject.attached && bannerObject.hasSize) {
      final bannerBottom = bannerObject
          .localToGlobal(Offset(0, bannerObject.size.height), ancestor: areaObject)
          .dy;
      show = bannerBottom <= _monthHeaderHeight;
    }
    if (show != _showCompactMonthSummary) {
      setState(() {
        _showCompactMonthSummary = show;
      });
    }
  }

  // [追加] 年・月を切り替えたら一番上へ戻す (v.2026.11.23+26112301)
  void _resetScrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    setState(() {
      _showCompactMonthSummary = false;
      _expandedRaceIds.clear();
    });
  }

  // [追加] 月バナーのカメラ・画像ボタンから、ニュースページのボタンと同じ取り込み画面を開く (v.2026.11.23+26112301)
  void _openTicketImport({required bool fromGallery}) {
    final key = widget.key;
    if (key is! GlobalKey<SavedTicketsListPageState>) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => fromGallery
            ? GalleryQrScannerPage(savedListKey: key)
            : QRScannerPage(savedListKey: key),
      ),
    );
  }

  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    final userId = UserSession().localUserId;
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _allTicketItems = [];
        _filteredTicketItems = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ユーザー情報の取得に失敗しました。')),
      );
      return;
    }

    final finalItems = await _ticketLogic.fetchAndProcessTickets(userId);

    _allTicketItems = finalItems;

    final newMonthsWithData = <int, Set<int>>{};
    for (final item in _allTicketItems) {
      // 修正: item.raceResult?.raceDate ではなく item.raceDate を使用
      if (item.raceDate.isNotEmpty) {
        try {
          final dateParts = item.raceDate.split(RegExp(r'[年月日]'));
          final year = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          if (newMonthsWithData.containsKey(year)) {
            newMonthsWithData[year]!.add(month);
          } else {
            newMonthsWithData[year] = {month};
          }
        } catch (e) {
          debugPrint('日付の解析エラー: ${item.raceDate}');
        }
      }
    }
    _monthsWithData = newMonthsWithData;

    if (_allTicketItems.isNotEmpty) {
      if (_selectedYear == null || _selectedMonth == null) {
        final latestItem = _allTicketItems.first;
        // 修正: item.raceResult への依存を排除
        if(latestItem.raceDate.isNotEmpty) {
          try {
            final dateParts = latestItem.raceDate.split(RegExp(r'[年月日]'));
            _selectedYear = int.parse(dateParts[0]);
            _selectedMonth = int.parse(dateParts[1]);
            _baseYear = DateTime.now().year;
            final targetPage = _initialPage + (_selectedYear! - _baseYear);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_pageController.hasClients) {
                _pageController.jumpToPage(targetPage);
              }
            });
          } catch (e) {
            _selectedYear = DateTime.now().year;
            _selectedMonth = DateTime.now().month;
          }
        } else {
          _selectedYear = DateTime.now().year;
          _selectedMonth = DateTime.now().month;
        }
      }
    } else {
      _selectedYear = DateTime.now().year;
      _selectedMonth = DateTime.now().month;
    }

    _filterTickets();
    setState(() { _isLoading = false; });
  }

  void _filterTickets() {
    if (_selectedYear == null || _selectedMonth == null) {
      setState(() { _filteredTicketItems = []; });
      return;
    }
    setState(() {
      _filteredTicketItems = _allTicketItems.where((item) {
        // 修正: raceResultのチェックではなく、raceDateのチェックに変更
        if (item.raceDate.isEmpty) return false;
        try {
          final dateParts = item.raceDate.split(RegExp(r'[年月日]'));
          final year = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          return year == _selectedYear && month == _selectedMonth;
        } catch (e) {
          return false;
        }
      }).toList();
    });
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Column(
            children: [
              _buildYearSelector(),
              // [修正] 年間サマリー・月セレクタ・月バナー・レース一覧を1つのスクロールにまとめた (v.2026.11.23+26112301)
              Expanded(child: _buildScrollBody()),
            ],
          ),
        ),
      ],
    );
  }

  // [追加] 1つにまとめたスクロール。月セレクタは上に固定し、月バナーが流れたら縮んだ月サマリーを重ねて出す (v.2026.11.23+26112301)
  Widget _buildScrollBody() {
    return Stack(
      key: _scrollAreaKey,
      fit: StackFit.expand,
      children: [
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverToBoxAdapter(child: _buildYearlySummaryPanel()),
            SliverPersistentHeader(
              pinned: true,
              delegate: _MonthSelectorHeaderDelegate(
                height: _monthHeaderHeight,
                backgroundColor: _pageBackgroundColor,
                child: _buildMonthSelector(),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                key: _monthBannerKey,
                child: _buildMonthBanner(),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            if (_isLoading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_filteredTicketItems.isEmpty)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text('この月の購入履歴はありません。', style: TextStyle(color: Colors.black54))),
              )
            else
              _buildTicketList(),
          ],
        ),
        if (_showCompactMonthSummary)
          Positioned(
            top: _monthHeaderHeight,
            left: 0,
            right: 0,
            child: _buildCompactMonthSummary(),
          ),
      ],
    );
  }

  Widget _buildTypeStatsTable(Map<String, BettingTypeStats> typeStats) {
    const typeOrder = ['単勝', '複勝', '枠連', '馬連', 'ワイド', '馬単', '3連複', '3連単'];
    String fmt(int v) => v.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

    final ordered = [
      ...typeOrder.where((t) => typeStats.containsKey(t)),
      ...typeStats.keys.where((t) => !typeOrder.contains(t)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          dataRowMinHeight: 28,
          dataRowMaxHeight: 28,
          headingRowHeight: 28,
          columnSpacing: 12,
          columns: const [
            DataColumn(label: Text('券種', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
            DataColumn(label: Text('枚数', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: Text('購入金額', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: Text('払戻', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: Text('的中率', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), numeric: true),
            DataColumn(label: Text('回収率', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), numeric: true),
          ],
          rows: ordered.map((name) {
            final s = typeStats[name]!;
            final hitRateStr = s.purchaseCount > 0
                ? '${(s.hitCount / s.purchaseCount * 100).toStringAsFixed(1)}%'
                : '-';
            final recoveryRateStr = s.purchaseAmount > 0
                ? '${(s.payoutAmount / s.purchaseAmount * 100).toStringAsFixed(1)}%'
                : '-';
            final payoutColor = s.payoutAmount > s.purchaseAmount
                ? const Color(0xFF1A4314)
                : Colors.black87;
            return DataRow(cells: [
              DataCell(Text(name, style: const TextStyle(fontSize: 11))),
              DataCell(Text('${s.purchaseCount}', style: const TextStyle(fontSize: 11))),
              DataCell(Text('¥${fmt(s.purchaseAmount)}', style: const TextStyle(fontSize: 11))),
              DataCell(Text(
                s.payoutAmount > 0 ? '¥${fmt(s.payoutAmount)}' : '-',
                style: TextStyle(fontSize: 11, color: s.payoutAmount > 0 ? payoutColor : Colors.black38),
              )),
              DataCell(Text(hitRateStr, style: const TextStyle(fontSize: 11))),
              DataCell(Text(recoveryRateStr, style: const TextStyle(fontSize: 11))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildYearSelector() {
    const activeColor = Color(0xFF1A4314);

    return SizedBox(
      height: 50,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: (int page) {
          final newYear = _baseYear + (page - _initialPage);
          if (newYear != _selectedYear) {
            setState(() {
              _selectedYear = newYear;
              _isYearSummaryExpanded = false;
              _filterTickets();
            });
            _resetScrollToTop(); // [追加] (v.2026.11.23+26112301)
          }
        },
        itemBuilder: (context, index) {
          final year = _baseYear + (index - _initialPage);
          final isSelected = (year == _selectedYear);

          return GestureDetector(
            // ★追加: 選択中の年をタップでパネル開閉
            onTap: () {
              if (isSelected) {
                setState(() {
                  _isYearSummaryExpanded = !_isYearSummaryExpanded;
                });
                // [追加] 年間サマリーを開いたときは一番上へ戻して見えるようにする (v.2026.11.23+26112301)
                if (_isYearSummaryExpanded && _scrollController.hasClients) {
                  _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              } else {
                // 選択されていない年をタップした場合はその年に移動
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
              decoration: BoxDecoration(
                color: isSelected ? activeColor : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.5),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ] : [],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$year年',
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  // ★追加: 開閉を示すアイコン（選択中のみ表示）
                  if (isSelected) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _isYearSummaryExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.white,
                      size: 16,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // [修正] 月セレクタを12か月の1行に変更（色分けは従来どおり） (v.2026.11.23+26112301)
  Widget _buildMonthSelector() {
    return Container(
      height: 36,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: List.generate(12, (index) {
          final month = index + 1;
          final isSelected = month == _selectedMonth;
          final hasData = _monthsWithData[_selectedYear]?.contains(month) ?? false;

          Color backgroundColor;
          Color textColor;
          FontWeight fontWeight;

          if (isSelected) {
            backgroundColor = Colors.grey.shade700;
            textColor = Colors.white;
            fontWeight = FontWeight.bold;
          } else if (hasData) {
            backgroundColor = Colors.green.shade100;
            textColor = Colors.green.shade900;
            fontWeight = FontWeight.w600;
          } else {
            backgroundColor = Colors.white;
            textColor = Colors.black87;
            fontWeight = FontWeight.normal;
          }

          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedMonth = month;
                  _filterTickets();
                });
                _resetScrollToTop();
              },
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  border: index == 0
                      ? null
                      : Border(left: BorderSide(color: Colors.grey.shade300, width: 0.5)),
                ),
                child: Text(
                  '$month',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: fontWeight,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMonthBanner() {
    if (_selectedMonth == null) return const SizedBox.shrink();

    // Use TicketAggregator
    final stats = TicketAggregator.calculateMonthlyStats(_filteredTicketItems);
    final typeStats = TicketAggregator.calculateTypeStats(_filteredTicketItems);

    // 金額フォーマット用ヘルパー
    String formatMoney(int amount) {
      return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    }

    // 統計行表示用ヘルパー
    Widget buildStatRow(String label, String value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      );
    }

    final englishMonth = _englishMonths[_selectedMonth! - 1];

    // [修正] 月の集計の行（従来のバナーの中身そのまま） (v.2026.11.23+26112301)
    final summaryRow = Row(
        children: [
          // 左カラム：月表示
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_selectedMonth月',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, height: 1.1),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  englishMonth,
                  style: const TextStyle(color: Color(0xFF1A4314), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),

          const Spacer(),

          // 中央カラム：枚数・的中率（縦並び）
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              buildStatRow('購入', '${stats.totalCount}枚'),
              buildStatRow('的中', '${stats.hitCount}枚'),
              buildStatRow('的中率', '${stats.hitRate.toStringAsFixed(1)}%'),
            ],
          ),

          const SizedBox(width: 16),

          // 右カラム：金額・収支（縦並び）
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '購入 ¥${formatMoney(stats.totalPurchase)}',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
              Text(
                '払戻 ¥${formatMoney(stats.totalPayout)}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: stats.balance >= 0 ? Colors.white.withOpacity(0.1) : Colors.red.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                      color: stats.balance >= 0 ? Colors.yellowAccent : Colors.white30,
                      width: 0.5
                  ),
                ),
                child: Text(
                  '${stats.balance >= 0 ? '+' : ''}¥${formatMoney(stats.balance)}',
                  style: TextStyle(
                    color: stats.balance >= 0 ? Colors.yellowAccent : Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
    );

    // [修正] 馬券取り込みボタンと券種別の開閉ボタンを月バナーの中の下の行へ入れ、券種別の表もバナーの中に出す (v.2026.11.23+26112301)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A4314),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A4314), Color(0xFF2E6331)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          summaryRow,
          _buildBannerActionRow(typeStats.isNotEmpty),
          if (_isMonthTypeStatsExpanded && typeStats.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: _buildTypeStatsTable(typeStats),
            ),
        ],
      ),
    );
  }

  // [追加] 月バナーの下の行：馬券アイコン・カメラ・画像のボタン（左）と券種別の開閉（右） (v.2026.11.23+26112301)
  Widget _buildBannerActionRow(bool hasTypeStats) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/icon_baken.png',
            width: 34,
            height: 28,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 12),
          _buildImportIconButton(
            icon: Icons.camera_alt,
            semanticLabel: 'カメラで読み取る',
            onTap: () => _openTicketImport(fromGallery: false),
          ),
          const SizedBox(width: 12),
          _buildImportIconButton(
            icon: Icons.image,
            semanticLabel: '画像から読み取る',
            onTap: () => _openTicketImport(fromGallery: true),
          ),
          const Spacer(),
          if (hasTypeStats)
            GestureDetector(
              onTap: () => setState(() => _isMonthTypeStatsExpanded = !_isMonthTypeStatsExpanded),
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 3, 6, 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('券種別', style: TextStyle(fontSize: 11, color: Colors.white)),
                    Icon(
                      _isMonthTypeStatsExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 16,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // [追加] 線で囲んだアイコンだけの取り込みボタン (v.2026.11.23+26112301)
  Widget _buildImportIconButton({
    required IconData icon,
    required String semanticLabel,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: Colors.white.withValues(alpha: 0.08),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
        ),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 28,
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }

  // [追加] 月バナーが流れた後に月セレクタの下へ重ねる、1行の月サマリー (v.2026.11.23+26112301)
  Widget _buildCompactMonthSummary() {
    if (_selectedMonth == null) return const SizedBox.shrink();

    final stats = TicketAggregator.calculateMonthlyStats(_filteredTicketItems);

    String formatMoney(int amount) {
      return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    }

    return Container(
      color: _pageBackgroundColor,
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A4314),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(
              '$_selectedMonth月',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 10),
            Text(
              '購入 ¥${formatMoney(stats.totalPurchase)}',
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(width: 10),
            Text(
              '払戻 ¥${formatMoney(stats.totalPayout)}',
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: stats.balance >= 0 ? Colors.white.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
                border: Border.all(
                    color: stats.balance >= 0 ? Colors.yellowAccent : Colors.white30,
                    width: 0.5
                ),
              ),
              child: Text(
                '${stats.balance >= 0 ? '+' : ''}¥${formatMoney(stats.balance)}',
                style: TextStyle(
                  color: stats.balance >= 0 ? Colors.yellowAccent : Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// 【修正箇所】_buildTicketList: グループ情報を各カード生成メソッドに渡すように変更
  Widget _buildTicketList() {
    // レースIDごとにグループ化
    final Map<String, List<TicketListItem>> groupedItems = {};
    for (final item in _filteredTicketItems) {
      if (groupedItems.containsKey(item.raceId)) {
        groupedItems[item.raceId]!.add(item);
      } else {
        groupedItems[item.raceId] = [item];
      }
    }

    // グループ（レース）のリストを作成
    final List<List<TicketListItem>> groups = groupedItems.values.toList();

    // [修正] 1つにまとめたスクロールの中に入れるため ListView から SliverList に変更 (v.2026.11.23+26112301)
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final group = groups[index];

          // グループ内のアイテム数が1つの場合は、そのままカードを表示
          if (group.length == 1) {
            // ★修正: グループ情報を渡す
            return _buildSingleTicketCard(group.first, groupItems: group, indexInGroup: 0);
          }

          // 複数枚ある場合はフォルダ（ExpansionTile）表示
          // [修正] 右端に枚数と▼の帯を出すため、ExpansionTile をやめて同じ開閉を自前で行う (v.2026.11.23+26112301)
          final raceId = group.first.raceId;
          final isExpanded = _expandedRaceIds.contains(raceId);
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            elevation: 2.0,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedRaceIds.remove(raceId);
                      } else {
                        _expandedRaceIds.add(raceId);
                      }
                    });
                  },
                  child: _buildGroupHeader(group, isExpanded: isExpanded),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  child: isExpanded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          // ★修正: mapのindexを使ってグループ内位置を特定
                          children: group.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            return Container(
                              decoration: BoxDecoration(
                                border: Border(top: BorderSide(color: Colors.grey.shade200)),
                                color: Colors.grey.shade50, // 階層を深く見せるための背景色
                              ),
                              padding: const EdgeInsets.only(left: 16.0), // インデント
                              // ★修正: グループ情報とインデックスを渡す
                              child: _buildSingleTicketCard(item, isGroupChild: true, groupItems: group, indexInGroup: idx),
                            );
                          }).toList(),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ],
            ),
          );
        },
        childCount: groups.length,
      ),
    );
  }

  // [修正] レースのカード：左に2行（1行目＝レース名だけ／2行目＝購入・払戻・収支をそろえて左寄せ）、右端にうすい緑の帯（枚数と▼）。1枚だけのレースのカードでも使う (v.2026.11.23+26112301)
  Widget _buildGroupHeader(
    List<TicketListItem> groupItems, {
    bool isConfirmed = true,
    bool showArrow = true,
    bool isExpanded = false,
  }) {
    final firstItem = groupItems.first;
    final stats = TicketAggregator.calculateMonthlyStats(groupItems);

    // 金額フォーマット用
    String formatMoney(int amount) {
      return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    }

    Color balanceColor = stats.balance > 0 ? Colors.blue.shade700 : (stats.balance < 0 ? Colors.red.shade700 : Colors.black);
    if (stats.totalPayout == 0 && stats.balance < 0) balanceColor = Colors.red.shade700;

    // 「ラベル 金額」の1項目。3項目を同じ幅に並べ、それぞれ左寄せにする
    Widget buildAmountField(String label, String value, TextStyle valueStyle) {
      return Expanded(
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)),
                const SizedBox(width: 4),
                Text(value, style: valueStyle),
              ],
            ),
          ),
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    firstItem.displayTitle, // レース名
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      buildAmountField(
                        '購入',
                        formatMoney(stats.totalPurchase),
                        const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                      buildAmountField(
                        '払戻',
                        isConfirmed ? formatMoney(stats.totalPayout) : '未確定',
                        isConfirmed
                            ? const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold)
                            : const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      buildAmountField(
                        '収支',
                        isConfirmed ? '${stats.balance >= 0 ? '+' : ''}${formatMoney(stats.balance)}円' : '-',
                        isConfirmed
                            ? TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: balanceColor)
                            : const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 40,
            color: Colors.green.shade100.withValues(alpha: 0.7),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${stats.totalCount}枚',
                  style: TextStyle(fontSize: 11, color: Colors.green.shade900, fontWeight: FontWeight.w600),
                ),
                if (showArrow)
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.expand_more, size: 22, color: Colors.green.shade900),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// 【修正箇所】_buildSingleTicketCard: 引数を追加し、onTap時の遷移ロジックを変更
  Widget _buildSingleTicketCard(TicketListItem item, {bool isGroupChild = false, List<TicketListItem>? groupItems, int indexInGroup = 0}) {
    final totalAmount = item.parsedTicket['合計金額'] as int? ?? 0;
    final isHit = item.hitResult?.isHit ?? false;
    final payout = item.hitResult?.totalPayout ?? 0;
    final refund = item.hitResult?.totalRefund ?? 0;
    final balance = (payout + refund) - totalAmount;

    // [修正] レース画面へ移る処理（従来の ListTile の onTap の中身）を、1枚だけのレースのカードと共用するため関数にした (v.2026.11.23+26112301)
    Future<void> openRacePage() async {
      if (item.raceDate.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('レースの日付情報がありません。')),
        );
        return;
      }

      // ★修正: 遷移時に兄弟チケット情報をRouteSettings経由で渡す
      // RacePageのコンストラクタを変更せずにデータを渡すためのテクニック
      final siblingQrData = groupItems?.map((e) => e.qrData).toList() ?? [item.qrData];
      final args = {
        'siblingTickets': siblingQrData,
        'initialIndex': indexInGroup,
      };

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RacePage(
            raceId: item.raceId,
            raceDate: item.raceDate,
            qrData: item.qrData,
          ),
          settings: RouteSettings(arguments: args), // 引数として渡す
        ),
      );
      reloadData();
    }

    return Dismissible(
      key: ValueKey(item.qrData.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('削除の確認'),
              content: const Text('この項目を本当に削除しますか？'),
              actions: <Widget>[
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('キャンセル')),
                TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('削除', style: TextStyle(color: Colors.red))),
              ],
            );
          },
        ) ?? false;
      },
      onDismissed: (direction) async {
        final userId = UserSession().localUserId;
        if (userId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('エラー: ログイン状態を確認できませんでした。')),
            );
            reloadData();
          }
          return;
        }
        await _ticketRepository.deleteQrData(item.qrData.id!, userId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('削除しました')));
          reloadData(); // データを再読み込みしてグループ構造を更新
        }
      },
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        // グループ内アイテムの場合はCardの影やマージンを消してリストっぽくする
        elevation: isGroupChild ? 0 : 2.0,
        margin: isGroupChild ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 4.0), // [修正] グループのカードと同じ間隔に (v.2026.11.23+26112301)
        color: isHit ? Colors.red.shade50 : (isGroupChild ? Colors.transparent : null),
        shape: isGroupChild ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero) : null,
        clipBehavior: Clip.antiAlias, // [追加] 右端の帯を角丸の内側に収める (v.2026.11.23+26112301)
        // [修正] 1枚だけのレースのカードは複数枚のレースと同じ形（右端の帯は枚数だけ）。グループ内の馬券の行は従来どおり (v.2026.11.23+26112301)
        child: isGroupChild ? ListTile(
          contentPadding: isGroupChild ? const EdgeInsets.fromLTRB(0, 8, 16, 8) : null,
          isThreeLine: true,
          title: isGroupChild ? null : Text(item.displayTitle, style: const TextStyle(fontWeight: FontWeight.bold)), // グループ内ならタイトル非表示
          subtitle: Text(item.displaySubtitle),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$totalAmount円', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54, height: 1.2)),
              if (item.raceResult != null) ...[
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontFamily: Theme.of(context).textTheme.bodyLarge?.fontFamily),
                    children: <TextSpan>[
                      TextSpan(text: '${payout + refund}円', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isHit ? Colors.green.shade700 : Colors.black, height: 1.2)),
                      if (refund > 0)
                        TextSpan(text: ' (返$refund)', style: const TextStyle(fontSize: 11, color: Colors.black54, height: 1.1)),
                    ],
                  ),
                ),
                Text('${balance >= 0 ? '+' : ''}$balance円', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: balance > 0 ? Colors.blue.shade700 : (balance < 0 ? Colors.red.shade700 : Colors.black), height: 1.2)),
              ] else
                const Text(' (未確定)', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          onTap: openRacePage,
        ) : InkWell(
          onTap: openRacePage,
          child: _buildGroupHeader([item], isConfirmed: item.raceResult != null, showArrow: false),
        ),
      ),
    );
  }

// ★修正: 年次集計パネル（アイコンなし・項目順序修正版）
  Widget _buildYearlySummaryPanel() {
    if (!_isYearSummaryExpanded || _selectedYear == null) return const SizedBox.shrink();

    // 1. データ集計
    final yearlyItems = _allTicketItems.where((item) {
      if (item.raceDate.isEmpty) return false;
      try {
        final dateParts = item.raceDate.split(RegExp(r'[年月日]'));
        final year = int.parse(dateParts[0]);
        return year == _selectedYear;
      } catch (e) {
        return false;
      }
    }).toList();

    if (yearlyItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        color: Colors.white70,
        child: const Text('データがありません', textAlign: TextAlign.center),
      );
    }

    final typeStats = TicketAggregator.calculateTypeStats(yearlyItems);

    // 変数初期化
    int totalPurchase = 0;
    int totalPayout = 0;
    int totalTicketCount = yearlyItems.length;

    // レース単位集計用マップ
    Map<String, int> racePurchaseMap = {};
    Map<String, int> racePayoutMap = {};
    Map<String, String> raceNameMap = {};
    Set<String> hitRaces = {};

    for (final item in yearlyItems) {
      final purchase = item.parsedTicket['合計金額'] as int? ?? 0;
      totalPurchase += purchase;

      // レース毎の購入額加算
      racePurchaseMap[item.raceId] = (racePurchaseMap[item.raceId] ?? 0) + purchase;

      // レース名保持
      if (!raceNameMap.containsKey(item.raceId)) {
        raceNameMap[item.raceId] = item.displayTitle.isNotEmpty ? item.displayTitle : item.raceName;
      }

      if (item.raceResult != null) {
        final payout = (item.hitResult?.totalPayout ?? 0) + (item.hitResult?.totalRefund ?? 0);
        totalPayout += payout;

        // レース毎の払戻額加算
        racePayoutMap[item.raceId] = (racePayoutMap[item.raceId] ?? 0) + payout;

        // 的中レース判定
        if ((item.hitResult?.isHit ?? false) || (item.hitResult?.totalRefund ?? 0) > 0) {
          hitRaces.add(item.raceId);
        }
      }
    }

    // レース単位での最大値算出
    int maxPayoutAmount = 0;
    String maxPayoutRaceName = '-';
    int maxProfitAmount = -999999999;
    String maxProfitRaceName = '-';
    bool hasProfitRace = false;

    for (final raceId in racePurchaseMap.keys) {
      final purchase = racePurchaseMap[raceId]!;
      final payout = racePayoutMap[raceId] ?? 0;
      final profit = payout - purchase;

      // 最高払戻
      if (payout > maxPayoutAmount) {
        maxPayoutAmount = payout;
        maxPayoutRaceName = raceNameMap[raceId] ?? '-';
      }

      // 最高プラス収支 (利益が出ていて最大のもの)
      if (profit > 0 && profit > maxProfitAmount) {
        maxProfitAmount = profit;
        maxProfitRaceName = raceNameMap[raceId] ?? '-';
        hasProfitRace = true;
      }
    }

    final balance = totalPayout - totalPurchase;
    final balanceColor = balance >= 0 ? Colors.blue.shade700 : Colors.red.shade700;

    // 効率指標
    final purchaseRaceCount = racePurchaseMap.length;
    final hitRaceCount = hitRaces.length;
    final recoveryRate = totalPurchase > 0 ? (totalPayout / totalPurchase * 100) : 0.0;
    final hitRate = purchaseRaceCount > 0 ? (hitRaceCount / purchaseRaceCount * 100) : 0.0;

    // 平均購入額
    final avgPurchase = purchaseRaceCount > 0 ? (totalPurchase / purchaseRaceCount).floor() : 0;

    // ヘルパー関数
    String fmt(int val) => val.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    final labelStyle = TextStyle(color: Colors.grey.shade600, fontSize: 11);

    // 2. UI構築
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // 【上段：メイン指標】
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('年間収支', style: labelStyle),
                    Text('${balance >= 0 ? '+' : ''}¥${fmt(balance)}',
                        style: TextStyle(color: balanceColor, fontWeight: FontWeight.bold, fontSize: 20)),
                  ],
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('購入:', style: labelStyle),
                        Text('¥${fmt(totalPurchase)}', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('払戻:', style: labelStyle),
                        Text('¥${fmt(totalPayout)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 16),

          // 【中段1：最高払戻】(元の行)
          if (maxPayoutAmount > 0) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)),
                  child: Text('最高払戻', style: TextStyle(fontSize: 10, color: Colors.grey.shade800, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(maxPayoutRaceName, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))),
                Text('¥${fmt(maxPayoutAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
              ],
            ),
            const SizedBox(height: 8),
          ],

          // 【中段2：基本データ】(元の行)
          Row(
            children: [
              _buildSummaryItem('購入レース数', '$purchaseRaceCount', 'R'),
              const Spacer(),
              Container(width: 1, height: 20, color: Colors.grey.shade300),
              const Spacer(),
              _buildSummaryItem('馬券購入枚数', '$totalTicketCount', '枚'),
            ],
          ),
          const SizedBox(height: 8),

          // 【中段3：今回追加 (平均購入額・最高プラス収支)】
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 平均購入額
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('平均購入額', style: labelStyle),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('¥${fmt(avgPurchase)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        Text('/R', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                      ],
                    ),
                  ],
                ),
              ),
              // 最高プラス収支
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('最高プラス収支', style: labelStyle),
                    if (hasProfitRace) ...[
                      Text(maxProfitRaceName,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11)),
                      Text('+¥${fmt(maxProfitAmount)}',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue.shade700)),
                    ] else
                      const Text('-', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 【下段：効率指標】
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildEfficiencyItem('回収率', '${recoveryRate.toStringAsFixed(1)}%', recoveryRate >= 100),
                Container(width: 1, height: 20, color: Colors.grey.shade300),
                _buildEfficiencyItem('的中率', '${hitRate.toStringAsFixed(1)}%', false),
              ],
            ),
          ),
          if (typeStats.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '券種別集計',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 4),
            _buildTypeStatsTable(typeStats),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            Text(unit, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Widget _buildEfficiencyItem(String label, String value, bool isPositive) {
    return Row(
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(width: 8),
        Text(value, style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isPositive ? Colors.red : Colors.black87, // 競馬では回収率100%超えは赤字で強調することが多い
        )),
      ],
    );
  }
}

// [追加] 月セレクタを上に固定するためのヘッダー (v.2026.11.23+26112301)
class _MonthSelectorHeaderDelegate extends SliverPersistentHeaderDelegate {
  _MonthSelectorHeaderDelegate({
    required this.height,
    required this.backgroundColor,
    required this.child,
  });

  final double height;
  final Color backgroundColor;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant _MonthSelectorHeaderDelegate oldDelegate) => true;
}
