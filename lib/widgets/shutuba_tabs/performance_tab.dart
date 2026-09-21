// lib/widgets/shutuba_tabs/performance_tab.dart

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_past_race_extra_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/user_repository.dart';
import 'package:hetaumakeiba_v2/logic/race_data_parser.dart';
import 'package:hetaumakeiba_v2/logic/race_interval_analyzer.dart';
import 'package:hetaumakeiba_v2/services/user_session.dart';
import 'package:hetaumakeiba_v2/models/horse_past_race_extra_model.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/user_mark_model.dart';
import 'package:hetaumakeiba_v2/screens/shutuba_table_page.dart';
import 'package:hetaumakeiba_v2/utils/grade_utils.dart';
import 'package:hetaumakeiba_v2/widgets/shutuba_tabs/info_tab.dart';

// [修正] 成績タブ拡充: 過去走カードに条件・コース区分・ペース・前後半3F・通過順注記・上がり順位・
// 勝ち馬・タイム指数・備考などを追加し7行表示にした。表示方法（ハイライト・左端の色帯・着順背景）は従来どおり (v.2026.9.22+26092203)

/// 表示する過去走の数
const int _kPastRaceCount = 5;

// [追加] 出馬表UI調整: 列幅の定数 (v.2026.9.22+26092206)
/// 縦書きの馬名列の幅
const double _kNameColumnWidth = 28;
/// 間隔/距離列の幅（見出しを2行にして70→46）
const double _kIntervalColumnWidth = 46;
/// 過去走カード1枚あたりの目安幅（最小幅の計算用。従来の表示幅と同程度）
const double _kPastCardWidth = 270;

class _PerformanceData {
  final List<HorseRaceRecord> records;
  final Map<String, RaceResult> raceResults;
  final Map<String, HorsePastRaceExtra> extras;

  _PerformanceData(this.records, this.raceResults, this.extras);
}

class PerformanceTabWidget extends StatelessWidget {
  final PredictionRaceData predictionRaceData;
  final List<PredictionHorseDetail> horses;
  final Function(SortableColumn) onSort;
  final Widget Function(PredictionHorseDetail) buildMarkDropdown;
  // [修正] 左2列の固定と最小幅の指定のため、共通の表生成関数に追加された任意引数を受け取れる型にする (v.2026.9.22+26092206)
  final Widget Function({
  required List<DataColumn2> columns,
  required List<PredictionHorseDetail> horses,
  required List<DataCell> Function(PredictionHorseDetail horse) cellBuilder,
  int fixedLeftColumns,
  double? minWidth,
  }) buildDataTableForTab;

  final String? highlightedRaceId;
  final Function(String) onRaceHighlightChanged;

  final HorseRepository _horseRepo = HorseRepository();
  final RaceRepository _raceRepo = RaceRepository();
  final UserRepository _userRepo = UserRepository();
  final HorsePastRaceExtraRepository _extraRepo = HorsePastRaceExtraRepository();

  PerformanceTabWidget({
    Key? key,
    required this.predictionRaceData,
    required this.horses,
    required this.onSort,
    required this.buildMarkDropdown,
    required this.buildDataTableForTab,
    required this.highlightedRaceId,
    required this.onRaceHighlightChanged,
  }) : super(key: key);

  static String _pastRaceLabel(int index) {
    if (index == 0) return '前走';
    if (index == 1) return '前々走';
    return '${index + 1}走前';
  }

