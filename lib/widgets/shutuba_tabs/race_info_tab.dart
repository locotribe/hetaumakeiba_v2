// lib/widgets/shutuba_tabs/race_info_tab.dart

// [削除] レーティング削除: レースレベル診断を外したので、その import（読み込み係の知らせの購読・Rt のまとめ・今回のクラス・カード）を外した (v.2026.10.18+26101803)
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/utils/grade_utils.dart';
import 'package:hetaumakeiba_v2/models/track_conditions_model.dart';
import 'package:hetaumakeiba_v2/logic/analysis/weather_analyzer.dart';
import 'package:hetaumakeiba_v2/db/course_elevations.dart';
import 'package:hetaumakeiba_v2/logic/elevation_logic.dart';
// [追加] コース平面図表示 (v.1.0)
import 'package:hetaumakeiba_v2/models/course_diagram_model.dart';
import 'package:hetaumakeiba_v2/services/course_diagram_service.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/course_diagram_painter.dart';
// [追加] T6: AIレース総評の取り込み・保存
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_memo_repository.dart';
import 'package:hetaumakeiba_v2/services/user_session.dart';
import 'package:hetaumakeiba_v2/logic/ai_export/citation_sanitizer.dart';
import 'package:hetaumakeiba_v2/utils/memo_csv_util.dart'; // [追加] AIファイル名整理: 総評ファイル名の照合 (v.2026.10.10+26101007)
// [追加] レース情報ヘッダー整理 Step2: 見出しの文字の組み立て・クッション値の評価・開閉状態の保存 (v.2026.10.15+26101510)
import 'package:hetaumakeiba_v2/logic/race_header_format.dart';
import 'package:hetaumakeiba_v2/utils/track_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
// [追加] レース情報ヘッダー整理 Step3: 風の分析の文から絵文字を外すため（保存済みの天気にも絵文字が残っている） (v.2026.10.15+26101511)
import 'package:hetaumakeiba_v2/logic/ai_export/ai_weather_snapshot.dart' show aiStripEmoji;

class RaceInfoTabWidget extends StatefulWidget {
  final PredictionRaceData predictionRaceData;
  final List<PredictionHorseDetail> horses;
  final Widget Function(PredictionHorseDetail) buildMarkDropdown;
  final Widget Function(int) buildGateNumber;
  final Widget Function(int, int) buildHorseNumber;
  // [追加] 0-9b-1 天気/馬場データ取得をshutuba_table_page.dartへ引き上げ（展開シミュタブと共有し二重取得を防ぐ） (v.2026.7.27+26072704)
  final Future<TrackConditionRecord?>? trackConditionFuture;
  final Future<Map<String, String>?>? jmaWeatherFuture;
  final Future<Map<String, dynamic>?>? pinpointWeatherFuture;
  final TrackConditionRecord? cachedPrevRecord;
  // [追加] 馬場予測の起点（レース当日より前で一番新しい計測）。予測は当日の計測で動かさない (v.2026.10.31+26103102)
  final Future<TrackConditionRecord?>? predictionBaseFuture;
  final bool isWeatherLocked;
  final VoidCallback onRefreshWeather;

  const RaceInfoTabWidget({
    super.key,
    required this.predictionRaceData,
    required this.horses,
    required this.buildMarkDropdown,
    required this.buildGateNumber,
    required this.buildHorseNumber,
    this.trackConditionFuture,
    this.jmaWeatherFuture,
    this.pinpointWeatherFuture,
    this.cachedPrevRecord,
    // [追加] 馬場予測の起点 (v.2026.10.31+26103102)
    this.predictionBaseFuture,
    this.isWeatherLocked = true,
    required this.onRefreshWeather,
  });

  @override
  State<RaceInfoTabWidget> createState() => _RaceInfoTabWidgetState();
}

