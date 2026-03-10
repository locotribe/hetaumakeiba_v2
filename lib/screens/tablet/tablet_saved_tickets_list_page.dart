import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/ticket_repository.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/main.dart';
import 'package:hetaumakeiba_v2/screens/race_page.dart';
import 'package:hetaumakeiba_v2/models/ticket_list_item.dart';
import 'package:hetaumakeiba_v2/logic/ticket_aggregator.dart';
import 'package:hetaumakeiba_v2/logic/ticket_data_logic.dart';

class TabletSavedTicketsListPage extends StatefulWidget {
  const TabletSavedTicketsListPage({super.key});

  @override
  State<TabletSavedTicketsListPage> createState() => TabletSavedTicketsListPageState();
}

class TabletSavedTicketsListPageState extends State<TabletSavedTicketsListPage> {
  List<TicketListItem> _allTicketItems = [];
  List<TicketListItem> _filteredTicketItems = [];

  int? _selectedYear;
  int? _selectedMonth;
  Map<int, Set<int>> _monthsWithData = {};

  late PageController _pageController;
  static const int _initialPage = 10000;
  int _baseYear = DateTime.now().year;

  bool _isLoading = true;
  final TicketRepository _ticketRepository = TicketRepository();
  final TicketDataLogic _ticketLogic = TicketDataLogic();

