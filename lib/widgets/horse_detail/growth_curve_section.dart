// lib/widgets/horse_detail/growth_curve_section.dart

// [追加] 馬体重成長曲線 Step2: 馬詳細タブ「情報・血統」の最下部に出す成長曲線。
// 見出し（1行目: デビュー体重→最新、2行目: 最高・最低・走数）、期間スイッチ（直近1年／3年／全期間）、
// グラフ（タップした点の詳細を下に表示）、凡例を並べる。データは受け取るだけで、読み込みはしない (v.2026.10.1+26100102)
// [修正] 馬詳細タブ 表示項目変更 Step3: 期間スイッチを廃止し、全期間を「画面の幅＝1年」の横スクロールで表示（開いたときは右端＝最新）。
// 左の体重目盛りはスクロールさせない。縦軸は全期間で固定。凡例は 馬体重・頭数・人気・着順 の4つ (v.2026.10.15+26101502)
// [修正] 成長曲線の表示項目追加: 選んだレースの枠に斤量・上がりの行を足し、タップで選んだ点を薄い青で点滅させる。
// 上の帯の ▼・×・間隔は GrowthCurvePainter が描く (v.2026.10.19+26101905)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/growth_curve_builder.dart';
import 'package:hetaumakeiba_v2/models/horse_performance_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/utils/speed_index_date_parser.dart';
import 'package:hetaumakeiba_v2/widgets/horse_detail/growth_curve_painter.dart';

class GrowthCurveSection extends StatefulWidget {
  final PredictionHorseDetail horse;

  /// その馬の過去走（DB の horse_performance。並び順は問わない）
  final List<HorseRaceRecord> records;

  /// 今回レースの日付（PredictionRaceData.raceDate の文字列）
  final String raceDate;

  // [追加] 馬詳細タブ 表示項目変更 Step3追補: レース全体で決めた縦軸（GrowthCurveBuilder.raceWeightWindow）。null ならこの馬の体重だけで決める (v.2026.10.15+26101502)
  final GrowthWeightWindow? window;

  const GrowthCurveSection({
    super.key,
    required this.horse,
    required this.records,
    required this.raceDate,
    this.window,
  });

  @override
  State<GrowthCurveSection> createState() => _GrowthCurveSectionState();
}

