// lib/screens/saved_tickets_list_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/logic/hit_checker.dart';
import 'package:hetaumakeiba_v2/models/qr_data_model.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/logic/parse.dart';
import 'package:hetaumakeiba_v2/screens/saved_ticket_detail_page.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/utils/url_generator.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';

class TicketListItem {
  final QrData qrData;
  final Map<String, dynamic> parsedTicket;
  final RaceResult? raceResult;
  final HitResult? hitResult;
  final String displayTitle;
  final String displaySubtitle;

  TicketListItem({
    required this.qrData,
    required this.parsedTicket,
    this.raceResult,
    this.hitResult,
    required this.displayTitle,
    required this.displaySubtitle,
  });
}

class SavedTicketsListPage extends StatefulWidget {
  const SavedTicketsListPage({super.key});

  @override
  State<SavedTicketsListPage> createState() => SavedTicketsListPageState();
}

class SavedTicketsListPageState extends State<SavedTicketsListPage> {
  List<TicketListItem> _allTicketItems = [];
  List<TicketListItem> _filteredTicketItems = [];

  // 年月選択の状態管理変数
  int? _selectedYear;
  int? _selectedMonth;
  // ▼▼▼ 購入履歴のある月を管理する変数を復活 ▼▼▼
  Map<int, Set<int>> _monthsWithData = {}; // {年: {月のセット}} の形でデータを保持

  late PageController _pageController;
  static const int _initialPage = 10000; // PageViewの擬似無限スクロール用
  int _baseYear = DateTime.now().year; // PageViewの中心となる年

  bool _isLoading = true;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // 英語の月名リスト
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

    final allQrData = await _dbHelper.getAllQrData();
    final List<TicketListItem> tempItems = [];
    for (final qrData in allQrData) {
      try {
        final parsedTicket = jsonDecode(qrData.parsedDataJson) as Map<String, dynamic>;
        if (parsedTicket.isEmpty) continue;

        final url = generateNetkeibaUrl(
          year: parsedTicket['年'].toString(),
          racecourseCode: racecourseDict.entries.firstWhere((e) => e.value == parsedTicket['開催場']).key,
          round: parsedTicket['回'].toString(),
          day: parsedTicket['日'].toString(),
          race: parsedTicket['レース'].toString(),
        );
        final raceId = ScraperService.getRaceIdFromUrl(url)!;
        final raceResult = await _dbHelper.getRaceResult(raceId);

        HitResult? hitResult;
        if (raceResult != null) {
          hitResult = HitChecker.check(parsedTicket: parsedTicket, raceResult: raceResult);
        }

        tempItems.add(TicketListItem(
          qrData: qrData, parsedTicket: parsedTicket, raceResult: raceResult, hitResult: hitResult,
          displayTitle: '', displaySubtitle: '',
        ));
      } catch (e) {
        print('購入履歴のデータ処理中にエラーが発生しました: ${qrData.id} - $e');
      }
    }

    final Map<String, int> duplicateCounter = {};
    for (final item in tempItems) {
      final key = _generatePurchaseKey(item.parsedTicket);
      duplicateCounter[key] = (duplicateCounter[key] ?? 0) + 1;
    }
    final Map<String, int> currentDuplicateIndex = {};
    final List<TicketListItem> finalItems = [];
    for (final item in tempItems) {
      String title;
      if (item.raceResult != null) {
        title = item.raceResult!.raceTitle;
      } else {
        final venue = item.parsedTicket['開催場'] ?? '不明';
        final raceNum = item.parsedTicket['レース'] ?? '??';
        title = '$venue ${raceNum}R';
      }
      String purchaseMethodDisplay = item.parsedTicket['方式'] ?? '';
      if (purchaseMethodDisplay == 'ながし') {
        final purchaseContents = item.parsedTicket['購入内容'] as List<dynamic>?;
        if (purchaseContents != null && purchaseContents.isNotEmpty) {
          final firstPurchase = purchaseContents.first as Map<String, dynamic>;
          purchaseMethodDisplay = firstPurchase['ながし種別'] as String? ?? purchaseMethodDisplay;
          if (firstPurchase.containsKey('マルチ') && firstPurchase['マルチ'] == 'あり') {
            purchaseMethodDisplay += 'マルチ';
          }
        }
      }
      final purchaseDetails = (item.parsedTicket['購入内容'] as List).map((p) => p['式別']).where((p) => p != null).toSet().join(', ');
      String line2 = '$purchaseDetails $purchaseMethodDisplay';
      final key = _generatePurchaseKey(item.parsedTicket);
      if (duplicateCounter[key]! > 1) {
        final index = (currentDuplicateIndex[key] ?? 0) + 1;
        line2 += ' ($index)';
        currentDuplicateIndex[key] = index;
      }
      final line3 = _formatPurchaseSummary(item.parsedTicket['購入内容'] as List<dynamic>);
      final combinedSubtitle = '$line2\n$line3';

      finalItems.add(TicketListItem(
        qrData: item.qrData, parsedTicket: item.parsedTicket, raceResult: item.raceResult,
        hitResult: item.hitResult, displayTitle: title, displaySubtitle: combinedSubtitle,
      ));
    }
    finalItems.sort((a, b) {
      final dateA = a.raceResult?.raceDate;
      final dateB = b.raceResult?.raceDate;
      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;
      return dateB.compareTo(dateA);
    });
    _allTicketItems = finalItems;

