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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('出馬表データの読み込みに失敗しました: $e')),
      );
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      // 最新の出馬表情報をスクレイピングしてDBを更新
      // scrapeFeaturedRacesはList<FeaturedRace>を返すので、対象のraceIdでフィルタリング
      final updatedRaces = await ScraperService.scrapeFeaturedRaces(_dbHelper);
      final updatedRace = updatedRaces.firstWhere(
            (r) => r.raceId == widget.raceId,
        orElse: () => throw Exception('Updated race not found in scraped data'),
      );

      // 各出走馬の競走成績も同期
      if (updatedRace.shutubaHorses != null && updatedRace.shutubaHorses!.isNotEmpty) {
        // syncNewHorseData は Future<void> を返すので await する
        await ScraperService.syncNewHorseData(
          [updatedRace], // このレースの馬のみ同期
          _dbHelper,
        );
      }

      setState(() {
        _featuredRace = updatedRace;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('出馬表データを更新しました')),
      );
    } catch (e) {
      print('Error refreshing shutuba data: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('出馬表データの更新に失敗しました: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold( // const を削除
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
                child: Text('出走馬情報がありません。'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRaceInfoCard(FeaturedRace race) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              // raceDateはStringなので、DateTime.parseで変換してからフォーマット
              '${DateFormat('yyyy年M月d日').format(DateTime.parse(race.raceDate))} ${race.venue} ${race.raceNumber}R',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${race.raceName} (${race.raceGrade})',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('距離: ${race.distance} / 条件: ${race.conditions} / 重量: ${race.weight}'),
            Text('詳細: ${race.raceDetails1 ?? ''} ${race.raceDetails2 ?? ''}'), // null許容に対応
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

  Widget _buildHorseList(List<ShutubaHorseDetail> horses) {
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
            // 最新5レース分に絞る
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
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        horse.gateNumber.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${horse.horseNumber}番'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        horse.horseName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text('${horse.sexAndAge} / ${horse.carriedWeight}kg'),
                    const SizedBox(width: 8),
                    FutureBuilder<UserMark?>(
                      future: _dbHelper.getUserMark(widget.raceId, horse.horseId),
                      builder: (context, markSnapshot) {
                        final currentMark = markSnapshot.data?.mark;
                        return DropdownButton<String>(
                          value: currentMark,
                          hint: const Text('印'),
                          items: <String>['◎', '〇', '▲', '△', '×', '消'].map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (String? newValue) async {
                            if (newValue != null) {
                              final userMark = UserMark(
                                raceId: widget.raceId,
                                horseId: horse.horseId,
                                mark: newValue,
                                timestamp: DateTime.now(),
                              );
                              await _dbHelper.insertOrUpdateUserMark(userMark); // メソッド名修正済み
                              setState(() {
                                // UIを再構築して印を更新 (FutureBuilderが再度実行される)
                              });
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('騎手: ${horse.jockey}'),
                    Text('オッズ: ${horse.odds?.toStringAsFixed(1) ?? '-'} / 人気: ${horse.popularity ?? '-'}'),
                    if (horse.isScratched)
                      const Text('出走取消', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ],
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('過去5走成績:', style: TextStyle(fontWeight: FontWeight.bold)),
                        if (records.isEmpty)
                          const Text('過去の競走成績がありません。')
                        else
                          ...records.map((record) => Text(
                              '${DateFormat('MM/dd').format(DateTime.parse(record.date))} ${record.venue}${record.raceNumber}R ${record.raceName} (${record.distance} ${record.trackCondition}) ${record.rank}着'
                          )).toList(),
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