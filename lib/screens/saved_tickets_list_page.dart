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

  int? _selectedYear;
  int? _selectedMonth;
  List<int> _availableYears = [];

  bool _isLoading = true;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    reloadData(); // 関数名を変更
  }

  // ▼▼▼ 関数名を _loadAllDataAndSetInitialFilter から reloadData に変更 ▼▼▼
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

    _allTicketItems = finalItems;

    // ▼▼▼ 年の抽出とソート処理をnullセーフに修正 ▼▼▼
    final years = _allTicketItems
        .map((item) {
      try {
        if (item.raceResult?.raceDate != null) {
          return int.parse(item.raceResult!.raceDate.split('年').first);
        }
        return null;
      } catch (e) { return null; }
    })
        .where((y) => y != null)
        .toSet()
        .toList();

    final nonNullYears = years.cast<int>();
    nonNullYears.sort((a, b) => b.compareTo(a)); // 降順にソート
    _availableYears = nonNullYears;
    // ▲▲▲ ここまで修正 ▲▲▲

    if (_allTicketItems.isNotEmpty) {
      if (_selectedYear == null || !_availableYears.contains(_selectedYear)) {
        final latestItem = _allTicketItems.first;
        try {
          final dateParts = latestItem.raceResult!.raceDate.split(RegExp(r'[年月日]'));
          _selectedYear = int.parse(dateParts[0]);
          _selectedMonth = int.parse(dateParts[1]);
        } catch (e) {
          if(_availableYears.isNotEmpty) _selectedYear = _availableYears.first;
          _selectedMonth = DateTime.now().month;
        }
      }
    }

    _filterTickets();

    setState(() { _isLoading = false; });
  }

  void _filterTickets() {
    if (_selectedYear == null || _selectedMonth == null) {
      _filteredTicketItems = [];
      return;
    }
    _filteredTicketItems = _allTicketItems.where((item) {
      if (item.raceResult == null) return false;
      try {
        final dateParts = item.raceResult!.raceDate.split(RegExp(r'[年月日]'));
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        return year == _selectedYear && month == _selectedMonth;
      } catch (e) {
        return false;
      }
    }).toList();
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
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('全データ削除'),
        content: const Text('本当にすべての保存データを削除しますか？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('キャンセル')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('削除')),
        ],
      ),
    );
    if (confirm == true) {
      await _dbHelper.deleteAllData();
      await reloadData(); // 関数名を変更
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('すべてのデータが削除されました。')));
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
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildYearSelector(),
              const SizedBox(height: 8),
              _buildMonthSelector(),
              const Divider(height: 24),
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
    if (_availableYears.isEmpty) return const SizedBox(height: 40);
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _availableYears.length,
        itemBuilder: (context, index) {
          final year = _availableYears[index];
          final isSelected = year == _selectedYear;
          return ActionChip(
            label: Text('$year年', style: TextStyle(color: isSelected ? Colors.white : Colors.black)),
            backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.white,
            onPressed: () {
              setState(() {
                _selectedYear = year;
                _filterTickets();
              });
            },
          );
        },
        separatorBuilder: (context, index) => const SizedBox(width: 8),
      ),
    );
  }

  Widget _buildMonthSelector() {
    return GridView.count(
      crossAxisCount: 6,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.8,
      children: List.generate(12, (index) {
        final month = index + 1;
        final isSelected = month == _selectedMonth;
        return ElevatedButton(
          onPressed: () {
            setState(() {
              _selectedMonth = month;
              _filterTickets();
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Theme.of(context).primaryColor.withOpacity(0.8) : Colors.white,
            foregroundColor: isSelected ? Colors.white : Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: EdgeInsets.zero,
          ),
          child: Text('${month}月'),
        );
      }),
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
              reloadData(); // 関数名を変更
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
                reloadData(); // 関数名を変更
              },
            ),
          ),
        );
      },
    );
  }
}
