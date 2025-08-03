// lib/screens/shutuba_table_page.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/database_helper.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart';
import 'package:hetaumakeiba_v2/services/scraper_service.dart';
import 'package:hetaumakeiba_v2/models/prediction_race_data.dart';

class ShutubaTablePage extends StatefulWidget {
  final String raceId;

  const ShutubaTablePage({Key? key, required this.raceId}) : super(key: key);

  @override
  State<ShutubaTablePage> createState() => _ShutubaTablePageState();
}

class _ShutubaTablePageState extends State<ShutubaTablePage> {
  late Future<PredictionRaceData?> _predictionRaceDataFuture;
  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    _loadShutubaData();
  }

  Future<void> _loadShutubaData() async {
    setState(() {
      _predictionRaceDataFuture = _fetchPredictionData();
    });
  }

  Future<PredictionRaceData?> _fetchPredictionData() async {
    try {
      final race = await _dbHelper.getFeaturedRace(widget.raceId);
      if (race == null) {
        throw Exception('データベースからレース情報が見つかりませんでした。');
      }
      final predictionData = await ScraperService.scrapePredictionRaceData(race);
      final userMarks = await _dbHelper.getAllUserMarksForRace(widget.raceId);
      final markMap = {for (var mark in userMarks) mark.horseId: mark};

      for (var horse in predictionData.horses) {
        horse.userMark = markMap[horse.horseId];
      }
      return predictionData;
    } catch (e) {
      print('Error fetching prediction data: $e');
      rethrow;
    }
  }

  Future<void> _refreshData() async {
    await _loadShutubaData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('出馬表データを更新しました')),
      );
    }
  }

  Color _getGradeColor(String grade) {
    if (grade.contains('G1')) return Colors.blue.shade700;
    if (grade.contains('G2')) return Colors.red.shade700;
    if (grade.contains('G3')) return Colors.green.shade700;
    return Colors.blueGrey;
  }

  Color _getGradeTextColor(String grade) {
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('出馬表'),
      ),
      body: FutureBuilder<PredictionRaceData?>(
        future: _predictionRaceDataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('エラー: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: Text('レース情報が見つかりませんでした。ID: ${widget.raceId}'));
          }

          final predictionData = snapshot.data!;
          return RefreshIndicator(
            onRefresh: _refreshData,
            child: ListView(
              children: [
                _buildRaceInfoCard(predictionData),
                if (predictionData.horses.isNotEmpty)
                  _buildHorseList(predictionData.horses),
                if (predictionData.horses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: Text('出走馬情報がありません。')),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRaceInfoCard(PredictionRaceData race) {
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
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
                  const SizedBox(width: 12),
                ],
                Expanded(
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

  Widget _buildHorseList(List<PredictionHorseDetail> horses) {
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
                    DropdownButton<String>(
                      value: horse.userMark?.mark,
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
                          setState(() {
                            horse.userMark = userMark;
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 8),

                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _getGateColor(horse.gateNumber),
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
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('騎手: ${horse.jockey}'),
                      Text('オッズ: ${horse.odds?.toStringAsFixed(1) ?? '--'} / ${horse.popularity ?? '--'}人気'),
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
  Widget _buildPastRaceRecord(HorseRaceRecord record) {
    Widget buildInfoRow(String label, String value) {
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