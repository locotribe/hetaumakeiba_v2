// lib/screens/saved_tickets_list_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/main.dart';
import 'package:hetaumakeiba_v2/screens/race_page.dart';
import 'package:hetaumakeiba_v2/models/ticket_list_item.dart';
import 'package:hetaumakeiba_v2/logic/ticket_aggregator.dart';
import 'package:hetaumakeiba_v2/logic/ticket_data_logic.dart';

class SavedTicketsListPage extends StatefulWidget {
  const SavedTicketsListPage({super.key});

  @override
  State<SavedTicketsListPage> createState() => SavedTicketsListPageState();
}

class SavedTicketsListPageState extends State<SavedTicketsListPage> {
  List<TicketListItem> _allTicketItems = [];
  List<TicketListItem> _filteredTicketItems = [];

  bool _isYearSummaryExpanded = false;

  int? _selectedYear;
  int? _selectedMonth;
  Map<int, Set<int>> _monthsWithData = {};

  late PageController _pageController;
  static const int _initialPage = 10000;
  int _baseYear = DateTime.now().year;

  bool _isLoading = true;
  final DatabaseHelper _dbHelper = DatabaseHelper();
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
          print('日付の解析エラー: ${item.raceDate}');
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

  Future<void> _deleteAllData() async {
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
              _buildYearlySummaryPanel(),
              const SizedBox(height: 16),
              _buildMonthSelector(),
              const SizedBox(height: 16),
              _buildMonthBanner(),
              const SizedBox(height: 16),
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
              _isYearSummaryExpanded = false; // 年が変わったら閉じる（または維持でも可）
              _filterTickets();
            });
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

  Widget _buildMonthSelector() {
    return GridView.count(
      crossAxisCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 0,
      crossAxisSpacing: 0,
      childAspectRatio: 2.0,
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

        return GestureDetector(
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

    // Use TicketAggregator
    final stats = TicketAggregator.calculateMonthlyStats(_filteredTicketItems);

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
      child: Row(
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

    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];

        // グループ内のアイテム数が1つの場合は、そのままカードを表示
        if (group.length == 1) {
          // ★修正: グループ情報を渡す
          return _buildSingleTicketCard(group.first, groupItems: group, indexInGroup: 0);
        }

        // 複数枚ある場合はフォルダ（ExpansionTile）表示
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0),
          elevation: 2.0,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
            childrenPadding: EdgeInsets.zero,
            title: _buildGroupHeader(group),
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
          ),
        );
      },
    );
  }

  Widget _buildGroupHeader(List<TicketListItem> groupItems) {
    final firstItem = groupItems.first;
    final stats = TicketAggregator.calculateMonthlyStats(groupItems);

    // 金額フォーマット用
    String formatMoney(int amount) {
      return amount.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},');
    }

    Color balanceColor = stats.balance > 0 ? Colors.blue.shade700 : (stats.balance < 0 ? Colors.red.shade700 : Colors.black);
    if (stats.totalPayout == 0 && stats.balance < 0) balanceColor = Colors.red.shade700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          firstItem.displayTitle, // レース名
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${stats.totalCount}枚購入', style: const TextStyle(fontSize: 12, color: Colors.grey)),
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('購入: ${formatMoney(stats.totalPurchase)}円', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                    Text('払戻: ${formatMoney(stats.totalPayout)}円', style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(width: 8),
                Text(
                  '${stats.balance >= 0 ? '+' : ''}${formatMoney(stats.balance)}円',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: balanceColor),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

// 【修正箇所】_buildSingleTicketCard: 引数を追加し、onTap時の遷移ロジックを変更
  Widget _buildSingleTicketCard(TicketListItem item, {bool isGroupChild = false, List<TicketListItem>? groupItems, int indexInGroup = 0}) {
    final totalAmount = item.parsedTicket['合計金額'] as int? ?? 0;
    final isHit = item.hitResult?.isHit ?? false;
    final payout = item.hitResult?.totalPayout ?? 0;
    final refund = item.hitResult?.totalRefund ?? 0;
    final balance = (payout + refund) - totalAmount;

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
        final userId = localUserId;
        if (userId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('エラー: ログイン状態を確認できませんでした。')),
            );
            reloadData();
          }
          return;
        }
        await _dbHelper.deleteQrData(item.qrData.id!, userId);
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
        margin: isGroupChild ? EdgeInsets.zero : const EdgeInsets.symmetric(vertical: 8.0),
        color: isHit ? Colors.red.shade50 : (isGroupChild ? Colors.transparent : null),
        shape: isGroupChild ? const RoundedRectangleBorder(borderRadius: BorderRadius.zero) : null,
        child: ListTile(
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
          onTap: () async {
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
          },
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