class _RaceInfoTabWidgetState extends State<RaceInfoTabWidget> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // [追加] T6: AIレース総評（race_memos に保存・レース情報タブに表示） (v.2026.9.27+26092711)
  String? _aiRaceComment;

  @override
  void initState() {
    super.initState();
    _loadAiRaceComment();
    // [追加] レース情報ヘッダー整理 Step2: 折りたたみの開閉状態を端末から読む (v.2026.10.15+26101510)
    _loadExpandedStates();
    // [削除] レーティング削除: レースレベル診断の計算し直し（読み込み係の知らせの購読と dispose）、開閉の保存、Rt のまとめの計算を外した (v.2026.10.18+26101803)
  }

  // [追加] レース情報ヘッダー整理 Step2: 折りたたみの開閉（コース図・高低差／気象庁 広域天気概況／ピンポイント詳細）。キーごとに端末へ保存し、別のレースを開いても同じ状態にする。初期は開 (v.2026.10.15+26101510)
  static const String _courseExpandedKey = 'race_info_course_expanded';
  static const String _jmaExpandedKey = 'race_info_jma_expanded';
  static const String _pinpointExpandedKey = 'race_info_pinpoint_expanded';
  static final Map<String, bool> _expandedCache = {};

  bool _isExpanded(String key) => _expandedCache[key] ?? true;

  Future<void> _loadExpandedStates() async {
    const keys = [_courseExpandedKey, _jmaExpandedKey, _pinpointExpandedKey];
    // [修正] レーティング削除: レースレベル診断の開閉は読まなくなった (v.2026.10.18+26101803)
    if (keys.every(_expandedCache.containsKey)) return;
    final prefs = await SharedPreferences.getInstance();
    for (final key in keys) {
      _expandedCache[key] = prefs.getBool(key) ?? true;
    }
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleExpanded(String key) async {
    final next = !_isExpanded(key);
    setState(() => _expandedCache[key] = next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, next);
  }

  Future<void> _loadAiRaceComment() async {
    final userId = UserSession().localUserId;
    if (userId == null) return;
    final memo = await RaceMemoRepository()
        .getRaceMemo(userId, widget.predictionRaceData.raceId);
    if (!mounted) return;
    setState(() {
      // [修正] レースメモ用途分離: AI予想・買い目は aiPredictionMemo列から読む (v.2026.9.28+26092802)
      final text = memo?.aiPredictionMemo?.trim() ?? '';
      _aiRaceComment = text.isEmpty ? null : text;
    });
  }

  Future<void> _importAiRaceComment() async {
    final userId = UserSession().localUserId;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ログインが必要です。')),
      );
      return;
    }
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.single.path == null) return;
      // [追加] AIファイル名整理: 「インポート総評_…_このレースのID.txt」だけを取り込む（別のレース・別の種別のファイルの取り違え防止） (v.2026.10.10+26101007)
      final pickedName = result.files.single.name;
      if (!isImportSummaryFileNameFor(
          pickedName, widget.predictionRaceData.raceId)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'このレースの総評ファイル（インポート総評_…_${widget.predictionRaceData.raceId}.txt）を選択してください。'),
          ),
        );
        return;
      }
      final content = await File(result.files.single.path!).readAsString();
      // [追加] T8: AI出力の引用記号([cite: n]等)を除去してから保存 (v.2026.9.27+26092713)
      final text = stripCitations(content).trim();
      if (text.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ファイルが空です。')),
        );
        return;
      }
      // [修正] レースメモ用途分離: AI予想・買い目は aiPredictionMemo列へ保存し、総評(memo)は保持 (v.2026.9.28+26092802)
      await RaceMemoRepository().upsertAiPredictionMemo(
        userId: userId,
        raceId: widget.predictionRaceData.raceId,
        aiPredictionMemo: text,
      );
      await _loadAiRaceComment();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AIレース総評を取り込みました。')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('取り込みエラー: ${e.toString()}')),
      );
    }
  }

  Widget _buildAiCommentSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('AI予想・買い目',
                  style:
                      TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              OutlinedButton.icon(
                onPressed: _importAiRaceComment,
                icon: const Icon(Icons.file_download, size: 18),
                label: const Text('取り込み'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _aiRaceComment ??
                  '未取り込み（AIのレース総評テキストを「取り込み」から読み込めます）',
              style: TextStyle(
                fontSize: 12,
                color: _aiRaceComment == null ? Colors.grey : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _mapToTrackTypeKey() {
    final tt = widget.predictionRaceData.trackType ?? '';
    final dir = widget.predictionRaceData.direction ?? '';
    final inOut = widget.predictionRaceData.courseInOut ?? '';

    if (tt.contains('ダ')) return 'dirt';
    if (dir.contains('直')) return 'shiba_straight';
    if (inOut.contains('外')) return 'shiba_outer';
    if (inOut.contains('内')) return 'shiba_inner';
    return 'shiba';
  }

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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRaceHeader(context),
          const Divider(height: 1, thickness: 1),
          _buildSimpleShutubaList(context),
          const Divider(height: 1, thickness: 1),
          _buildAiCommentSection(context),
        ],
      ),
    );
  }

  Widget _buildRaceHeader(BuildContext context) {
    final gradeColor = getGradeColor(widget.predictionRaceData.raceGrade ?? '');

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          // [修正] レース情報ヘッダー整理 Step2: 取得した文字をそのまま並べるのをやめ、日付・開催・発走の行、コース・天候・馬場のタイル、条件のチップ、本賞金の行に整理した。馬場計測値は本賞金の下に常に出し、コース平面図と高低差グラフは「コース図・高低差」で折りたためるようにした (v.2026.10.15+26101510)
          const SizedBox(height: 6),
          _buildRaceDateLine(),
          const SizedBox(height: 10),
          _buildRaceSummaryTiles(),
          const SizedBox(height: 10),
          _buildRaceCategoryChips(),
          _buildBasePrizeRow(),
          // [削除] レーティング削除: 本賞金の下のレースレベル診断を外した (v.2026.10.18+26101803)
          _buildDetailedTrackCondition(),
          _buildCourseSectionHeader(),
          if (_isExpanded(_courseExpandedKey)) ...[
            // [追加] コース平面図表示 (v.1.0)
            _buildCourseDiagramSection(),
            _buildElevationChartSection(),
          ],
          const SizedBox(height: 12),
          _buildJmaWeather(),
          const SizedBox(height: 12),
          _buildPinpointWeather(),
        ],
      ),
    );
  }

  // [追加] レース情報ヘッダー整理 Step2: 日付・開催・発走時刻の行 (v.2026.10.15+26101510)
  Widget _buildRaceDateLine() {
    final data = widget.predictionRaceData;
    final dateText = formatMonthDayWithWeekday(data.raceDate) ?? data.raceDate;
    final holdingText = buildHoldingLabel(data.venue, data.holdingTimes, data.holdingDays);
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4.0,
      runSpacing: 2.0,
      children: [
        const Icon(Icons.calendar_today, size: 13, color: Colors.black54),
        Text('$dateText $holdingText', style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(width: 8),
        const Icon(Icons.schedule, size: 13, color: Colors.black54),
        Text(
          data.startTime != null ? '${data.startTime} 発走' : '発走時刻 未定',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ],
    );
  }

  // [追加] レース情報ヘッダー整理 Step2: コース・天候・馬場のタイル。天候・馬場が未発表なら「当日発表」と出す (v.2026.10.15+26101510)
  Widget _buildRaceSummaryTiles() {
    final data = widget.predictionRaceData;
    final Color trackColor = (data.trackType ?? '').contains('ダ') ? Colors.brown.shade700 : Colors.green.shade700;
    final distanceText = data.distanceValue != null ? ' ${data.distanceValue}m' : '';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildInfoTile(
              label: 'コース',
              value: Text.rich(
                TextSpan(children: [
                  TextSpan(text: buildTrackTypeLabel(data.trackType), style: TextStyle(color: trackColor)),
                  TextSpan(text: distanceText),
                ]),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              sub: buildCourseSubLabel(data.direction, data.courseInOut),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            // [修正] 天候のタイル: 発表が無いときは、ピンポイント詳細の発走時刻の予報の天気を「（予報）」つきで出す (v.2026.10.31+26103104)
            child: _buildWeatherTile(),
          ),
          const SizedBox(width: 6),
          Expanded(
            // [修正] 馬場のタイル: 発表が無いときは当日の計測の含水率から見込んだ馬場を「（含水率から）」つきで出す (v.2026.10.31+26103103)
            child: _buildTrackConditionTile(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncedValue(String? value) {
    if (value == null) {
      return const Text('当日発表', style: TextStyle(fontSize: 13, color: Colors.black45));
    }
    return Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87));
  }

  // [追加] レース日を「2026-10-31」の形で返す（馬場計測のdateと照合する）。読めなければ null (v.2026.10.31+26103103)
  String? _raceDayKey() {
    final match = RegExp(r'(\d{4})[^\d]*(\d{1,2})[^\d]*(\d{1,2})').firstMatch(widget.predictionRaceData.raceDate);
    if (match == null) return null;
    return '${match.group(1)}-${match.group(2)!.padLeft(2, '0')}-${match.group(3)!.padLeft(2, '0')}';
  }

  // [追加] 発表が無いときの馬場: 当日の計測の含水率（ゴール前と4コーナーの大きい方）から判定する。当日の計測が無い・障害・判定できないときは null (v.2026.10.31+26103103)
  String? _estimateGoingFromMoisture(TrackConditionRecord record) {
    if (record.date != _raceDayKey()) return null;
    final trackType = widget.predictionRaceData.trackType ?? '';
    if (trackType.contains('障')) return null;
    final isDirt = trackType.contains('ダ');
    final goal = (isDirt ? record.moistureDirtGoal : record.moistureTurfGoal) ?? 0.0;
    final corner4 = (isDirt ? record.moistureDirt4c : record.moistureTurf4c) ?? 0.0;
    final moisture = goal > corner4 ? goal : corner4;
    if (moisture <= 0) return null;
    final venueCode = widget.predictionRaceData.raceId.length >= 6
        ? widget.predictionRaceData.raceId.substring(4, 6)
        : '00';
    final going = TrackConstants.evaluateTrackCondition(venueCode, isDirt ? 'ダ' : '芝', moisture);
    return going == '不明' ? null : going;
  }

  // [追加] 馬場のタイル。発表があればその値、無ければ当日の計測の含水率から見込んだ馬場に「（含水率から）」を添える。どちらも無ければ「当日発表」 (v.2026.10.31+26103103)
  Widget _buildTrackConditionTile() {
    final announced = normalizeAnnouncedValue(widget.predictionRaceData.trackCondition);
    if (announced != null || widget.trackConditionFuture == null) {
      return _buildInfoTile(label: '馬場', value: _buildAnnouncedValue(announced));
    }
    return FutureBuilder<TrackConditionRecord?>(
      future: widget.trackConditionFuture,
      builder: (context, snapshot) {
        final record = snapshot.data;
        final estimated = record == null ? null : _estimateGoingFromMoisture(record);
        if (estimated == null) {
          return _buildInfoTile(label: '馬場', value: _buildAnnouncedValue(null));
        }
        return _buildInfoTile(label: '馬場', value: _buildAnnouncedValue(estimated), sub: '（含水率から）');
      },
    );
  }

  // [追加] 天候のタイル。発表があればその値、無ければピンポイント詳細の発走時刻の予報の天気に「（予報）」を添える。どちらも無ければ「当日発表」 (v.2026.10.31+26103104)
  Widget _buildWeatherTile() {
    final announced = normalizeAnnouncedValue(widget.predictionRaceData.weather);
    if (announced != null || widget.pinpointWeatherFuture == null) {
      return _buildInfoTile(label: '天候', value: _buildAnnouncedValue(announced));
    }
    return FutureBuilder<Map<String, dynamic>?>(
      future: widget.pinpointWeatherFuture,
      builder: (context, snapshot) {
        final raceTime = snapshot.data?['raceTime'];
        if (raceTime == null) {
          return _buildInfoTile(label: '天候', value: _buildAnnouncedValue(null));
        }
        return _buildInfoTile(
          label: '天候',
          value: _buildAnnouncedValue(WeatherAnalyzer.getWeatherText(raceTime['weatherCode'] ?? 0)),
          sub: '（予報）',
        );
      },
    );
  }

  // [追加] 馬場計測値カードの4項目（馬場回復・悪化予測／馬のスタミナ負荷／展開・波乱要因／馬場の状態）。当日の計測が入ってから出す。計測値なので予測シミュレーションの根拠は出さない (v.2026.10.31+26103103)
  Widget _buildMeasuredInsights(TrackConditionRecord record) {
    if (record.date != _raceDayKey() || widget.pinpointWeatherFuture == null) return const SizedBox.shrink();
    final isDirt = (widget.predictionRaceData.trackType ?? '').contains('ダ');
    final measuredMoisture = isDirt ? record.moistureDirtGoal : record.moistureTurfGoal;

    return FutureBuilder<Map<String, dynamic>?>(
      future: widget.pinpointWeatherFuture,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final raceTime = data?['raceTime'];
        if (data == null || raceTime == null) return const SizedBox.shrink();
        final List<dynamic> dailyData = data['daily'] ?? [];
        final analysisResult = _analyzeTrackInsights(record, raceTime, dailyData);

        final insightsList = <WeatherInsight>[
          WeatherAnalyzer.analyzeTrackRecovery(raceTime['radiation'] ?? 0.0, raceTime['evap'] ?? 0.0),
          WeatherAnalyzer.analyzeHorseStamina(raceTime['apparentTemp'] ?? 0.0, (raceTime['humidity'] ?? 0).toDouble()),
          WeatherAnalyzer.analyzeRaceRisk((raceTime['gusts'] ?? 0.0) / 3.6, raceTime['visibility'] ?? 20.0),
          ...analysisResult.insights.map((insight) => WeatherInsight(
                label: insight.label,
                value: measuredMoisture != null ? '計測含水率: G $measuredMoisture%' : insight.value,
                description: insight.description.split('\n\n【予測シミュレーションの根拠】').first,
                color: insight.color,
              )),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 10),
            ...insightsList.map(_buildMeasuredInsightBox),
          ],
        );
      },
    );
  }

  // [追加] 馬場計測値カードの4項目の1つ分の枠（ピンポイント詳細の馬場・展開インサイトと同じ見た目） (v.2026.10.31+26103103)
  Widget _buildMeasuredInsightBox(WeatherInsight insight) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: insight.color.withOpacity(0.05),
        border: Border(left: BorderSide(color: insight.color, width: 4)),
        borderRadius: const BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(insight.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: insight.color)),
              Text(insight.value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 4),
          Text(insight.description, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildInfoTile({required String label, required Widget value, String sub = ''}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
          const SizedBox(height: 2),
          value,
          if (sub.isNotEmpty)
            Text(sub, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        ],
      ),
    );
  }

  // [追加] レース情報ヘッダー整理 Step2: 競走条件と頭数のチップ（例: 3歳以上・オープン・国際・指定・別定・14頭） (v.2026.10.15+26101510)
  Widget _buildRaceCategoryChips() {
    final data = widget.predictionRaceData;
    final chips = <String>[
      ...buildRaceCategoryChips(data.raceCategory),
      if (data.horseCount != null) '${data.horseCount}頭',
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4.0,
      runSpacing: 4.0,
      children: chips
          .map((chip) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Text(chip, style: const TextStyle(fontSize: 12, color: Colors.black87)),
              ))
          .toList(),
    );
  }

  // [追加] レース情報ヘッダー整理 Step2: 本賞金の行。1着を太字で出し、2着以下を小さく並べる。1着が無いときは出さない (v.2026.10.15+26101510)
  Widget _buildBasePrizeRow() {
    final data = widget.predictionRaceData;
    if ((data.basePrize1st ?? 0) <= 0) return const SizedBox.shrink();
    final others = [data.basePrize2nd, data.basePrize3rd, data.basePrize4th, data.basePrize5th]
        .map(formatPrizeMan)
        .join(' ／ ');
    return Container(
      margin: const EdgeInsets.only(top: 8.0),
      padding: const EdgeInsets.only(top: 8.0),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          const Text('本賞金', style: TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: '1着 ${formatPrizeMan(data.basePrize1st)}万',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                TextSpan(
                  text: ' ／ $others',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ]),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // [削除] レーティング削除: 「レースレベル診断」の見出しとカード（_buildRaceLevelSection）を外した (v.2026.10.18+26101803)

  // [追加] レース情報ヘッダー整理 Step2: 数値のタイル（馬場計測値と、ピンポイント詳細の要約で使う）。dimmed は今回のレースに関係の薄い値を薄く出す (v.2026.10.15+26101510)
  Widget _buildMeasureTile({
    required String label,
    required List<String> lines,
    bool big = false,
    String note = '',
    Color? noteColor,
    bool dimmed = false,
  }) {
    final Color valueColor = dimmed ? Colors.black38 : Colors.black87;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
          const SizedBox(height: 2),
          ...lines.map((line) => Text(
                line,
                style: TextStyle(fontSize: big ? 20 : 13, fontWeight: FontWeight.bold, color: valueColor),
              )),
          if (note.isNotEmpty)
            Text(
              note,
              style: TextStyle(fontSize: 10, color: dimmed ? Colors.black38 : (noteColor ?? Colors.black54)),
            ),
        ],
      ),
    );
  }

  // [追加] レース情報ヘッダー整理 Step2: 「コース図・高低差」の見出し。行全体のタップで平面図と高低差グラフを開閉する。平面図・グラフと同じく、レースIDか距離が読めないときは出さない (v.2026.10.15+26101510)
  Widget _buildCourseSectionHeader() {
    final distance = int.tryParse(widget.predictionRaceData.distanceValue?.toString() ?? '');
    if (widget.predictionRaceData.raceId.length < 6 || distance == null) return const SizedBox.shrink();
    final expanded = _isExpanded(_courseExpandedKey);
    return Container(
      margin: const EdgeInsets.only(top: 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _toggleExpanded(_courseExpandedKey),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.map_outlined, size: 16, color: Colors.green.shade700),
              const SizedBox(width: 6),
              const Expanded(
                child: Text('コース図・高低差', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
              ),
              Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.grey.shade700),
            ],
          ),
        ),
      ),
    );
  }

  // [追加] コース平面図表示 (v.1.0)
  Widget _buildCourseDiagramSection() {
    final venueCode = widget.predictionRaceData.raceId.length >= 6
        ? widget.predictionRaceData.raceId.substring(4, 6)
        : null;

    final distance = int.tryParse(widget.predictionRaceData.distanceValue?.toString() ?? '');

    if (venueCode == null || distance == null) return const SizedBox.shrink();

    final trackTypeKey = _mapToTrackTypeKey();

    // [追加] シュート（引き込み線）の動的描画対応 (v.1.0)
    // RaceCourseData.approachPathから合流点までの相対ベクトル(角度・距離)を取得し、Painterへ渡す
    var raceCourse = CourseElevations.findRaceCourse(venueCode, distance, trackTypeKey);
    if (raceCourse == null && trackTypeKey == 'shiba') {
      raceCourse = CourseElevations.findRaceCourse(venueCode, distance, 'shiba_inner');
    }
    final approachPaths = raceCourse?.approachPath;

    return FutureBuilder<CourseDiagramData?>(
      future: CourseDiagramService.instance.getCourseDiagram(venueCode, distance, trackTypeKey),
      builder: (context, snapshot) {
        final diagram = snapshot.data;
        if (diagram == null) return const SizedBox.shrink();

        return Container(
          margin: const EdgeInsets.only(top: 16.0, bottom: 8.0),
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return AspectRatio(
                aspectRatio: diagram.imageInfo.width / diagram.imageInfo.height,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.asset(diagram.imageAsset, fit: BoxFit.contain),
                    ),
                    Positioned.fill(
                      child: CustomPaint(
                        painter: CourseDiagramPainter(
                          diagram: diagram,
                          raceDistance: distance,
                          approachPaths: approachPaths, // [追加] シュート（引き込み線）の動的描画対応 (v.1.0)
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildElevationChartSection() {
    final venueCode = widget.predictionRaceData.raceId.length >= 6
        ? widget.predictionRaceData.raceId.substring(4, 6)
        : null;

    final distance = int.tryParse(widget.predictionRaceData.distanceValue?.toString() ?? '');

    if (venueCode == null || distance == null) return const SizedBox.shrink();

    final trackTypeKey = _mapToTrackTypeKey();
    var raceCourse = CourseElevations.findRaceCourse(venueCode, distance, trackTypeKey);

    // [追加] JRAのraceData01表記では内回りがデフォルトで明記されず、外回りのみ「外」が
    // 付与されるため、courseInOutに「外」「内」「直」のいずれも含まれない場合
    // (=trackTypeKeyが'shiba'のまま)で見つからない時は内回りとして再検索する。
    // 内外回りの区別がないコース(東京・小倉・福島・函館・札幌・中京)は
    // 'shiba'キーで一致するため、このフォールバックは発火しない。 (v.13.41.2)
    if (raceCourse == null && trackTypeKey == 'shiba') {
      raceCourse = CourseElevations.findRaceCourse(venueCode, distance, 'shiba_inner');
    }

    if (raceCourse == null) return const SizedBox.shrink();

    final drawData = ElevationLogic.generateRaceChartData(raceCourse);

    return Container(
      margin: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 32, right: 8, bottom: 4),
            child: SizedBox(
              height: 30,
              child: Row(
                children: drawData.displaySections.map((sec) {
                  final d = sec.endDistance - sec.startDistance;
                  return Expanded(
                    flex: (d * 10).toInt(),
                    child: Center(
                      child: Text(
                        ElevationLogic.translateSectionName(sec.name),
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black54),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(
            height: 140,
            child: _buildRaceChart(raceCourse, drawData),
          ),
        ],
      ),
    );
  }

  Widget _buildRaceChart(RaceCourseData race, ChartDrawData drawData) {
    final raceDist = race.raceDistance.toDouble();
    double minY = drawData.spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 1.0;
    double maxY = drawData.spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 1.5;

    final List<VerticalLine> vLines = [];
    final List<VerticalRangeAnnotation> ranges = [];
    final stripeColors = [Colors.black.withValues(alpha: 0.01), Colors.black.withValues(alpha: 0.03)];

    for (int i = 0; i < drawData.displaySections.length; i++) {
      final sec = drawData.displaySections[i];
      vLines.add(VerticalLine(x: sec.startDistance, color: Colors.black12, strokeWidth: 0.5, dashArray: [4, 4]));
      ranges.add(VerticalRangeAnnotation(x1: sec.startDistance, x2: sec.endDistance, color: stripeColors[i % 2]));
    }

    // 右回りコースはx軸が反転しているため、スタート(青)/ゴール(赤)の
    // ラインも左右を入れ替える。
    final startX = race.isLeftHanded ? 0.0 : raceDist;
    final goalX = race.isLeftHanded ? raceDist : 0.0;
    vLines.add(VerticalLine(x: startX, color: Colors.blueAccent.withValues(alpha: 0.5), strokeWidth: 2));
    vLines.add(VerticalLine(x: goalX, color: Colors.redAccent.withValues(alpha: 0.5), strokeWidth: 2));

    return LineChart(
      LineChartData(
        minX: 0, maxX: raceDist, minY: minY, maxY: maxY,
        gridData: FlGridData(
          show: true,
          verticalInterval: 200,
          horizontalInterval: 0.5,
          getDrawingVerticalLine: (_) => const FlLine(color: Colors.black12, strokeWidth: 0.5),
          getDrawingHorizontalLine: (value) {
            if (value % 1.0 == 0.0) {
              return FlLine(color: Colors.blueAccent.withValues(alpha: 0.3), strokeWidth: 0.8);
            }
            return const FlLine(color: Colors.black12, strokeWidth: 0.5, dashArray: [3, 3]);
          },
        ),
        rangeAnnotations: RangeAnnotations(verticalRangeAnnotations: ranges),
        extraLinesData: ExtraLinesData(verticalLines: vLines),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, reservedSize: 22, interval: 400,
              getTitlesWidget: (val, _) {
                if (val < 0 || val > raceDist) return const SizedBox.shrink();
                // 右回りコースはx軸が反転している(x=0がゴール側)ため、
                // 距離表示も「スタートからの距離」になるよう反転させる。
                final displayVal = race.isLeftHanded ? val : raceDist - val;
                return Text('${displayVal.toInt()}m', style: const TextStyle(color: Colors.black38, fontSize: 8));
              },
            ),
          ),
          leftTitles: AxisTitles(
              sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  interval: 0.5,
                  getTitlesWidget: (v, _) => Text('${v.toStringAsFixed(1)}m', style: const TextStyle(color: Colors.black38, fontSize: 8))
              )
          ),
        ),
        lineBarsData: [LineChartBarData(
            spots: drawData.spots,
            isCurved: true,
            gradient: drawData.lineGradient,
            barWidth: 2.0,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, gradient: drawData.areaGradient)
        )],
        lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => Colors.black87,
                getTooltipItems: (ss) => ss.map((s) {
                  // 右回りコースはx軸が反転している(x=0がゴール側)ため、
                  // ツールチップの距離表示も「スタートからの距離」になるよう反転させる。
                  final displayX = race.isLeftHanded ? s.x : raceDist - s.x;
                  return LineTooltipItem('${displayX.toInt()}m\n${s.y.toStringAsFixed(2)}m', const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold));
                }).toList()
            )
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.black12)),
      ),
    );
  }

  Widget _buildDetailedTrackCondition() {
    if (widget.trackConditionFuture == null) return const SizedBox.shrink();

    return FutureBuilder<TrackConditionRecord?>(
      future: widget.trackConditionFuture,
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
        // [修正] レース情報ヘッダー整理 Step2: 見出しを「馬場計測値」＋右端に計測日にし、3つの値をタイルで並べた。今回のレースに関係の薄い方（芝なら ダ含水率、ダートなら クッション値と芝含水率）は薄く出す (v.2026.10.15+26101510)
        final dateText = formatMonthDayWithWeekday(record.date) ?? record.date.replaceAll('-', '/');
        final isDirt = (widget.predictionRaceData.trackType ?? '').contains('ダ');
        final cushionEval = record.cushionValue != null ? TrackConstants.getCushionEvaluation(record.cushionValue!) : '';

        return Container(
          margin: const EdgeInsets.only(top: 12.0),
          padding: const EdgeInsets.only(top: 10.0),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Colors.grey.shade300)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.grass, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  const Text('馬場計測値', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const Spacer(),
                  Text('$dateText 計測', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                ],
              ),
              const SizedBox(height: 6),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _buildMeasureTile(
                        label: 'クッション値',
                        lines: ['${record.cushionValue ?? "-"}'],
                        big: true,
                        note: cushionEval,
                        noteColor: Colors.green.shade700,
                        dimmed: isDirt,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMeasureTile(
                        label: '芝含水率',
                        lines: ['G ${record.moistureTurfGoal ?? "-"}%', '4C ${record.moistureTurf4c ?? "-"}%'],
                        dimmed: isDirt,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildMeasureTile(
                        label: 'ダ含水率',
                        lines: ['G ${record.moistureDirtGoal ?? "-"}%', '4C ${record.moistureDirt4c ?? "-"}%'],
                        dimmed: !isDirt,
                      ),
                    ),
                  ],
                ),
              ),
              // [追加] 当日の計測が入ってから、4項目を計測値の下に出す (v.2026.10.31+26103103)
              _buildMeasuredInsights(record),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJmaWeather() {
    return FutureBuilder<Map<String, String>?>(
      future: widget.jmaWeatherFuture,
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
              // [修正] レース情報ヘッダー整理 Step3: 見出しの行のタップで開閉する。たたむと見出しと発表時刻だけを出す (v.2026.10.15+26101511)
              InkWell(
                onTap: () => _toggleExpanded(_jmaExpandedKey),
                child: Row(
                  children: [
                    const Icon(Icons.public, size: 16, color: Colors.blue),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text('気象庁 広域天気概況', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ),
                    Text('${data['reportDatetime']} 発表', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    const SizedBox(width: 4),
                    Icon(_isExpanded(_jmaExpandedKey) ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.grey.shade700),
                  ],
                ),
              ),
              if (_isExpanded(_jmaExpandedKey)) ...[
                const SizedBox(height: 8),
                Text(
                  data['overviewText'] ?? '',
                  style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.4),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildWeeklyWeather(List<dynamic> dailyData) {
    if (dailyData.isEmpty) return const SizedBox.shrink();

    DateTime? raceDate;
    final rMatch = RegExp(r'(\d{4})[^\d]*(\d{1,2})[^\d]*(\d{1,2})').firstMatch(widget.predictionRaceData.raceDate);
    if (rMatch != null) {
      raceDate = DateTime(int.parse(rMatch.group(1)!), int.parse(rMatch.group(2)!), int.parse(rMatch.group(3)!));
    }

    List<dynamic> targetWeekData = dailyData;
    if (raceDate != null) {
      final monday = raceDate.subtract(Duration(days: raceDate.weekday - 1));
      final sunday = monday.add(const Duration(days: 6));

      targetWeekData = dailyData.where((d) {
        final dateDt = DateTime.tryParse(d['date']);
        if (dateDt == null) return false;
        final compareDate = DateTime(dateDt.year, dateDt.month, dateDt.day);
        return !compareDate.isBefore(monday) && !compareDate.isAfter(sunday);
      }).toList();
    }

    if (targetWeekData.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // [修正] レース情報ヘッダー整理 Step3: 見出しの先頭の絵文字を外した (v.2026.10.15+26101511)
        const Text('レース開催週の天候推移', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: targetWeekData.map((d) {
              final dateDt = DateTime.tryParse(d['date']);
              final dateStr = dateDt != null ? '${dateDt.month}/${dateDt.day}' : d['date'];
              final precip = (d['precipitationSum'] as num).toDouble();
              return Container(
                width: 55,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    Text(dateStr, style: const TextStyle(fontSize: 10, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(WeatherAnalyzer.getWeatherText(d['weatherCode']).substring(0, 1), style: const TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${d['tempMax'].toStringAsFixed(0)}/${d['tempMin'].toStringAsFixed(0)}', style: const TextStyle(fontSize: 9, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text(precip > 0 ? '${precip}mm' : '-', style: TextStyle(fontSize: 9, fontWeight: precip > 0 ? FontWeight.bold : FontWeight.normal, color: precip > 0 ? Colors.blue : Colors.black38)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // [追加] JRA発表予測の専用バッジUI (v.4.0)
  Widget _buildJraPredictionBadge(JraConditionPrediction prediction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: prediction.color.withOpacity(0.08),
        border: Border.all(color: prediction.color.withOpacity(0.6), width: 1.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.flag, color: prediction.color, size: 20),
          const SizedBox(width: 8),
          // [修正] JRAの公式予測ではなくアプリの計算による予測なので、ラベルを「馬場予測:」にした (v.2026.10.31+26103102)
          const Text("馬場予測:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black54)),
          const SizedBox(width: 8),
          Text(prediction.conditionText, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: prediction.color)),
          if (prediction.leaningText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 2),
              child: Text(prediction.leaningText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: prediction.color.withOpacity(0.8))),
            ),
        ],
      ),
    );
  }

  Widget _buildPinpointWeather() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: widget.pinpointWeatherFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData) return const SizedBox.shrink();

        final data = snapshot.data!;
        final current = data['current'];
        final raceTime = data['raceTime'];
        final List<dynamic> timeline = data['timeline'] ?? [];
        final List<dynamic> dailyData = data['daily'] ?? [];

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
              // [修正] レース情報ヘッダー整理 Step3: 見出しの行のタップで開閉する。たたむと要約（_buildPinpointSummary）だけを出す。開いたときの中身は変えていない (v.2026.10.15+26101511)
              InkWell(
                onTap: () => _toggleExpanded(_pinpointExpandedKey),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.teal),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text('${widget.predictionRaceData.venue}競馬場 ピンポイント詳細', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.teal)),
                    ),
                    if (widget.isWeatherLocked)
                      const Text('当時のデータ', style: TextStyle(fontSize: 10, color: Colors.grey))
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20, color: Colors.teal),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: widget.onRefreshWeather,
                      ),
                    const SizedBox(width: 4),
                    Icon(_isExpanded(_pinpointExpandedKey) ? Icons.expand_less : Icons.expand_more, size: 20, color: Colors.grey.shade700),
                  ],
                ),
              ),
              if (!_isExpanded(_pinpointExpandedKey))
                _buildPinpointSummary(data),
              if (_isExpanded(_pinpointExpandedKey)) ...[
              const Divider(),

              if (dailyData.isNotEmpty)
                _buildWeeklyWeather(dailyData),

              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // [修正] レース情報ヘッダー整理 Step3: 見出しの先頭の絵文字を外した (v.2026.10.15+26101511)
                  const Text('現在の状況', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('(${current['time']} 現在)', style: const TextStyle(fontSize: 10, color: Colors.black54)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16.0,
                runSpacing: 8.0,
                children: [
                  _buildTrackConditionItem('天気', WeatherAnalyzer.getWeatherText(current['weatherCode'] ?? 0)),
                  _buildTrackConditionItem('気温', '${current['temp']}℃'),
                  _buildTrackConditionItem('湿度', '${current['humidity']}%'),
                  _buildTrackConditionItem('降水量', '${current['precipitation']} mm'),
                  // [修正] 風速表示・回顧メモ文言: Open-Meteo の風速は km/h なので 3.6 で割って m/s で表示（小数1桁） (v.2026.10.14+26101405)
                  _buildTrackConditionItem('風速', '${(((current['windSpeed'] as num?)?.toDouble() ?? 0.0) / 3.6).toStringAsFixed(1)} m/s'),
                  _buildTrackConditionItem('風向き', current['windDirText']),
                ],
              ),
              const SizedBox(height: 12),
              // [修正] レース情報ヘッダー整理 Step3: 見出しの先頭の絵文字を外した (v.2026.10.15+26101511)
              Text('発走時刻 (${_getFormattedRaceTime()}) の予報', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16.0,
                runSpacing: 8.0,
                children: [
                  _buildTrackConditionItem('天気', WeatherAnalyzer.getWeatherText(raceTime['weatherCode'] ?? 0)),
                  _buildTrackConditionItem('気温', '${raceTime['temp']}℃'),
                  _buildTrackConditionItem('湿度', '${raceTime['humidity']}%'),
                  _buildTrackConditionItem('降水確率', '${raceTime['pop']}%'),
                  _buildTrackConditionItem('降水量', '${raceTime['precipitation']} mm'),
                  // [修正] 風速表示・回顧メモ文言: km/h を m/s に換算して表示（小数1桁） (v.2026.10.14+26101405)
                  _buildTrackConditionItem('風速', '${(((raceTime['windSpeed'] as num?)?.toDouble() ?? 0.0) / 3.6).toStringAsFixed(1)} m/s'),
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
                  // [修正] レース情報ヘッダー整理 Step3: 絵文字を外して出す。端末に保存済みの天気（当時のデータ）の文にも絵文字が残っているので、表示の時に外す (v.2026.10.15+26101511)
                  aiStripEmoji('${data['windAnalysis'] ?? ''}'),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange.shade900),
                ),
              ),

              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // [修正] レース情報ヘッダー整理 Step3: 見出しの先頭の絵文字を外した (v.2026.10.15+26101511)
                  const Text('馬場・展開インサイト', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('(${widget.predictionRaceData.startTime ?? "15:45"}の予報に基づく)',
                      style: const TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.normal)),
                ],
              ),
              const SizedBox(height: 8),

              FutureBuilder<TrackConditionRecord?>(
                // [修正] 予測の起点は、レース当日より前の計測（無ければ最新の計測）にする。当日の計測が入っても予測が動かない (v.2026.10.31+26103102)
                future: widget.predictionBaseFuture ?? widget.trackConditionFuture,
                builder: (context, trackSnapshot) {
                  final trackRecord = trackSnapshot.data;
                  // [修正] レース情報ヘッダー整理 Step3: 計算を _analyzeTrackInsights に移した（たたんだときの要約と同じ結果を使うため。引数は元のまま） (v.2026.10.15+26101511)
                  final analysisResult = _analyzeTrackInsights(trackRecord, raceTime, dailyData);

                  final insightsList = [
                    WeatherAnalyzer.analyzeTrackRecovery(raceTime['radiation'] ?? 0.0, raceTime['evap'] ?? 0.0),
                    WeatherAnalyzer.analyzeHorseStamina(raceTime['apparentTemp'] ?? 0.0, (raceTime['humidity'] ?? 0).toDouble()),
                    WeatherAnalyzer.analyzeRaceRisk((raceTime['gusts'] ?? 0.0) / 3.6, raceTime['visibility'] ?? 20.0),
                    ...analysisResult.insights,
                  ];

                  return Column(
                    children: [
                      // JRA予測バッジをインサイト一覧の先頭に表示
                      if (analysisResult.jraPrediction != null)
                        _buildJraPredictionBadge(analysisResult.jraPrediction!),

                      ...insightsList.map((insight) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: insight.color.withOpacity(0.05),
                          border: Border(left: BorderSide(color: insight.color, width: 4)),
                          borderRadius: const BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(insight.label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: insight.color)),
                                Text(insight.value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(insight.description, style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3)),
                          ],
                        ),
                      )),
                    ],
                  );
                },
              ),

              const SizedBox(height: 16),
              // [修正] レース情報ヘッダー整理 Step3: 見出しの先頭の絵文字を外した (v.2026.10.15+26101511)
              const Text('午後の時系列変化', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: timeline.map((t) {
                    final double precip = (t['precipitation'] as num?)?.toDouble() ?? 0.0;
                    return Container(
                      width: 50,
                      margin: const EdgeInsets.only(right: 8),
                      child: Column(
                        children: [
                          Text(t['time'], style: const TextStyle(fontSize: 10, color: Colors.black54)),
                          const SizedBox(height: 4),
                          Text(WeatherAnalyzer.getWeatherText(t['weatherCode'] ?? 0).substring(0, 1), style: const TextStyle(fontSize: 10, color: Colors.black87)),
                          const SizedBox(height: 2),
                          Text('${t['temp']}℃', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text('${t['pop']}%', style: const TextStyle(fontSize: 10, color: Colors.blue)),
                          if (precip > 0)
                            Text('${precip}mm', style: const TextStyle(fontSize: 10, color: Colors.lightBlue)),
                          // [修正] 風速表示・回顧メモ文言: km/h を m/s に換算し、単位を「m/s」にする（小数1桁） (v.2026.10.14+26101405)
                          Text('${(((t['windSpeed'] as num?)?.toDouble() ?? 0.0) / 3.6).toStringAsFixed(1)}m/s', style: const TextStyle(fontSize: 10, color: Colors.teal)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              ],
            ],
          ),
        );
      },
    );
  }

  // [追加] レース情報ヘッダー整理 Step3: 馬場・展開インサイトの計算（開いたときの一覧と、たたんだときの要約で同じ結果を使う） (v.2026.10.15+26101511)
  WeatherAnalysisResult _analyzeTrackInsights(TrackConditionRecord? trackRecord, dynamic raceTime, List<dynamic> dailyData) {
    final String venueCode = widget.predictionRaceData.raceId.length >= 6
        ? widget.predictionRaceData.raceId.substring(4, 6)
        : '00';

    // [修正] 返却型 WeatherAnalysisResult の展開と UI統合 (v.4.0)
    return WeatherAnalyzer.analyzeTrackConditionInsights(
      venueCode: venueCode,
      trackType: widget.predictionRaceData.trackType ?? '芝',
      currentRecord: trackRecord,
      // [修正] 起点が動かないので「前回予測」との2本立てはやめ、予測は1本にする (v.2026.10.31+26103102)
      cachedRecord: null,
      expectedPrecipitation: (raceTime['precipitation'] as num?)?.toDouble() ?? 0.0,
      expectedRadiation: (raceTime['radiation'] as num?)?.toDouble() ?? 0.0,
      expectedSoilMoisture: (raceTime['soilMoisture'] as num?)?.toDouble(),
      dailyWeather: dailyData,
      raceDateStr: widget.predictionRaceData.raceDate,
    );
  }

  // [追加] レース情報ヘッダー整理 Step3: ピンポイント詳細をたたんだときの要約。発走時刻の予報（天気・気温・降水確率・風）、馬場予測（芝は予測クッション値→予測含水率、ダートは予測含水率だけ）、今回の馬場予測の見出しと説明（根拠より前の部分）を出す (v.2026.10.15+26101511)
  Widget _buildPinpointSummary(Map<String, dynamic> data) {
    final raceTime = data['raceTime'];
    final List<dynamic> dailyData = data['daily'] ?? [];
    final isDirt = (widget.predictionRaceData.trackType ?? '').contains('ダ');
    final windMs = (((raceTime['windSpeed'] as num?)?.toDouble() ?? 0.0) / 3.6).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('発走時刻 (${_getFormattedRaceTime()}) の予報', style: const TextStyle(fontSize: 11, color: Colors.black54)),
        const SizedBox(height: 4),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildMeasureTile(label: '天気', lines: [WeatherAnalyzer.getWeatherText(raceTime['weatherCode'] ?? 0)])),
              const SizedBox(width: 6),
              Expanded(child: _buildMeasureTile(label: '気温', lines: ['${raceTime['temp']}℃'])),
              const SizedBox(width: 6),
              Expanded(child: _buildMeasureTile(label: '降水確率', lines: ['${raceTime['pop']}%'])),
              const SizedBox(width: 6),
              Expanded(child: _buildMeasureTile(label: '風', lines: ['$windMs m/s'], note: '${data['windDirText'] ?? ''}')),
            ],
          ),
        ),
        FutureBuilder<TrackConditionRecord?>(
          // [修正] 予測の起点は、レース当日より前の計測（無ければ最新の計測）にする (v.2026.10.31+26103102)
          future: widget.predictionBaseFuture ?? widget.trackConditionFuture,
          builder: (context, trackSnapshot) {
            final analysisResult = _analyzeTrackInsights(trackSnapshot.data, raceTime, dailyData);
            final moisture = analysisResult.predictedMoisture;
            if (moisture == null) return const SizedBox.shrink();
            final cushion = analysisResult.predictedCushion;
            WeatherInsight? current;
            for (final insight in analysisResult.insights) {
              if (!insight.label.startsWith('[前回予測]')) current = insight;
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                const Text('馬場予測', style: TextStyle(fontSize: 11, color: Colors.black54)),
                const SizedBox(height: 4),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isDirt && cushion != null) ...[
                        Expanded(child: _buildMeasureTile(label: '予測クッション値', lines: [cushion.toStringAsFixed(1)], big: true)),
                        const SizedBox(width: 6),
                      ],
                      Expanded(child: _buildMeasureTile(label: '予測含水率', lines: ['${moisture.toStringAsFixed(1)}%'], big: true)),
                      if (isDirt || cushion == null) ...[
                        const SizedBox(width: 6),
                        const Expanded(child: SizedBox.shrink()),
                      ],
                    ],
                  ),
                ),
                if (current != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: current.color.withValues(alpha: 0.05),
                      border: Border(left: BorderSide(color: current.color, width: 4)),
                      borderRadius: const BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          current.label.replaceFirst('[今回確定] ', ''),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: current.color),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          current.description.split('\n\n').first,
                          style: const TextStyle(fontSize: 12, color: Colors.black87, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildTrackConditionItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.black54)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }

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
              widget.buildHorseNumber(horse.horseNumber, horse.gateNumber),
              const SizedBox(width: 8),
              SizedBox(
                width: 50,
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