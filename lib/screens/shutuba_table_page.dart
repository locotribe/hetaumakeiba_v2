// lib/screens/shutuba_table_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/featured_race_model.dart';
import 'package:hetaumakeiba_v2/models/shutuba_horse_detail_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';

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
      await _loadShutubaData();

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

  // ▼▼▼ グレード表示用のヘルパー関数を追加 ▼▼▼
  Color _getGradeColor(String grade) {
    if (grade.contains('G1')) return Colors.blue.shade700;
    if (grade.contains('G2')) return Colors.red.shade700;
    if (grade.contains('G3')) return Colors.green.shade700;
    return Colors.blueGrey; // デフォルト色
  }

  Color _getGradeTextColor(String grade) {
    return Colors.white;
  }
  // ▲▲▲ ヘルパー関数の追加ここまで ▲▲▲

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

  // ▼▼▼ グレード表示の修正を適用したメソッド ▼▼▼
  Widget _buildRaceInfoCard(FeaturedRace race) {
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
            const SizedBox(height: 8),
            Row( // グレードとレース名を横に並べるためにRowを使用
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // グレードが存在する場合のみ四角いアイコンを表示
                if (race.raceGrade.isNotEmpty) ...[
                  Container(
                    width: 40,
                    height: 25,
                    decoration: BoxDecoration(
                      color: _getGradeColor(race.raceGrade),
                    ),
                    child: Center(
                      child: Text(
                        race.raceGrade,
                        style: TextStyle(
                          color: _getGradeTextColor(race.raceGrade),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12), // アイコンとレース名の間隔
                ],
                // レース名
                Expanded( // 長いレース名でも表示が崩れないようにExpandedで囲む
                  child: Text(
                    race.raceName,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(race.raceDetails1 ?? ''),
          ],
        ),
      ),
    );
  }
  // ▲▲▲ _buildRaceInfoCardの修正ここまで ▲▲▲

  Color _getGateColor(int gateNumber) {
    switch (gateNumber) {
      case 1: return Colors.white;
      case 2: return Colors.black;
      case 3: return Colors.red;
      case 4: return Colors.blue;
      case 5: return Colors.yellow;
      case 6: return Colors.green;
      case 7: return Colors.orange;
      case 8: return Colors.pink.shade200;
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
// _buildHorseListメソッド全体をこちらのコードに置き換えてください

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
              margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 4.0),
                title: Row(
                  children: [
                    // ▼▼▼ 修正点①：「印」のドロップダウンをここに移動 ▼▼▼
                    FutureBuilder<UserMark?>(
                      future: _dbHelper.getUserMark(widget.raceId, horse.horseId),
                      builder: (context, markSnapshot) {
                        return DropdownButton<String>(
                          value: markSnapshot.data?.mark,
                          hint: const Text('印'),
                          underline: const SizedBox(),
                          items: <String>['◎', '〇', '▲', '△', '✕', '消', '　'].map((String value) {
                            return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                    value,
                                  style: const TextStyle(fontSize: 20.0),
                                )
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
                              await _dbHelper.insertOrUpdateUserMark(userMark);
                              setState(() {});
                            }
                          },
                        );
                      },
                    ),
                    // ▼▼▼ 修正点②：右側とのスペースを追加 ▼▼▼
                    const SizedBox(width: 8),

                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _getGateColor(horse.gateNumber),
                       // shape: BoxShape.circle,
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
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: 60, child: Text('${horse.sexAndAge} / ${horse.carriedWeight}kg', textAlign: TextAlign.end,)),
                    // 元の位置にあったFutureBuilderは削除
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
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(left: 8.0, bottom: 4.0),
                          child: Text('過去5走成績:', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const Center(child: CircularProgressIndicator())
                        else if (records.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text('過去の競走成績データがありません。'),
                          )
                        else
                          Column(
                            children: records.asMap().entries.map((entry) {
                              final record = entry.value;
                              final isLast = entry.key == records.length - 1;
                              return Column(
                                children: [
                                  _buildPastRaceRecord(record),
                                  if (!isLast)
                                    const Divider(height: 1),
                                ],
                              );
                            }).toList(),
                          )
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
  // ▼▼▼ 修正点：ご指摘に基づき、正しいプロパティを表示するように修正 ▼▼▼
  Widget _buildPastRaceRecord(HorseRaceRecord record) {
    Widget buildInfoRow(String label, String value) {
      // 値が空、または"-"の場合は行自体を表示しない
      if (value.trim().isEmpty || value.trim() == '-') {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 120,
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '${record.date.replaceAll('/', '.')} ${record.raceName}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text('${record.rank}着', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          buildInfoRow('開催/条件/馬場', '${record.venue} ${record.raceNumber}R / ${record.distance} / 天候:${record.weather} / 馬場:${record.trackCondition}'),
          buildInfoRow('枠/馬番/頭数', '${record.frameNumber} / ${record.horseNumber} / ${record.numberOfHorses}'),
          buildInfoRow('騎手/斤量', '${record.jockey} / ${record.carriedWeight}kg'),
          buildInfoRow('タイム/着差/ペース', '${record.time} / ${record.margin} / ${record.pace}'),
          buildInfoRow('通過', '${record.cornerPassage} / ${record.agari}'),
          buildInfoRow('人気/オッズ', '${record.popularity}番人気 / ${record.odds}倍'),
          buildInfoRow('馬体重', record.horseWeight),
          buildInfoRow('勝ち馬', record.winnerOrSecondHorse),
          buildInfoRow('賞金', record.prizeMoney),
        ],
      ),
    );
  }
}