    // ▼▼▼ 購入履歴のある月を抽出するロジックを復活 ▼▼▼
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
    // ▲▲▲ ここまで ▲▲▲

    if (_allTicketItems.isNotEmpty) {
      if (_selectedYear == null || _selectedMonth == null) {
        final latestItem = _allTicketItems.first;
        if(latestItem.raceResult != null) {
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

  String _formatPurchaseSummary(List<dynamic> purchases) {
    if (purchases.isEmpty) return '';
    try {
      final firstPurchase = purchases.first as Map<String, dynamic>;
      final amount = firstPurchase['購入金額'] ?? 0;
      String horseNumbersStr = '';
      if (firstPurchase.containsKey('all_combinations')) {
        final combinations = firstPurchase['all_combinations'] as List;
        if (combinations.isNotEmpty) {
          horseNumbersStr = (combinations.first as List).join('→');
        }
      }
      String summary = '$horseNumbersStr / ${amount}円';
      if (purchases.length > 1 || (firstPurchase['all_combinations'] as List).length > 1) {
        summary += ' ...他';
      }
      return summary;
    } catch (e) {
      print('Error in _formatPurchaseSummary: $e');
      return '購入内容の表示に失敗しました';
    }
  }

  String _generatePurchaseKey(Map<String, dynamic> parsedTicket) {
    try {
      final url = generateNetkeibaUrl(
        year: parsedTicket['年'].toString(),
        racecourseCode: racecourseDict.entries.firstWhere((e) => e.value == parsedTicket['開催場']).key,
        round: parsedTicket['回'].toString(),
        day: parsedTicket['日'].toString(),
        race: parsedTicket['レース'].toString(),
      );
      final raceId = ScraperService.getRaceIdFromUrl(url)!;
      final purchaseMethod = parsedTicket['方式'] ?? '';
      final purchaseDetails = (parsedTicket['購入内容'] as List);
      final detailsString = purchaseDetails.map((p) {
        final detailMap = p as Map<String, dynamic>;
        final sortedKeys = detailMap.keys.toList()..sort();
        return sortedKeys.map((key) => '$key:${detailMap[key]}').join(';');
      }).join('|');
      return '$raceId-$purchaseMethod-$detailsString';
    } catch (e) {
      return parsedTicket['QR'] ?? parsedTicket.toString();
    }
  }

  Future<void> _deleteAllData() async {
    // 省略
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

  // ▼▼▼ 年セレクターの選択色を修正 ▼▼▼
  Widget _buildYearSelector() {
    const activeColor = Color(0xFF1A4314); // バナーに合わせた色

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
                  color: activeColor.withOpacity(0.5),
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

  // ▼▼▼ 月セレクターに「購入履歴あり」のスタイルを再適用 ▼▼▼
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
          backgroundColor = Colors.grey.shade700; // 選択中はグレー
          textColor = Colors.white;
          fontWeight = FontWeight.bold;
        } else if (hasData) {
          backgroundColor = Colors.green.shade100; // データありは薄い緑
          textColor = Colors.green.shade900;
          fontWeight = FontWeight.w600;
        } else {
          backgroundColor = Colors.white; // 通常は白
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
                '${month}月',
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

    final englishMonth = _englishMonths[_selectedMonth! - 1];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A4314),
        gradient: const LinearGradient(
          colors: [Color(0xFF1A4314), Color(0xFF2E6331)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_selectedMonth}月',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  englishMonth,
                  style: const TextStyle(
                    color: Color(0xFF1A4314),
                    fontSize: 11,
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
        final balance = payout - totalAmount;

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
            await _dbHelper.deleteQrData(item.qrData.id!);
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
                  Text('${totalAmount}円', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black54, height: 1.2)),
                  if (item.raceResult != null) ...[
                    Text('${payout}円', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isHit ? Colors.green.shade700 : Colors.black, height: 1.2)),
                    Text('${balance >= 0 ? '+' : ''}$balance円', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: balance > 0 ? Colors.blue.shade700 : (balance < 0 ? Colors.red.shade700 : Colors.black), height: 1.2)),
                  ] else
                    const Text(' (未確定)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => SavedTicketDetailPage(qrData: item.qrData)),
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