  @override
  Widget build(BuildContext context) {
    // [修正] 出馬表UI調整: 馬名を縦書きの細い列にし、印・枠と馬名の左2列を固定。
    // 間隔/距離列は見出しを2行にして幅を縮小。取消馬は行全体をグレーアウト (v.2026.9.22+26092206)
    const double fixedColumnsWidth = 40 + _kNameColumnWidth + _kIntervalColumnWidth * _kPastRaceCount;
    const int columnCount = 2 + _kPastRaceCount * 2;
    const double tableMinWidth =
        fixedColumnsWidth + _kPastCardWidth * _kPastRaceCount + 6.0 * (columnCount - 1) + 4;
    return buildDataTableForTab(
      fixedLeftColumns: 2,
      minWidth: tableMinWidth,
      columns: [
        DataColumn2(label: const Text('印\n枠'), fixedWidth: 40, onSort: (i, asc) => onSort(SortableColumn.horseNumber)),
        DataColumn2(
          label: const Text('馬\n名', textAlign: TextAlign.center),
          fixedWidth: _kNameColumnWidth,
          onSort: (i, asc) => onSort(SortableColumn.horseName),
        ),
        for (int i = 0; i < _kPastRaceCount; i++) ...[
          const DataColumn2(
            label: Text('間隔\n距離', textAlign: TextAlign.center),
            fixedWidth: _kIntervalColumnWidth,
          ),
          DataColumn2(label: Text(_pastRaceLabel(i))),
        ],
      ],
      horses: horses,
      cellBuilder: (horse) {
        final cells = <DataCell>[
          DataCell(MarkAndGateCell(horse: horse, buildMarkDropdown: buildMarkDropdown)),
          // [修正] 馬名セルの背景を、出走馬タブの所属列と同じ所属色（美浦=薄い青 / 栗東=薄い赤 等）にする (v.2026.9.22+26092207)
          DataCell(_VerticalHorseName(
            name: horse.horseName,
            backgroundColor: _getAffiliationColor(horse.trainerAffiliation),
          )),
          ..._buildPerformanceCells(horse.horseId),
        ];
        if (!horse.isScratched) return cells;
        return cells.map((cell) => DataCell(_grayOut(cell.child))).toList();
      },
    );
  }

  // [追加] 所属の色分け。出走馬タブ（starters_tab.dart）の _getAffiliationColor と同じ内容 (v.2026.9.22+26092207)
  static Color _getAffiliationColor(String affiliation) {
    if (affiliation.contains('美') || affiliation.contains('美浦')) {
      return Colors.lightBlue.shade50;
    } else if (affiliation.contains('栗') || affiliation.contains('栗東')) {
      return Colors.pink.shade50;
    } else if (affiliation.contains('地') || affiliation.contains('地方')) {
      return Colors.orange.shade50;
    } else if (affiliation.contains('外') || affiliation.contains('海外')) {
      return Colors.green.shade50;
    }
    return Colors.transparent;
  }

