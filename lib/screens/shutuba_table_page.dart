// lib/screens/shutuba_table_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';
import 'package:hetaumakeiba_v2/models/shutuba_horse_detail_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:intl/intl.dart'; // 日付フォーマット用

class ShutubaTablePage extends StatefulWidget {
  final String raceId;

  const ShutubaTablePage({Key? key, required this.raceId}) : super(key: key);

  @override
  State<ShutubaTablePage> createState() => _ShutubaTablePageState();
}

class _ShutubaTablePageState extends State<ShutubaTablePage> {
  FeaturedRace? _featuredRace;
  bool _isLoading = true;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadShutubaData();
  }

  Future<void> _loadShutubaData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final race = await _dbHelper.getFeaturedRace(widget.raceId);
      setState(() {
        _featuredRace = race;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading shutuba data: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('出馬表データの読み込みに失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _refreshData() async {
    // 1時間に1回しか更新できないようにするロジック
    if (_featuredRace != null && _featuredRace!.lastScraped.isAfter(DateTime.now().subtract(const Duration(hours: 1)))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('データの更新は1時間に1回までです。')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ScraperService.scrapeFeaturedRaces(_dbHelper);
      await _loadShutubaData(); // 再読み込み

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('出馬表データを更新しました')),
        );
      }
    } catch (e) {
      print('Error refreshing shutuba data: $e');
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('出馬表データの更新に失敗しました: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('出馬表')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_featuredRace == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('出馬表')),
        body: Center(child: Text('レース情報が見つかりませんでした。ID: ${widget.raceId}')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_featuredRace!.raceName),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          children: [
            _buildRaceInfoCard(_featuredRace!),
            if (_featuredRace!.shutubaHorses != null && _featuredRace!.shutubaHorses!.isNotEmpty)
              _buildHorseList(_featuredRace!.shutubaHorses!),
            if (_featuredRace!.shutubaHorses == null || _featuredRace!.shutubaHorses!.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Center(child: Text('出走馬情報がありません。')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRaceInfoCard(FeaturedRace race) {
    // ▼▼▼ 修正点：グレードが空でない場合のみ()付きで表示する ▼▼▼
    String raceTitle = race.raceName;
    if (race.raceGrade.isNotEmpty) {
      raceTitle += ' (${race.raceGrade})';
    }
    // ▲▲▲ 修正ここまで ▲▲▲

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${race.raceDate} ${race.venue} ${race.raceNumber}R',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              raceTitle, // 修正したタイトルを表示
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(race.raceDetails1 ?? ''),
          ],
        ),
      ),
    );
  }

  Color _getGateColor(int gateNumber) {
    switch (gateNumber) {
      case 1: return Colors.white;
      case 2: return Colors.black;
      case 3: return Colors.red;
      case 4: return Colors.blue;
      case 5: return Colors.yellow;
      case 6: return Colors.green;
      case 7: return Colors.orange;
      case 8: return Colors.pink;
      default: return Colors.grey;
    }
  }

  Color _getTextColorForGate(int gateNumber) {
    switch (gateNumber) {
      case 1:
      case 5:
        return Colors.black;
      default:
        return Colors.white;
    }
  }

  Widget _buildHorseList(List<ShutubaHorseDetail> horses) {
    horses.sort((a, b) => a.horseNumber.compareTo(b.horseNumber));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: horses.length,
      itemBuilder: (context, index) {
        final horse = horses[index];
        return FutureBuilder<List<HorseRaceRecord>>(
          future: _dbHelper.getHorsePerformanceRecords(horse.horseId),
          builder: (context, snapshot) {
            List<HorseRaceRecord> records = snapshot.data ?? [];
            if (records.length > 5) {
              records = records.sublist(0, 5);
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: ExpansionTile(
                title: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _getGateColor(horse.gateNumber),
                        shape: BoxShape.circle,
                        border: horse.gateNumber == 1 ? Border.all(color: Colors.grey) : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        horse.gateNumber.toString(),
                        style: TextStyle(color: _getTextColorForGate(horse.gateNumber), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(width: 30, child: Text('${horse.horseNumber}番')),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        horse.horseName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 80, child: Text('${horse.sexAndAge} / ${horse.carriedWeight}kg', textAlign: TextAlign.end,)),
                    const SizedBox(width: 8),
                    FutureBuilder<UserMark?>(
                      future: _dbHelper.getUserMark(widget.raceId, horse.horseId),
                      builder: (context, markSnapshot) {
                        return DropdownButton<String>(
                          value: markSnapshot.data?.mark,
                          hint: const Text('印'),
                          underline: const SizedBox(),
                          items: <String>['◎', '〇', '▲', '△', '×', '消'].map((String value) {
                            return DropdownMenuItem<String>(value: value, child: Text(value));
                          }).toList(),
                          onChanged: (String? newValue) async {
                            if (newValue != null) {
                              final userMark = UserMark(
                                raceId: widget.raceId,
                                horseId: horse.horseId,
                                mark: newValue,
                                timestamp: DateTime.now(),
                              );
                              await _dbHelper.insertOrUpdateUserMark(userMark);
                              setState(() {});
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('騎手: ${horse.jockey}'),
                      Text('オッズ: ${horse.odds?.toStringAsFixed(1) ?? '--'} / ${horse.popularity ?? '--'}人気'),
                      if (horse.isScratched)
                        const Text('出走取消', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('過去5走成績:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Center(child: CircularProgressIndicator())
                        else if (records.isEmpty)
                          const Text('  過去の競走成績データがありません。')
                        else
                          ...records.map((record) {
                            try {
                              final formattedDate = DateFormat('MM/dd').format(DateTime.parse(record.date.replaceAll('/', '-')));
                              return Text('  $formattedDate ${record.raceName} (${record.distance}) ${record.rank}着');
                            } catch (e) {
                              return Text('  日付形式エラー: ${record.date}');
                            }
                          }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}