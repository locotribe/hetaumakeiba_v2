// lib/screens/saved_tickets_list_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/hit_checker.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/screens/race_result_page.dart';
import 'package:hetaumakeiba_v2/services/race_result_scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:hetaumakeiba_v2/main.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
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

    final userId = localUserId; // FirebaseAuthからlocalUserIdに変更
    if (userId == null) {
      setState(() {
        _isLoading = false;
        _allTicketItems = [];
        _filteredTicketItems = [];
      });
      // オプション：ユーザーにエラーメッセージを表示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ユーザー情報の取得に失敗しました。')),
      );
      return;
    }

    final finalItems = await _ticketLogic.fetchAndProcessTickets(userId);

    _allTicketItems = finalItems;

    final newMonthsWithData = <int, Set<int>>{};
    for (final item in _allTicketItems) {
      if (item.raceResult?.raceDate != null && item.raceResult!.raceDate.isNotEmpty) {
        try {
          final dateParts = item.raceResult!.raceDate.split(RegExp(r'[年月日]'));
          final year = int.parse(dateParts[0]);
          final month = int.parse(dateParts[1]);
          if (newMonthsWithData.containsKey(year)) {
            newMonthsWithData[year]!.add(month);
          } else {
            newMonthsWithData[year] = {month};
          }
        } catch (e) {
          print('日付の解析エラー: ${item.raceResult!.raceDate}');
        }
      }
    }
    _monthsWithData = newMonthsWithData;

    if (_allTicketItems.isNotEmpty) {
      if (_selectedYear == null || _selectedMonth == null) {
        final latestItem = _allTicketItems.first;
        if(latestItem.raceResult != null && latestItem.raceResult!.raceDate.isNotEmpty) {
          try {
            final dateParts = latestItem.raceResult!.raceDate.split(RegExp(r'[年月日]'));
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
        if (item.raceResult == null || item.raceResult!.raceDate.isEmpty) return false;
        try {
          final dateParts = item.raceResult!.raceDate.split(RegExp(r'[年月日]'));
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
              _filterTickets();
            });
          }
        },
        itemBuilder: (context, index) {
          final year = _baseYear + (index - _initialPage);
          final isSelected = (year == _selectedYear);

          return AnimatedContainer(
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
            child: Center(
              child: Text(
                '$year年',
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
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

  Widget _buildTicketList() {
    return ListView.builder(
      itemCount: _filteredTicketItems.length,
      itemBuilder: (context, index) {
        final item = _filteredTicketItems[index];
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
            final userId = localUserId; // FirebaseAuthからlocalUserIdに変更
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
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('「${item.displayTitle}」を削除しました。')));
              reloadData();
            }
          },
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: Card(
            color: isHit ? Colors.red.shade50 : null,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            elevation: 2.0,
            child: ListTile(
              isThreeLine: true,
              title: Text(item.displayTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
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
                if (item.raceResult?.raceDate == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('レースの日付情報がありません。')),
                  );
                  return;
                }
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RacePage(
                      raceId: item.raceId,
                      raceDate: item.raceResult!.raceDate,
                      qrData: item.qrData,
                    ),
                  ),
                );
                reloadData();
              },
            ),
          ),
        );
      },
    );
  }
}