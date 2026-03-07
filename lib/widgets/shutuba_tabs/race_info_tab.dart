// lib/widgets/shutuba_tabs/race_info_tab.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/utils/grade_utils.dart';
import 'package:hetaumakeiba_v2/db/repositories/track_condition_repository.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/services/jma_weather_service.dart'; // 気象庁APIサービスをインポート
import 'package:hetaumakeiba_v2/services/open_meteo_service.dart'; // ▼ 追加
import 'package:hetaumakeiba_v2/logic/analysis/weather_analyzer.dart'; // 作成したファイルをインポート

class RaceInfoTabWidget extends StatefulWidget {
  final PredictionRaceData predictionRaceData;
  final List<PredictionHorseDetail> horses;
  final Widget Function(PredictionHorseDetail) buildMarkDropdown;
  final Widget Function(int) buildGateNumber;
  final Widget Function(int, int) buildHorseNumber;

  const RaceInfoTabWidget({
    super.key,
    required this.predictionRaceData,
    required this.horses,
    required this.buildMarkDropdown,
    required this.buildGateNumber,
    required this.buildHorseNumber,
  });

  @override
  State<RaceInfoTabWidget> createState() => _RaceInfoTabWidgetState();
}

// ▼ AutomaticKeepAliveClientMixin を追加してタブの状態を保持する ▼
class _RaceInfoTabWidgetState extends State<RaceInfoTabWidget> with AutomaticKeepAliveClientMixin {
  final TrackConditionRepository _trackConditionRepo = TrackConditionRepository();
  Future<TrackConditionRecord?>? _trackConditionFuture;
  Future<Map<String, String>?>? _jmaWeatherFuture;
  Future<Map<String, dynamic>?>? _pinpointWeatherFuture;

  // ▼ これを true にすることで、タブを切り替えても状態が保持される ▼
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  @override
  void didUpdateWidget(RaceInfoTabWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 印を変えただけ(同レース)ではリロードしないように、raceIdを比較
    if (widget.predictionRaceData.raceId != oldWidget.predictionRaceData.raceId) {
      _loadAllData();
    }
  }

  // ▼ UI表示用に「3/8(日) 15:40」という分かりやすい文字列を作るメソッド
  String _getFormattedRaceTime() {
    final rawDate = widget.predictionRaceData.raceDate;
    final rawTime = widget.predictionRaceData.startTime ?? "未定";
    try {
      final dateMatch = RegExp(r'(\d{4})[^\d]*(\d{1,2})[^\d]*(\d{1,2})').firstMatch(rawDate);
      if (dateMatch != null) {
        final year = int.parse(dateMatch.group(1)!);
        final month = int.parse(dateMatch.group(2)!);
        final day = int.parse(dateMatch.group(3)!);
        final dt = DateTime(year, month, day);
        const weekdays = ['', '月', '火', '水', '木', '金', '土', '日'];
        final w = weekdays[dt.weekday];
        return '$month/$day($w) $rawTime';
      }
    } catch(e) {}
    return rawTime;
  }

  // ▼ 変更: どんな日付形式でも確実に判定する強力なロックメソッド
  bool _isWeatherLocked() {
    try {
      int year = DateTime.now().year;
      int month = DateTime.now().month;
      int day = DateTime.now().day;

      // 正規表現を使って文字列の中から「4桁の数字(年)」「1〜2桁の数字(月)」「1〜2桁の数字(日)」を強引に抜き出す
      // これにより "2024-03-08", "2024/03/08", "2024年3月8日", "20240308" など全てに対応可能
      final dateMatch = RegExp(r'(\d{4})[^\d]*(\d{1,2})[^\d]*(\d{1,2})').firstMatch(widget.predictionRaceData.raceDate);

      if (dateMatch != null) {
        year = int.parse(dateMatch.group(1)!);
        month = int.parse(dateMatch.group(2)!);
        day = int.parse(dateMatch.group(3)!);
      } else {
        // どうしても日付が取れない場合は、データを壊さないよう安全のために「ロック(true)」にする
        return true;
      }

      final timeStr = widget.predictionRaceData.startTime ?? "15:00";
      final timeParts = timeStr.split(':');
      int hour = 15;
      int minute = 0;
      if (timeParts.length >= 2) {
        hour = int.tryParse(timeParts[0]) ?? 15;
        minute = int.tryParse(timeParts[1]) ?? 0;
      }

      final raceDateTime = DateTime(year, month, day, hour, minute);

      // ★ ロックする時刻 ＝ 発走時刻の「1時間後」
      final lockTime = raceDateTime.add(const Duration(hours: 1));

      return DateTime.now().isAfter(lockTime);
    } catch (e) {
      // エラーが起きた場合も安全装置としてロック
      return true;
    }
  }