  /// 取消馬の行を白黒・半透明にする
  static Widget _grayOut(Widget child) {
    return Opacity(
      opacity: 0.45,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0.2126, 0.7152, 0.0722, 0, 0,
          0, 0, 0, 1, 0,
        ]),
        child: child,
      ),
    );
  }

  List<DataCell> _buildPerformanceCells(String horseId) {
    final futurePerformanceData = Future<_PerformanceData>(() async {
      final records = await _horseRepo.getHorsePerformanceRecords(horseId);
      final raceIds = records.map((r) => r.raceId).where((id) => id.isNotEmpty).toSet().toList();
      final raceResults = await _raceRepo.getMultipleRaceResults(raceIds);
      final displayRaceIds = records
          .take(_kPastRaceCount)
          .map((r) => r.raceId)
          .where((id) => id.isNotEmpty)
          .toList();
      final extras = await _extraRepo.getForHorse(horseId, displayRaceIds);
      return _PerformanceData(records, raceResults, extras);
    });

    final List<DataCell> cells = [];

    cells.add(DataCell(
      FutureBuilder<_PerformanceData>(
        future: futurePerformanceData,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data!.records.isNotEmpty) {
            final currentRace = predictionRaceData;
            final previousRace = snapshot.data!.records.first;
            final interval = RaceIntervalAnalyzer.formatRaceInterval(currentRace.raceDate, previousRace.date);
            final distanceChange = RaceIntervalAnalyzer.formatDistanceChange(currentRace.raceDetails1 ?? '', previousRace.distance);
            return _buildIntervalCell(interval, distanceChange);
          }
          return const SizedBox(width: _kIntervalColumnWidth);
        },
      ),
    ));

    for (int i = 0; i < _kPastRaceCount; i++) {
      cells.add(DataCell(
        FutureBuilder<_PerformanceData>(
          future: futurePerformanceData,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData && snapshot.data!.records.length > i) {
              final record = snapshot.data!.records[i];
              final raceResult = snapshot.data!.raceResults[record.raceId];
              HorseResult? horseResultInRace;
              if (raceResult != null) {
                try {
                  horseResultInRace = raceResult.horseResults.firstWhere((hr) => hr.horseId == record.horseId);
                } catch (e) {
                }
              }
              final extra = snapshot.data!.extras[record.raceId];
              return _buildPastRaceDetailCard(record, raceResult, horseResultInRace, extra);
            }
            return const SizedBox(width: 250);
          },
        ),
      ));

      if (i < _kPastRaceCount - 1) {
        cells.add(DataCell(
          FutureBuilder<_PerformanceData>(
            future: futurePerformanceData,
            builder: (context, snapshot) {
              if (snapshot.hasData && snapshot.data!.records.length > i + 1) {
                final current = snapshot.data!.records[i];
                final previous = snapshot.data!.records[i + 1];
                final interval = RaceIntervalAnalyzer.formatRaceInterval(current.date, previous.date);
                final distanceChange = RaceIntervalAnalyzer.formatDistanceChange(current.distance, previous.distance);
                return _buildIntervalCell(interval, distanceChange);
              }
              return const SizedBox(width: _kIntervalColumnWidth);
            },
          ),
        ));
      }
    }
    return cells;
  }

  Widget _buildIntervalCell(String interval, String distanceChange) {
    Color distanceColor;
    switch (distanceChange) {
      case '延長': distanceColor = Colors.blue; break;
      case '短縮': distanceColor = Colors.red; break;
      default: distanceColor = Colors.black87;
    }
    // [修正] 列幅を70→46に縮小。長い表記（例: 12ヶ月）ははみ出さないよう自動縮小する (v.2026.9.22+26092206)
    return SizedBox(
      width: _kIntervalColumnWidth,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(interval, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            Text(distanceChange, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: distanceColor)),
          ],
        ),
      ),
    );
  }

  /// 'YYYY/MM/DD' 形式の日付を 'MM/DD' に整形する。解析できなければそのまま返す。
  static String _formatShortDate(String date) {
    final match = RegExp(r'^\d{4}[/\-.](\d{1,2})[/\-.](\d{1,2})').firstMatch(date);
    if (match == null) return date;
    return '${match.group(1)!.padLeft(2, '0')}/${match.group(2)!.padLeft(2, '0')}';
  }

  /// 回り・コース区分。新聞ページの値（例: '右B'）を優先し、無ければレース結果のコース情報から回りだけを返す。
  static String _resolveCourseLabel(RaceResult? raceResult, HorsePastRaceExtra? extra) {
    final fromExtra = extra?.courseSection;
    if (fromExtra != null && fromExtra.isNotEmpty) return fromExtra;
    if (raceResult != null) {
      final dbMatch = RegExp(r'(芝|ダ|障)\s*(右|左|直線|直)').firstMatch(raceResult.raceInfo);
      if (dbMatch != null) return dbMatch.group(2)!;
      final raceMatch = RegExp(r'\(\s*(右|左|直線|直)').firstMatch(raceResult.raceInfo);
      if (raceMatch != null) return raceMatch.group(1)!;
    }
    return '';
  }

  /// レース全体の前後半3F。レース結果の「ペース:」行を優先し、無ければ戦績の pace 列を使う。
  static ({double first3f, double last3f})? _resolveFirstLast3F(HorseRaceRecord record, RaceResult? raceResult) {
    if (raceResult != null) {
      final fromResult = RaceDataParser.extractRaceFirstLast3F(raceResult);
      if (fromResult != null) return fromResult;
    }
    return RaceDataParser.parseRecordPace(record.pace);
  }

  /// 通過順。新聞ページの注記付きの値を優先し、無ければ戦績の通過順を使う。
  static List<PastRaceCorner> _resolveCorners(HorseRaceRecord record, HorsePastRaceExtra? extra) {
    final fromExtra = extra?.corners;
    if (fromExtra != null && fromExtra.isNotEmpty) return fromExtra;
    if (record.cornerPassage.isEmpty) return const [];
    return record.cornerPassage
        .split('-')
        .map((p) => PastRaceCorner(position: p.trim(), note: ''))
        .where((c) => c.position.isNotEmpty)
        .toList();
  }

  Widget _buildBlinkerBadge(bool isHighlighted) {
    return Container(
      width: 13,
      height: 13,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isHighlighted ? Colors.white : Colors.black87,
        shape: BoxShape.circle,
      ),
      child: Text(
        'B',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: isHighlighted ? Colors.black87 : Colors.white,
        ),
      ),
    );
  }

  Widget _buildCornerText(List<PastRaceCorner> corners, Color textColor, bool isHighlighted) {
    // [修正] 通過しないコーナー（位置が '-'）は位置を表示せず、注記があれば注記だけを残す。
    // 区切りの '-' と混ざって '----4-4' のように読みにくかったため (v.2026.9.22+26092204)
    final noPosition = RegExp(r'^[-－\s]*$');
    final visible = corners
        .where((c) => !(noPosition.hasMatch(c.position) && c.note.isEmpty))
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    final noteColor = isHighlighted ? Colors.yellowAccent : Colors.red.shade700;
    final spans = <InlineSpan>[];
    bool needsSeparator = false;
    for (final corner in visible) {
      final hasPosition = !noPosition.hasMatch(corner.position);
      if (hasPosition) {
        if (needsSeparator) spans.add(TextSpan(text: '-', style: TextStyle(color: textColor)));
        spans.add(TextSpan(text: corner.position, style: TextStyle(color: textColor)));
        if (corner.note.isNotEmpty) {
          spans.add(TextSpan(
            text: corner.note,
            style: TextStyle(color: noteColor, fontWeight: FontWeight.bold),
          ));
        }
        needsSeparator = true;
      } else {
        // 位置の無いコーナーの注記（例: 出遅れ '出'）は、次の位置の前に空白を空けて表示する
        if (needsSeparator) spans.add(TextSpan(text: ' ', style: TextStyle(color: textColor)));
        spans.add(TextSpan(
          text: '${corner.note} ',
          style: TextStyle(color: noteColor, fontWeight: FontWeight.bold),
        ));
        needsSeparator = false;
      }
    }
    return Text.rich(
      TextSpan(children: spans, style: const TextStyle(fontSize: 11)),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildAgariText(String agari, int? agariRank, Color textColor, bool isHighlighted) {
    if (agari.isEmpty) return const SizedBox.shrink();
    Color? background;
    if (!isHighlighted && agariRank != null) {
      if (agariRank == 1) background = Colors.red.shade100;
      if (agariRank == 2) background = Colors.blue.shade100;
      if (agariRank == 3) background = Colors.yellow.shade200;
    }
    final rankText = agariRank != null ? '($agariRank)' : '';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      color: background,
      child: Text(
        '上$agari$rankText',
        maxLines: 1,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  Widget _buildPaceText(
      String? paceMark,
      ({double first3f, double last3f})? firstLast3f,
      double? individualFirst3f,
      Color textColor,
      bool isHighlighted,
      ) {
    final spans = <InlineSpan>[];
    if (paceMark != null && paceMark.isNotEmpty) {
      Color markColor = textColor;
      if (!isHighlighted) {
        if (paceMark == 'H') markColor = Colors.red.shade700;
        if (paceMark == 'S') markColor = Colors.blue.shade700;
      }
      spans.add(TextSpan(text: '$paceMark ', style: TextStyle(color: markColor, fontWeight: FontWeight.bold)));
    }
    if (firstLast3f != null) {
      spans.add(TextSpan(
        text: '${firstLast3f.first3f.toStringAsFixed(1)}-${firstLast3f.last3f.toStringAsFixed(1)}',
        style: TextStyle(color: textColor),
      ));
    }
    if (individualFirst3f != null) {
      spans.add(TextSpan(
        text: ' 前${individualFirst3f.toStringAsFixed(1)}',
        style: TextStyle(color: textColor),
      ));
    }
    if (spans.isEmpty) return const SizedBox.shrink();
    return Text.rich(
      TextSpan(children: spans, style: const TextStyle(fontSize: 11)),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// 右ブロックの1行（左: 伸縮して省略記号 / 右: 最大幅120で右寄せ）
  Widget _buildLine(Widget left, Widget? right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: left),
        if (right != null) ...[
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: right,
          ),
        ],
      ],
    );
  }

  Widget _buildPastRaceDetailCard(
      HorseRaceRecord record,
      RaceResult? raceResult,
      HorseResult? horseResult,
      HorsePastRaceExtra? extra,
      ) {
    final isHighlighted = record.raceId.isNotEmpty && record.raceId == highlightedRaceId;
    final textColor = isHighlighted ? Colors.white : Colors.black87;
    final subTextColor = isHighlighted ? Colors.white70 : Colors.black54;
    final rankInt = int.tryParse(record.rank);
    Color backgroundColor = Colors.transparent;
    if (isHighlighted) {
      backgroundColor = Colors.black54;
    } else if (rankInt != null) {
      if (rankInt == 1) backgroundColor = Colors.red.withAlpha(30);
      if (rankInt == 2) backgroundColor = Colors.blue.withAlpha(30);
      if (rankInt == 3) backgroundColor = Colors.yellow.withAlpha(80);
    }

    final legStyle = RaceDataParser.getSimpleLegStyle(record.cornerPassage, record.numberOfHorses);

    String extractedGrade = '';
    final gradePattern = RegExp(r'\((J\.?G[I]{1,3}|G[I]{1,3})\)', caseSensitive: false);
    final match = gradePattern.firstMatch(record.raceName);
    if (match != null) extractedGrade = match.group(1)!;
    final gradeColor = getGradeColor(extractedGrade);

    final timeDiffMargin = record.margin;
    final stringMargin = horseResult?.margin ?? '';
    String displayMargin = timeDiffMargin;

    if (stringMargin.isNotEmpty && timeDiffMargin.isNotEmpty) {
      displayMargin = '$stringMargin / $timeDiffMargin';
    } else if (stringMargin.isNotEmpty) {
      displayMargin = stringMargin;
    }

    // --- 追加情報（データ源の優先順位は設計書 §4-2） ---
    final raceNameLabel = record.raceName
        .replaceAll(RegExp(r'\((J\.?G[I]{1,3}|G[I]{1,3})\)', caseSensitive: false), '')
        .trim();
    final venueLabel = record.venue.replaceAll(RegExp(r'\d'), '');
    final raceNumberLabel = record.raceNumber.isNotEmpty ? '${record.raceNumber}R' : '';
    final headerLabel = [_formatShortDate(record.date), venueLabel, raceNumberLabel]
        .where((s) => s.isNotEmpty)
        .join(' ');
    final conditionLabel = extra?.raceCondition ?? '';
    final frameLabel = record.frameNumber.isNotEmpty ? '(${record.frameNumber}枠)' : '';
    final courseLabel = _resolveCourseLabel(raceResult, extra);
    final courseLine = [record.distance, courseLabel, record.trackCondition, record.weather]
        .where((s) => s.isNotEmpty)
        .join(' ');
    final firstLast3f = _resolveFirstLast3F(record, raceResult);
    final paceMark = extra?.paceMark ??
        (firstLast3f != null
            ? RaceDataParser.paceMarkFromFirstLast3F(firstLast3f.first3f, firstLast3f.last3f)
            : null);
    final agariRank = extra?.agariRank ??
        (raceResult != null ? RaceDataParser.computeAgariRank(raceResult, record.horseId) : null);
    final corners = _resolveCorners(record, extra);
    final isRecord = extra?.isRecord == true;
    final isBlinker = extra?.isBlinker == true;
    final winnerLabel = record.winnerOrSecondHorse.isEmpty
        ? ''
        : '${record.rank == '1' ? '2着' : '勝'} ${record.winnerOrSecondHorse}';
    final commentLabel = [extra?.remark, extra?.shortComment]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(' ');
    final timeColor = (isRecord && !isHighlighted) ? Colors.red.shade700 : textColor;
    final commentColor = isHighlighted ? Colors.white : Colors.deepOrange.shade700;

    const double fontSize = 11;
    const double smallFontSize = 10;

    return GestureDetector(
      onTap: () {
        if (record.raceId.isNotEmpty) {
          onRaceHighlightChanged(record.raceId);
        }
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: gradeColor, width: 5.0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 52,
              decoration: BoxDecoration(
                color: backgroundColor,
                border: Border(right: BorderSide(color: Colors.grey.shade300)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      FutureBuilder<UserMark?>(
                        future: _userRepo.getUserMark(UserSession().localUserId!, record.raceId, record.horseId),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data?.mark != null) {
                            return Text(
                              snapshot.data!.mark,
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: isHighlighted ? const Color.fromRGBO(255, 255, 255, 0.30) : const Color.fromRGBO(0, 0, 0, 0.20),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            record.rank,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: ['1','2','3'].contains(record.rank)
                                  ? Colors.red
                                  : textColor,
                            ),
                          ),
                          Text(
                            '${record.popularity}人気',
                            style: TextStyle(fontSize: 11, color: textColor),
                          ),
                          if (record.odds.isNotEmpty)
                            Text(
                              '単${record.odds}',
                              maxLines: 1,
                              style: TextStyle(fontSize: 10, color: textColor),
                            ),
                          Text(
                            legStyle,
                            style: TextStyle(fontSize: 11, color: textColor),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: backgroundColor,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6.0, 3.0, 4.0, 3.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1行目: 日付・開催・R / 条件
                      _buildLine(
                        Text(headerLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: textColor)),
                        conditionLabel.isNotEmpty
                            ? Text(conditionLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: smallFontSize, color: subTextColor))
                            : null,
                      ),
                      // 2行目: レース名 / 頭数・馬番・枠
                      _buildLine(
                        Text(raceNameLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: textColor)),
                        Text('${record.numberOfHorses}頭 ${record.horseNumber}番$frameLabel', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: smallFontSize, color: textColor)),
                      ),
                      // 3行目: 距離・回り/コース区分・馬場・天気 / タイム（レコードは赤字＋R）
                      _buildLine(
                        Text(courseLine, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: fontSize, color: textColor)),
                        Text(isRecord ? '${record.time} R' : record.time, maxLines: 1,
                            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: timeColor)),
                      ),
                      // 4行目: 騎手(斤量)・馬体重・ブリンカー / 着差
                      _buildLine(
                        Row(
                          children: [
                            Flexible(
                              child: Text('${record.jockey}(${record.carriedWeight}) ${record.horseWeight}', maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: fontSize, color: textColor)),
                            ),
                            if (isBlinker) ...[
                              const SizedBox(width: 3),
                              _buildBlinkerBadge(isHighlighted),
                            ],
                          ],
                        ),
                        Text(displayMargin, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: textColor)),
                      ),
                      // 5行目: 通過順（注記は赤字） / 上がり3F（順位1〜3位は背景色）
                      _buildLine(
                        _buildCornerText(corners, textColor, isHighlighted),
                        _buildAgariText(record.agari, agariRank, textColor, isHighlighted),
                      ),
                      // 6行目: ペース記号・レース前後半3F・個別前半3F / タイム指数
                      _buildLine(
                        _buildPaceText(paceMark, firstLast3f, extra?.individualFirst3f, textColor, isHighlighted),
                        extra?.timeIndex != null
                            ? Text('指数${extra!.timeIndex}', maxLines: 1,
                                style: TextStyle(fontSize: smallFontSize, fontWeight: FontWeight.bold, color: textColor))
                            : null,
                      ),
                      // 7行目: 勝ち馬(2着馬) / 備考・短評
                      _buildLine(
                        Text(winnerLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: smallFontSize, color: subTextColor)),
                        commentLabel.isNotEmpty
                            ? Text(commentLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: smallFontSize, fontWeight: FontWeight.bold, color: commentColor))
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// [追加] 出馬表UI調整: 馬名を1文字ずつ縦に並べる縦書き表示。
// 文字の大きさはセルの高さ÷文字数で自動調整（上限16・下限9）。長音「ー」等は縦書き用に90度回転する (v.2026.9.22+26092206)
class _VerticalHorseName extends StatelessWidget {
  final String name;
  // [追加] セルの背景色（所属色）。未指定なら背景なし (v.2026.9.22+26092207)
  final Color backgroundColor;

  const _VerticalHorseName({required this.name, this.backgroundColor = Colors.transparent});

  static const Set<String> _rotateChars = {'ー', '－', '-', '―', '〜', '～'};

  @override
  Widget build(BuildContext context) {
    final chars = name.characters.toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final double available =
            constraints.maxHeight.isFinite ? constraints.maxHeight - 8 : 130;
        final int count = chars.isEmpty ? 1 : chars.length;
        final double fontSize = (available / count / 1.15).clamp(9.0, 16.0);
        // [修正] 所属色の背景を付ける。背景が行の区切り線を覆わないよう、下端を1px空ける (v.2026.9.22+26092207)
        return Container(
          width: double.infinity,
          height: double.infinity,
          margin: const EdgeInsets.only(bottom: 1),
          color: backgroundColor,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: chars.map((ch) {
                  final text = Text(
                    ch,
                    style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, height: 1.1),
                  );
                  return _rotateChars.contains(ch) ? RotatedBox(quarterTurns: 1, child: text) : text;
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