class _GrowthCurveSectionState extends State<GrowthCurveSection>
    with SingleTickerProviderStateMixin {
  /// タップで選んだ点（全期間の中での番号）。null なら最後の点
  int? _selectedIndex;

  // [追加] 馬詳細タブ 表示項目変更 Step3: グラフ本体の横スクロール。開いたとき・馬が変わったときに右端（最新）へ移す (v.2026.10.15+26101502)
  final ScrollController _scrollController = ScrollController();
  bool _scrollToEndPending = true;

  // [追加] 成長曲線の表示項目追加: タップで選んだ点の点滅（0.9秒で薄い↔濃いを行き来する）。タップするまでは動かさない (v.2026.10.19+26101905)
  late final AnimationController _blinkController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _blink = CurvedAnimation(
    parent: _blinkController,
    curve: Curves.easeInOut,
  );

  @override
  void didUpdateWidget(covariant GrowthCurveSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.horse.horseId != widget.horse.horseId) {
      _selectedIndex = null;
      _scrollToEndPending = true;
      // [追加] 成長曲線の表示項目追加: 馬が変わったら点滅を止める (v.2026.10.19+26101905)
      _blinkController.reset();
    }
  }

  @override
  void dispose() {
    // [追加] 成長曲線の表示項目追加 (v.2026.10.19+26101905)
    _blinkController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  static String _signed(int v) {
    if (v > 0) return '+$v';
    if (v < 0) return '$v';
    return '±0';
  }

  static String _date(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}/$m/$day';
  }

  /// 見出し（生年月日は基本情報に出ているので出さない）。
  /// 1行目: デビュー体重 → 最新体重（増減）、2行目: 最高・最低・走数
  Widget _buildSummary(GrowthSummary summary) {
    final lines = <String>[];
    final debut = summary.debutWeight;
    final latest = summary.latestWeight;
    if (debut != null && latest != null) {
      final diff = summary.diffFromDebut;
      lines.add('デビュー ${debut}kg → 最新 ${latest}kg'
          '${diff == null ? '' : '（${_signed(diff)}）'}');
      lines.add('最高 ${summary.maxWeight}kg／最低 ${summary.minWeight}kg'
          '　${summary.runCount}走');
    } else {
      lines.add('${summary.runCount}走');
    }
    return Text(
      lines.join('\n'),
      style: const TextStyle(fontSize: 12, color: Colors.black87),
    );
  }

  // [修正] 馬詳細タブ 表示項目変更 Step3: 左に固定の体重目盛り、右に横スクロールする本体（幅は GrowthCurveBuilder.chartWidth） (v.2026.10.15+26101502)
  Widget _buildChart(
      List<GrowthPoint> points, GrowthWeightWindow window, int selected) {
    if (_scrollToEndPending) {
      _scrollToEndPending = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      });
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: GrowthCurveLayout.leftAxisWidth,
          height: GrowthCurveLayout.totalHeight,
          child: CustomPaint(
            painter: GrowthCurveAxisPainter(window: window),
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = GrowthCurveBuilder.chartWidth(
                viewportWidth: constraints.maxWidth,
                start: points.first.date,
                end: points.last.date,
              );
              final size = Size(width, GrowthCurveLayout.totalHeight);
              return SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (details) {
                    final layout = GrowthCurveLayout(
                        size: size, points: points, window: window);
                    final index = layout.nearestIndex(details.localPosition);
                    if (index != null) {
                      setState(() => _selectedIndex = index);
                      // [追加] 成長曲線の表示項目追加: タップで選んだら点滅を始める (v.2026.10.19+26101905)
                      if (!_blinkController.isAnimating) {
                        _blinkController.repeat(reverse: true);
                      }
                    }
                  },
                  child: CustomPaint(
                    size: size,
                    painter: GrowthCurvePainter(
                      points: points,
                      window: window,
                      selectedIndex: selected,
                      // [追加] 成長曲線の表示項目追加: タップで選んだ点だけ点滅（開いたときの最後の点は点滅しない） (v.2026.10.19+26101905)
                      highlightSelected: _selectedIndex == selected,
                      blink: _blink,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedInfo(GrowthPoint p) {
    final weight = p.weight;
    final change = p.weightChange;
    final weightText = weight == null
        ? '馬体重 計不'
        : '馬体重 ${weight}kg${change == null ? '' : '（${_signed(change)}）'}';
    String resultText;
    if (p.isCurrent) {
      resultText = '今回の当日発表';
    } else {
      final String rankText = switch (p.finishKind) {
        GrowthFinishKind.numeric => '${p.rank}着',
        GrowthFinishKind.stopped => '中止',
        GrowthFinishKind.excluded => '除外',
        GrowthFinishKind.scratched => '取消',
        GrowthFinishKind.unknown => '--',
      };
      final popularity = p.popularity;
      final fieldSize = p.fieldSize;
      resultText = '${popularity == null ? '--' : '$popularity'}人気 → $rankText'
          '${fieldSize == null ? '' : '（$fieldSize頭）'}';
    }
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_date(p.date)}  ${p.raceName}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            '$weightText　$resultText',
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
          // [追加] 成長曲線の表示項目追加: 斤量と上がり（今回の点は斤量だけ） (v.2026.10.19+26101905)
          const SizedBox(height: 2),
          Text(
            p.isCurrent
                ? '斤量 ${p.carriedWeight ?? '--'}'
                : '斤量 ${p.carriedWeight ?? '--'}　上がり ${p.agari ?? '--'}',
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Widget mark, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10)),
      ],
    );
  }

  Widget _lineMark(Color color) {
    return Container(width: 14, height: 2, color: color);
  }

  Widget _boxMark(Color color) {
    return Container(width: 8, height: 10, color: color);
  }

  // [修正] 馬詳細タブ 表示項目変更 Step3: 凡例は 馬体重・頭数・人気・着順 の4つだけ (v.2026.10.15+26101502)
  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: [
              _legendItem(_lineMark(GrowthCurvePainter.weightColor), '馬体重'),
              _legendItem(_boxMark(GrowthCurvePainter.fieldColor), '頭数'),
              _legendItem(_boxMark(GrowthCurvePainter.popularityColor), '人気'),
              _legendItem(_boxMark(GrowthCurvePainter.rankColor), '着順'),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            // [修正] 成長曲線の表示項目追加: 上の帯の説明を足す (v.2026.10.19+26101905)
            '上の▼は出走（×は取消・除外）、間の文字は前走からの間隔。棒は高いほど上位（18頭立てを満杯）。破線は計不をはさむ区間と今回の当日体重。点をタップで詳細',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _message(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(text,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final raceDate = parseRaceDateForSpeedIndex(widget.raceDate);
    final all = GrowthCurveBuilder.buildPoints(
      records: widget.records,
      raceDate: raceDate,
      currentHorseWeight: widget.horse.horseWeight,
      // [追加] 成長曲線の表示項目追加: 「今回」の点に出馬表の斤量を付ける (v.2026.10.19+26101905)
      currentCarriedWeight: widget.horse.carriedWeight,
    );
    // [修正] 馬詳細タブ 表示項目変更 Step3: 期間で絞らず全期間を描く。縦軸も全期間で1回だけ決める (v.2026.10.15+26101502)
    // [修正] 馬詳細タブ 表示項目変更 Step3追補: レース全体の縦軸を渡されたらそれを使う（グラフの高さは同じで、10kgの間隔がレースごとに変わる） (v.2026.10.15+26101502)
    final window = widget.window ?? GrowthCurveBuilder.weightWindow(all);
    final summary = GrowthCurveBuilder.summarize(all);
    final selectedIndex = _selectedIndex;
    final selected = all.isEmpty
        ? -1
        : (selectedIndex != null && selectedIndex < all.length
            ? selectedIndex
            : all.length - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSummary(summary),
        const SizedBox(height: 6),
        if (all.isEmpty)
          _message('戦績がありません')
        else ...[
          _buildChart(all, window, selected),
          _buildSelectedInfo(all[selected]),
          _buildLegend(),
        ],
      ],
    );
  }
}