  // ★追加：複数選択削除用の変数（IDはint型で保持）
  bool _isSelectionMode = false;
  final Set<int> _selectedTicketIds = {};

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
    reloadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> reloadData() async {
    if (!mounted) return;
    setState(() { _isLoading = true; });

    final userId = localUserId;
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
          print('日付の解析エラー: ${item.raceDate}');
        }
      }
    }
    _monthsWithData = newMonthsWithData;

    if (_allTicketItems.isNotEmpty) {
      if (_selectedYear == null || _selectedMonth == null) {
        final latestItem = _allTicketItems.first;
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左側 (30%): 年選択 ＋ 年次集計
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildYearSelector(),
                      _buildYearlySummaryPanel(),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // 右側 (70%): 月選択(1行) ＋ 月次集計バナー ＋ 購入履歴リスト
              Expanded(
                flex: 7,
                child: Column(
                  children: [
                    // 月選択エリアを中央寄せにし、右側エリア内での幅を70%に制限
                    Row(
                      children: [
                        const Spacer(flex: 1), // 左側の余白 (15%)
                        Expanded(
                          flex: 70, // 中央のコンテンツ (70%)
                          child: SizedBox(
                            height: 50, // ★左の年別タブと同じ高さに固定
                            child: _buildMonthSelector(),
                          ),
                        ),
                        const Spacer(flex: 1), // 右側の余白 (15%)
                      ],
                    ),
                    const SizedBox(height: 2), // ★間のスペースをほぼ無くして上にずらす
                    _buildMonthBanner(),
                    const SizedBox(height: 16),
                    // 下部エリア: 購入履歴リスト
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : (_filteredTicketItems.isEmpty
                          ? const Center(child: Text('この月の購入履歴はありません。', style: TextStyle(color: Colors.black54)))
                          : _buildTicketList()
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
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
              _filterTickets();
            });
          }
        },
        itemBuilder: (context, index) {
          final year = _baseYear + (index - _initialPage);
          final isSelected = (year == _selectedYear);

          return GestureDetector(
            onTap: () {
              if (!isSelected) {
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
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ★変更点: GridViewをやめ、RowとExpandedを使って確実に1列で高さを50にフィットさせる
  Widget _buildMonthSelector() {
    return Row(
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
            },
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border.all(
                  color: Colors.grey.shade300,
                  width: 0.5,
                ),
              ),
              child: Center(
                child: Text(
                  '$month月',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: fontWeight,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildMonthBanner() {
    if (_selectedMonth == null) return const SizedBox.shrink();

    final stats = TicketAggregator.calculateMonthlyStats(_filteredTicketItems);

    String formatMoney(int amount) {
      return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    }

    Widget buildStatRow(String label, String value) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)), // ★モバイル版に合わせて白系に変更
          const SizedBox(width: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)), // ★モバイル版に合わせて白系に変更
        ],
      );
    }

    final englishMonth = _englishMonths[_selectedMonth! - 1];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A4314), // ★変更: モバイル版と同じダークグリーンに修正
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1A4314)),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$_selectedMonth月',
                style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, height: 1.1), // ★白に変更
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white, // ★白背景に変更
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  englishMonth,
                  style: const TextStyle(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.bold), // ★黒に変更
                ),
              ),
            ],
          ),
          const Spacer(),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '購入 ¥${formatMoney(stats.totalPurchase)}',
                style: const TextStyle(color: Colors.white70, fontSize: 11), // ★白系に変更
              ),
              Text(
                '払戻 ¥${formatMoney(stats.totalPayout)}',
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), // ★白系に変更
              ),
              const SizedBox(height: 4),
              Container( // ★モバイル版に合わせて枠組みを追加
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: stats.balance >= 0 ? Colors.yellow : Colors.redAccent),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '収支 ${stats.balance >= 0 ? '+' : ''}¥${formatMoney(stats.balance)}',
                  style: TextStyle(
                    color: stats.balance >= 0 ? Colors.yellow : Colors.redAccent, // ★背景に合わせて見やすく変更
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTicketList() {
    final Map<String, List<TicketListItem>> groupedItems = {};
    for (final item in _filteredTicketItems) {
      groupedItems.putIfAbsent(item.raceId, () => []).add(item);
    }
    final List<List<TicketListItem>> groups = groupedItems.values.toList();

    return Column(
      children: [
        // 複数選択モード時のアクションバー (省略せずにそのまま配置)
        if (_isSelectionMode)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_selectedTicketIds.length} 件選択中', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                Row(
                  children: [
                    TextButton(onPressed: () => setState(() { _isSelectionMode = false; _selectedTicketIds.clear(); }), child: const Text('キャンセル')),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: _selectedTicketIds.isEmpty ? null : () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('一括削除'),
                            content: Text('選択した ${_selectedTicketIds.length} 件の馬券を削除しますか？'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('キャンセル')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('削除', style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final userId = localUserId;
                          if (userId != null) {
                            for (int id in _selectedTicketIds) {
                              await _ticketRepository.deleteQrData(id, userId);
                            }
                            setState(() { _isSelectionMode = false; _selectedTicketIds.clear(); });
                            reloadData();
                          }
                        }
                      },
                      child: const Text('削除実行'),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // メインのリスト部分
        Expanded(
          child: ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6.0),
                height: 145, // オーバーフロー対策
                child: Row(
                  children: [
                    // ★変更点: 左側（レース情報カード）を Expanded(flex: 3) に変更
                    Expanded(
                      flex: 3,
                      child: Dismissible(
                        key: ValueKey('group_${group.first.raceId}_$index'),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) async {
                          final userId = localUserId;
                          if (userId == null) return;
                          for (final item in group) {
                            if (item.qrData.id != null) await _ticketRepository.deleteQrData(item.qrData.id!, userId);
                          }
                          reloadData();
                        },
                        background: Container(decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)), alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete_sweep, color: Colors.white, size: 30)),
                        child: Card(
                          elevation: 3,
                          margin: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                          child: InkWell(
                            onTap: () async {
                              final siblingQrData = group.map((e) => e.qrData).toList();
                              await Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => RacePage(raceId: group.first.raceId, raceDate: group.first.raceDate, qrData: group.first.qrData),
                                settings: RouteSettings(arguments: {'siblingTickets': siblingQrData, 'initialIndex': 0}),
                              ));
                              reloadData();
                            },
                            child: Padding(padding: const EdgeInsets.all(12), child: _buildGroupHeader(group)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // ★変更点: 右側（馬券横スクロールリスト）を Expanded(flex: 7) に変更
                    Expanded(
                      flex: 7,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: group.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            final ticketId = item.qrData.id;
                            final isSelected = ticketId != null && _selectedTicketIds.contains(ticketId);

                            return Container(
                              width: 220, // 個別の馬券カード幅は維持
                              margin: const EdgeInsets.only(right: 8.0),
                              child: Card(
                                elevation: 2,
                                margin: EdgeInsets.zero,
                                color: isSelected ? Colors.blue.shade50 : ((item.hitResult?.isHit ?? false) ? Colors.red.shade50 : Colors.white),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: isSelected ? const BorderSide(color: Colors.blue, width: 2) : BorderSide.none,
                                ),
                                child: InkWell(
                                  onTap: () {
                                    if (_isSelectionMode && ticketId != null) {
                                      setState(() { isSelected ? _selectedTicketIds.remove(ticketId) : _selectedTicketIds.add(ticketId); });
                                    } else {
                                      Navigator.of(context).push(MaterialPageRoute(
                                        builder: (_) => RacePage(raceId: item.raceId, raceDate: item.raceDate, qrData: item.qrData),
                                        settings: RouteSettings(arguments: {'siblingTickets': group.map((e) => e.qrData).toList(), 'initialIndex': idx}),
                                      ));
                                    }
                                  },
                                  onLongPress: () {
                                    if (ticketId != null) setState(() { _isSelectionMode = true; _selectedTicketIds.add(ticketId); });
                                  },
                                  child: Stack(
                                    children: [
                                      Padding(padding: const EdgeInsets.all(12), child: _buildSingleTicketContent(item)),
                                      if (_isSelectionMode)
                                        Positioned(right: 4, top: 4, child: Icon(isSelected ? Icons.check_circle : Icons.radio_button_unchecked, color: isSelected ? Colors.blue : Colors.grey, size: 22)),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGroupHeader(List<TicketListItem> groupItems) {
    final firstItem = groupItems.first;
    final stats = TicketAggregator.calculateMonthlyStats(groupItems);
    String formatMoney(int amount) => amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(firstItem.displayTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${stats.totalCount}枚購入', style: const TextStyle(fontSize: 13, color: Colors.grey)),
            Text('${stats.balance >= 0 ? '+' : ''}${formatMoney(stats.balance)}円',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: stats.balance >= 0 ? Colors.blue.shade700 : Colors.red.shade700)),
          ],
        ),
        const SizedBox(height: 4),
        Text('累計購入: ${formatMoney(stats.totalPurchase)}円 / 累計払戻: ${formatMoney(stats.totalPayout)}円', style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );
  }

  Widget _buildSingleTicketContent(TicketListItem item) {
    final totalAmount = item.parsedTicket['合計金額'] as int? ?? 0;
    final isHit = item.hitResult?.isHit ?? false;
    final payout = item.hitResult?.totalPayout ?? 0;
    final refund = item.hitResult?.totalRefund ?? 0;
    final balance = (payout + refund) - totalAmount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(item.displaySubtitle, style: const TextStyle(fontSize: 12, color: Colors.black87)),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('購入 $totalAmount円', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54)),
            if (item.raceResult != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${payout + refund}円', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isHit ? Colors.green.shade700 : Colors.black)),
                  Text('${balance >= 0 ? '+' : ''}$balance円', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: balance > 0 ? Colors.blue.shade700 : (balance < 0 ? Colors.red.shade700 : Colors.black))),
                ],
              )
            else
              const Text('(未確定)', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  Widget _buildYearlySummaryPanel() {
    if (_selectedYear == null) return const SizedBox.shrink();

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

    int totalPurchase = 0;
    int totalPayout = 0;
    int totalTicketCount = yearlyItems.length;

    Map<String, int> racePurchaseMap = {};
    Map<String, int> racePayoutMap = {};
    Map<String, String> raceNameMap = {};
    Set<String> hitRaces = {};

    for (final item in yearlyItems) {
      final purchase = item.parsedTicket['合計金額'] as int? ?? 0;
      totalPurchase += purchase;

      racePurchaseMap[item.raceId] = (racePurchaseMap[item.raceId] ?? 0) + purchase;

      if (!raceNameMap.containsKey(item.raceId)) {
        raceNameMap[item.raceId] = item.displayTitle.isNotEmpty ? item.displayTitle : item.raceName;
      }

      if (item.raceResult != null) {
        final payout = (item.hitResult?.totalPayout ?? 0) + (item.hitResult?.totalRefund ?? 0);
        totalPayout += payout;

        racePayoutMap[item.raceId] = (racePayoutMap[item.raceId] ?? 0) + payout;

        if ((item.hitResult?.isHit ?? false) || (item.hitResult?.totalRefund ?? 0) > 0) {
          hitRaces.add(item.raceId);
        }
      }
    }

    int maxPayoutAmount = 0;
    String maxPayoutRaceName = '-';
    int maxProfitAmount = -999999999;
    String maxProfitRaceName = '-';
    bool hasProfitRace = false;

    for (final raceId in racePurchaseMap.keys) {
      final purchase = racePurchaseMap[raceId]!;
      final payout = racePayoutMap[raceId] ?? 0;
      final profit = payout - purchase;

      if (payout > maxPayoutAmount) {
        maxPayoutAmount = payout;
        maxPayoutRaceName = raceNameMap[raceId] ?? '-';
      }

      if (profit > 0 && profit > maxProfitAmount) {
        maxProfitAmount = profit;
        maxProfitRaceName = raceNameMap[raceId] ?? '-';
        hasProfitRace = true;
      }
    }

    final balance = totalPayout - totalPurchase;
    final balanceColor = balance >= 0 ? Colors.blue.shade700 : Colors.red.shade700;

    final purchaseRaceCount = racePurchaseMap.length;
    final hitRaceCount = hitRaces.length;
    final recoveryRate = totalPurchase > 0 ? (totalPayout / totalPurchase * 100) : 0.0;
    final hitRate = purchaseRaceCount > 0 ? (hitRaceCount / purchaseRaceCount * 100) : 0.0;

    final avgPurchase = purchaseRaceCount > 0 ? (totalPurchase / purchaseRaceCount).floor() : 0;

    String fmt(int val) => val.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    final labelStyle = TextStyle(color: Colors.grey.shade600, fontSize: 11);

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            // ★変更点: FittedBoxを追加し、はみ出す場合は自動で縮小させる
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                // ★変更点: FittedBox内ではspaceAroundが効かないため、centerに変更し手動で余白を設ける
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildEfficiencyItem('回収率', '${recoveryRate.toStringAsFixed(1)}%', recoveryRate >= 100),
                  const SizedBox(width: 16), // ★追加: 中央の線の左側の余白
                  Container(width: 1, height: 20, color: Colors.grey.shade300),
                  const SizedBox(width: 16), // ★追加: 中央の線の右側の余白
                  _buildEfficiencyItem('的中率', '${hitRate.toStringAsFixed(1)}%', false),
                ],
              ),
            ),
          ),
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
          color: isPositive ? Colors.red : Colors.black87,
        )),
      ],
    );
  }
}