  void _loadAllData({bool forceRefresh = false}) {
    _loadTrackCondition();
    setState(() {
      final venue = widget.predictionRaceData.venue;
      final raceId = widget.predictionRaceData.raceId;
      final isLocked = _isWeatherLocked(); // ▼ ロック判定を実行

      _jmaWeatherFuture = JmaWeatherService.fetchWeatherAndPop(
          venue,
          raceId,
          forceRefresh: forceRefresh,
          isPastRace: isLocked // ロックされていれば過去レースとして扱う
      );

      _pinpointWeatherFuture = OpenMeteoService.fetchDetailedWeather(
          venue,
          widget.predictionRaceData.raceDate,
          widget.predictionRaceData.startTime ?? "15:00",
          raceId,
          forceRefresh: forceRefresh,
          isPastRace: isLocked // ロックされていれば過去レースとして扱う
      );
    });
  }

  void _loadTrackCondition() {
    if (widget.predictionRaceData.raceId.length >= 6) {
      final venueCode = widget.predictionRaceData.raceId.substring(4, 6);
      setState(() {
        _trackConditionFuture = _trackConditionRepo.getLatestTrackConditionsForEachCourse().then((records) {
          try {
            return records.firstWhere((r) {
              final idStr = r.trackConditionId.toString();
              if (idStr.length >= 6) {
                return idStr.substring(4, 6) == venueCode;
              }
              return false;
            });
          } catch (e) {
            return null;
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // ▼ AutomaticKeepAliveClientMixin に必須 ▼
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRaceHeader(context),
          const Divider(height: 1, thickness: 1),
          _buildSimpleShutubaList(context),
        ],
      ),
    );
  }

  // 画面上部：レース情報ヘッダー
  Widget _buildRaceHeader(BuildContext context) {
    final gradeColor = getGradeColor(widget.predictionRaceData.raceGrade ?? '');

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1行目: レース番号、レース名、グレード
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade800,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${widget.predictionRaceData.raceNumber}R',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.predictionRaceData.raceName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (widget.predictionRaceData.raceGrade != null && widget.predictionRaceData.raceGrade!.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: gradeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    widget.predictionRaceData.raceGrade!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ]
            ],
          ),
          const SizedBox(height: 12),
          // 2行目: コース情報、発走時刻、天候、馬場 (元データ)
          Wrap(
            spacing: 12.0,
            runSpacing: 4.0,
            children: [
              Text('発走: ${widget.predictionRaceData.startTime ?? "-"}'),
              Text('${widget.predictionRaceData.trackType ?? ""}${widget.predictionRaceData.distanceValue ?? ""}m (${widget.predictionRaceData.direction ?? ""} ${widget.predictionRaceData.courseInOut ?? ""})'),
              Text('天候: ${widget.predictionRaceData.weather ?? "-"}'),
              Text('馬場: ${widget.predictionRaceData.trackCondition ?? "-"}'),
            ],
          ),
          const SizedBox(height: 8),
          // 3行目: 開催、条件、頭数
          Text(
            '${widget.predictionRaceData.venue} ${widget.predictionRaceData.holdingTimes ?? ""} ${widget.predictionRaceData.holdingDays ?? ""} / ${widget.predictionRaceData.raceCategory ?? ""} / ${widget.predictionRaceData.horseCount ?? ""}頭',
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
          const SizedBox(height: 4),
          // 4行目: 賞金
          Text(
            '本賞金: ${widget.predictionRaceData.basePrize1st ?? "-"}, ${widget.predictionRaceData.basePrize2nd ?? "-"}, ${widget.predictionRaceData.basePrize3rd ?? "-"}, ${widget.predictionRaceData.basePrize4th ?? "-"}, ${widget.predictionRaceData.basePrize5th ?? "-"}万円',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),

          // ▼詳細な馬場状態（クッション値・含水率）▼
          _buildDetailedTrackCondition(),

          const SizedBox(height: 12),
          // 気象庁とOpen-Meteoを縦に並べる
          _buildJmaWeather(),
          const SizedBox(height: 12),
          _buildPinpointWeather(),
        ],
      ),
    );
  }

  // JRA発表の馬場詳細（クッション値・含水率）を描画するウィジェット
  Widget _buildDetailedTrackCondition() {
    if (_trackConditionFuture == null) return const SizedBox.shrink();

    return FutureBuilder<TrackConditionRecord?>(
      future: _trackConditionFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.only(top: 12.0),
            child: Text('馬場詳細データを取得中...', style: TextStyle(fontSize: 12, color: Colors.black54)),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }

        final record = snapshot.data!;
        final dateStr = record.date.replaceAll('-', '/');
        final venueName = '${widget.predictionRaceData.venue}競馬場';

        return Container(
          margin: const EdgeInsets.only(top: 12.0),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blueGrey.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.grass, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text('$venueName ($dateStr)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16.0,
                runSpacing: 8.0,
                children: [
                  _buildTrackConditionItem('クッション値', '${record.cushionValue ?? "-"}'),
                  _buildTrackConditionItem('芝含水率 (G / 4C)', '${record.moistureTurfGoal ?? "-"}% / ${record.moistureTurf4c ?? "-"}%'),
                  _buildTrackConditionItem('ダ含水率 (G / 4C)', '${record.moistureDirtGoal ?? "-"}% / ${record.moistureDirt4c ?? "-"}%'),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ▼ 気象庁APIウィジェット（横幅いっぱい） ▼
  Widget _buildJmaWeather() {
    return FutureBuilder<Map<String, String>?>(
      future: _jmaWeatherFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const SizedBox.shrink();
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.public, size: 16, color: Colors.blue),
                      SizedBox(width: 4),
                      Text('気象庁 広域天気概況', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  // ★ 右上に発表時刻を表示
                  Text('${data['reportDatetime']} 発表', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                ],
              ),
              const SizedBox(height: 8),
              // ★ 天気概況（解説文）をそのまま表示
              Text(
                data['overviewText'] ?? '',
                style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }

  // ▼ Open-MeteoAPI（ピンポイント詳細・タイムライン） ▼
  Widget _buildPinpointWeather() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _pinpointWeatherFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!;
        final current = data['current'];
        final raceTime = data['raceTime'];
        final List<dynamic> timeline = data['timeline'] ?? [];

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.teal.shade300, width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.teal.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.teal),
                      const SizedBox(width: 4),
                      Text('${widget.predictionRaceData.venue}競馬場 ピンポイント詳細', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal)),
                    ],
                  ),
                  if (_isWeatherLocked())
                    const Text('当時のデータ', style: TextStyle(fontSize: 10, color: Colors.grey))
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20, color: Colors.teal),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        _loadAllData(forceRefresh: true);
                      },
                    ),
                ],
              ),
              const Divider(),

              // ▼ 1. 現在の状況 ▼
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('📍 現在の状況', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('(${current['time']} 現在)', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16.0,
                runSpacing: 8.0,
                children: [
                  _buildTrackConditionItem('気温', '${current['temp']}℃'),
                  _buildTrackConditionItem('湿度', '${current['humidity']}%'),
                  _buildTrackConditionItem('降水量', '${current['precipitation']} mm'),
                  _buildTrackConditionItem('風速', '${current['windSpeed']} m/s'),
                  _buildTrackConditionItem('風向き', current['windDirText']),
                ],
              ),
              const SizedBox(height: 12),

              // ▼ 2. 発走時刻の予報 ▼
              Text('🏁 発走時刻 (${_getFormattedRaceTime()}) の予報', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16.0,
                runSpacing: 8.0,
                children: [
                  _buildTrackConditionItem('気温', '${raceTime['temp']}℃'),
                  _buildTrackConditionItem('湿度', '${raceTime['humidity']}%'),
                  _buildTrackConditionItem('降水確率', '${raceTime['pop']}%'),
                  _buildTrackConditionItem('降水量', '${raceTime['precipitation']} mm'),
                  _buildTrackConditionItem('風速', '${raceTime['windSpeed']} m/s'),
                  _buildTrackConditionItem('風向き', data['windDirText']),
                ],
              ),
              const SizedBox(height: 12),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  data['windAnalysis'],
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                ),
              ),
              const SizedBox(height: 16),

              // ▼ 3. 午後の時系列タイムライン ▼
              const Text('🕒 午後の時系列変化', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: timeline.map((t) {
                    // ★ 修正: キャッシュから読み込んだ際にもエラーにならないよう null 安全処理
                    final double precip = (t['precipitation'] as num?)?.toDouble() ?? 0.0;
                    return Container(
                      width: 50,
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        children: [
                          Text(t['time'], style: const TextStyle(fontSize: 10, color: Colors.black54)),
                          const SizedBox(height: 4),
                          Text('${t['temp']}℃', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('${t['pop']}%', style: const TextStyle(fontSize: 10, color: Colors.blue)),
                          if (precip > 0)
                            Text('${precip}mm', style: const TextStyle(fontSize: 10, color: Colors.lightBlue)),
                          Text('${t['windSpeed']}m', style: const TextStyle(fontSize: 10, color: Colors.teal)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // 馬場状態・天気項目の各項目を描画するヘルパー
  Widget _buildTrackConditionItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

  // 画面下部：簡易出馬表リスト
  Widget _buildSimpleShutubaList(BuildContext context) {
    final List<PredictionHorseDetail> displayHorses = List.from(widget.horses);
    displayHorses.sort((a, b) {
      if (a.horseNumber > 0 && b.horseNumber > 0) {
        return a.horseNumber.compareTo(b.horseNumber);
      }
      if (a.horseNumber > 0 && b.horseNumber <= 0) return -1;
      if (a.horseNumber <= 0 && b.horseNumber > 0) return 1;
      return a.horseName.compareTo(b.horseName);
    });

    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: displayHorses.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final horse = displayHorses[index];
        final bool isLowOdds = horse.odds != null && horse.odds! <= 9.9;
        final Color oddsColor = isLowOdds ? Colors.red : Colors.black87;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          child: Row(
            children: [
              // 1. 馬番
              widget.buildHorseNumber(horse.horseNumber, horse.gateNumber),
              const SizedBox(width: 8),

              // 2. 予想印
              SizedBox(
                width: 50,
                // ▼ 追加: 印が変わった時に確実に表示を更新（再構築）させるためのKey
                child: KeyedSubtree(
                  key: ValueKey('${horse.horseId}_${horse.userMark.hashCode}'),
                  child: widget.buildMarkDropdown(horse),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 13,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Text('${horse.sexAndAge ?? ""} ', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                      Text(horse.horseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                flex: 10,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('${horse.jockey} ${horse.carriedWeight}kg', style: const TextStyle(fontSize: 12, color: Colors.black87)),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 55,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(horse.odds != null ? '${horse.odds}倍' : '---', style: TextStyle(fontWeight: FontWeight.bold, color: oddsColor)),
                    const SizedBox(height: 2),
                    Text(horse.popularity != null ? '${horse.popularity}人気' : '---', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}