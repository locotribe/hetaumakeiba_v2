// lib/widgets/factor_candidates_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/factor_candidate_selector.dart';
import 'package:hetaumakeiba_v2/widgets/horse_number_badge.dart';
// [追加] ローテ・血統タブの見た目の調整 Step3: 回数で選ぶファクター（ローテ・血統）の回収率の文字と色 (v.2026.10.19+26101908)
import 'package:hetaumakeiba_v2/widgets/volatility_components/past_race_return_style.dart';

// [追加] ローテ・血統タブの見た目の調整 Step3: 回数で選ぶファクター（ローテ・血統）のチップの名前（中身は win/place/show のまま） (v.2026.10.19+26101908)
const Map<String, String> _countMetricLabels = {
  FactorMetric.win: '1着数',
  FactorMetric.place: '連対数',
  FactorMetric.show: '3着内数',
};

// [追加] リフト値の水準に応じた色分け（カード内で共通利用） (v.2026.9.5+26090506)
Color _liftColor(double lift) {
  if (lift >= 2.0) return Colors.red.shade700;
  if (lift >= 1.3) return Colors.deepOrange.shade600;
  if (lift >= 1.0) return Colors.orange.shade800;
  if (lift >= 0.85) return Colors.blueGrey;
  return Colors.grey;
}

// [追加] 勝率／連対率／複勝率の切替ボタン (v.2026.9.5+26090506)
class _MetricSelector extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;
  final bool enabled;

  // [追加] ペース(スロー/ミドル/ハイ)や馬場(高/標準/低)のラベル上書き (v.2026.9.5+26090506)
  final Map<String, String>? labels;

  const _MetricSelector({
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.labels,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: FactorMetric.all.map((metric) {
        final bool isSelected = metric == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 6.0),
          child: InkWell(
            onTap: enabled ? () => onChanged(metric) : null,
            borderRadius: BorderRadius.circular(12.0),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10.0, vertical: 4.0),
              decoration: BoxDecoration(
                color: isSelected ? Colors.teal.shade700 : Colors.white,
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(
                  color: isSelected ? Colors.teal.shade700 : Colors.teal.shade200,
                ),
              ),
              child: Text(
                labels?[metric] ?? FactorMetric.labels[metric] ?? metric,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? Colors.white
                      : (enabled ? Colors.teal.shade800 : Colors.grey),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// [追加] 読み方の注意書きブロック。先頭1件は常時表示し、残りは折りたたむ (v.2026.9.5+26090506)
class _NotesSection extends StatelessWidget {
  final List<String> notes;

  const _NotesSection({required this.notes});

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty) return const SizedBox.shrink();

    final first = notes.first;
    final rest = notes.length > 1 ? notes.sublist(1) : const <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.7),
            borderRadius: BorderRadius.circular(6.0),
            border: Border.all(color: Colors.teal.shade100),
          ),
          child: Text(
            first,
            style: const TextStyle(fontSize: 11.5, height: 1.5),
          ),
        ),
        if (rest.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8.0),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              title: Text(
                'このデータの読み方をもっと見る（${rest.length}件）',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade800,
                ),
              ),
              children: rest
                  .map((note) => Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8.0),
                        padding: const EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(color: Colors.teal.shade100),
                        ),
                        child: Text(
                          note,
                          style: const TextStyle(fontSize: 11.5, height: 1.5),
                        ),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

// [追加] 年齢タブ Step2: 安全圏・足切りの区分と、性に当たる今回の出走馬の枠。安全圏は緑、足切りは赤 (v.2026.10.30+26103003)
class _ZoneSection extends StatelessWidget {
  final FactorCandidateResult result;

  const _ZoneSection({required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(6.0),
        border: Border.all(color: Colors.teal.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.zoneSummary ?? '',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.teal.shade900,
            ),
          ),
          if (result.safeZone.isNotEmpty)
            ..._rows('安全圏', Colors.green.shade700, result.safeZone),
          if (result.cutZone.isNotEmpty)
            ..._rows('足切り', Colors.red.shade700, result.cutZone),
        ],
      ),
    );
  }

  List<Widget> _rows(
      String title, Color color, List<FactorZoneCandidate> list) {
    return [
      const SizedBox(height: 6),
      Text(
        '$title の年齢の馬（${list.length}頭）',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
      ...list.map(
        (c) => Padding(
          padding: const EdgeInsets.only(top: 3.0),
          child: Row(
            children: [
              HorseNumberBadge(
                horseNumber: c.horseNumber,
                gateNumber: c.gateNumber,
                size: 20.0,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${c.horseName}  ${c.categoryText}  '
                  '複勝 ${c.showRate.toStringAsFixed(1)}%(${c.lift.toStringAsFixed(2)}倍) [${c.recordText}]',
                  style: TextStyle(fontSize: 11.5, color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

// [追加] 1ファクター分の「今回の該当馬」を表示するカード (v.2026.9.5+26090506)
class FactorCandidatesCard extends StatefulWidget {
  final FactorCandidateResult result;

  const FactorCandidatesCard({super.key, required this.result});

  @override
  State<FactorCandidatesCard> createState() => _FactorCandidatesCardState();
}

class _FactorCandidatesCardState extends State<FactorCandidatesCard> {
  String _metric = FactorMetric.show;

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final candidates = result.candidatesFor(_metric);

    return Card(
      elevation: 2,
      color: Colors.teal.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(color: Colors.teal.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, size: 18, color: Colors.teal.shade700),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${result.factorLabel}の傾向に合う今回の出走馬',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade900,
                    ),
                  ),
                ),
                if (candidates.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 2.0),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade700,
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Text(
                      '${candidates.length}頭',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              result.trendSummary,
              style: TextStyle(fontSize: 12, color: Colors.teal.shade900),
            ),
            const SizedBox(height: 8),
            // [追加] 年齢タブ Step2: 安全圏・足切りの枠（判定するファクターだけ） (v.2026.10.30+26103003)
            if (result.zoneSummary != null) _ZoneSection(result: result),

            // 指標の切替（単一スコアのファクターでは表示しない）
            if (result.showMetricSelector)
              Row(
                children: [
                  Text(
                    result.metricLabels == null ? '並べ替え' : '想定',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricSelector(
                      selected: _metric,
                      onChanged: (value) => setState(() => _metric = value),
                      // [修正] ローテ・血統タブの見た目の調整 Step3: 回数で選ぶファクターはチップを「1着数・連対数・3着内数」にする (v.2026.10.19+26101908)
                      labels: result.isCountBased
                          ? _countMetricLabels
                          : result.metricLabels,
                    ),
                  ),
                ],
              ),
            if (!result.isRateBased)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '※ このファクターは0〜100点のスコアを「50点=1.00倍」として換算した'
                  '“適合”です。他タブの倍率（実際の複勝率を全体平均で割った値）とは性質が違うため、'
                  '数値の大小をタブ間で直接比べないでください。',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
                ),
              ),
            // [追加] ローテ・血統タブの見た目の調整 Step3: 回数で選ぶファクターは、全体平均の行の代わりに全体の回収率を出す (v.2026.10.19+26101908)
            if (result.isCountBased)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '過去の出走馬全体の回収率: '
                  '単回 ${pastRaceReturnText(result.overallWinReturn)} ／ '
                  '複回 ${pastRaceReturnText(result.overallShowReturn)}',
                  style: TextStyle(fontSize: 10, color: Colors.teal.shade800),
                ),
              ),
            // [修正] ローテ・血統タブの見た目の調整 Step3: 回数で選ぶファクターでは全体平均（倍率の基準）の行を出さない (v.2026.10.19+26101908)
            if (result.baseline != null &&
                result.isRateBased &&
                !result.isCountBased)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '全体平均（この倍率が1.00倍の基準）: '
                  '勝率 ${result.baseline!.rate(FactorMetric.win).toStringAsFixed(1)}% ／ '
                  '連対率 ${result.baseline!.rate(FactorMetric.place).toStringAsFixed(1)}% ／ '
                  '複勝率 ${result.baseline!.rate(FactorMetric.show).toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 10, color: Colors.teal.shade800),
                ),
              ),

            const Divider(height: 16),

            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  result.emptyMessage ?? '該当する馬がいません。',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
              )
            else
              ...List.generate(candidates.length, (index) {
                return _buildCandidateRow(index, candidates[index], result);
              }),

            const SizedBox(height: 10),
            _NotesSection(notes: result.notes),
            const SizedBox(height: 6),
            Text(
              '※ ${result.criteria}。',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCandidateRow(
      int index, FactorCandidate candidate, FactorCandidateResult result) {
    final lift = candidate.liftFor(_metric);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Padding(
              padding: const EdgeInsets.only(top: 3.0),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.teal.shade700,
                ),
              ),
            ),
          ),
          HorseNumberBadge(
            horseNumber: candidate.horseNumber,
            gateNumber: candidate.gateNumber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        candidate.horseName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6.0, vertical: 1.0),
                      // [修正] ローテ・血統タブの見た目の調整 Step3: 回数で選ぶファクターのバッジは回収率（1着数のチップでは単回、ほかは複回） (v.2026.10.19+26101908)
                      decoration: BoxDecoration(
                        color: result.isCountBased
                            ? _returnBadgeColor(candidate)
                            : _liftColor(lift),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        result.isCountBased
                            ? _returnBadgeText(candidate)
                            : (result.isRateBased
                                ? '${lift.toStringAsFixed(2)}倍'
                                : '適合 ${lift.toStringAsFixed(2)}'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  candidate.reason,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                // [修正] ローテ・血統タブの見た目の調整 Step3: 回数で選ぶファクターは、率と倍率の行の代わりに回数と回収率の行を出す (v.2026.10.19+26101908)
                if (result.isCountBased)
                  _buildCountsLine(candidate)
                else if (candidate.rates != null)
                  _buildRatesLine(candidate, result),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatesLine(FactorCandidate candidate, FactorCandidateResult result) {
    final spans = <InlineSpan>[];

    for (final metric in FactorMetric.all) {
      final rate = candidate.rateFor(metric);
      if (rate == null) continue;
      final lift = candidate.liftFor(metric);
      final bool isSelected = metric == _metric;

      // ラベル上書きがあるファクター（ペースなど）はその名前を使う
      final String shortLabel = result.metricLabels?[metric] ??
          FactorMetric.shortLabels[metric] ??
          metric;

      if (spans.isNotEmpty) {
        spans.add(const TextSpan(
          text: '  ',
          style: TextStyle(fontSize: 11, color: Colors.black38),
        ));
      }

      spans.add(TextSpan(
        text:
            '$shortLabel ${rate.toStringAsFixed(1)}%(${lift.toStringAsFixed(2)})',
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? _liftColor(lift) : Colors.black45,
        ),
      ));
    }

    if (candidate.recordText != null) {
      spans.add(TextSpan(
        text: '  [${candidate.recordText}]',
        style: const TextStyle(fontSize: 10, color: Colors.black38),
      ));
    }

    if (spans.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 1.0),
      child: RichText(text: TextSpan(children: spans)),
    );
  }

  // [追加] ローテ・血統タブの見た目の調整 Step3: 回数で選ぶファクター（ローテ・血統）のバッジの文字と色。1着数のチップでは単回、ほかは複回 (v.2026.10.19+26101908)
  String _returnBadgeText(FactorCandidate candidate) {
    final name = _metric == FactorMetric.win ? '単回' : '複回';
    return '$name ${pastRaceReturnText(candidate.returnFor(_metric))}';
  }

  Color _returnBadgeColor(FactorCandidate candidate) {
    final value = candidate.returnFor(_metric);
    if (value == null) return Colors.grey;
    return pastRaceReturnColor(value, candidate.sampleStarts ?? 0);
  }

  // [追加] ローテ・血統タブの見た目の調整 Step3: 回数で選ぶファクターの行。「勝1 連2 複6  単回85% 複回132%  [1-1-4-9]」。選んだチップの回数と、並べ替えに使う回収率を太字にする (v.2026.10.19+26101908)
  Widget _buildCountsLine(FactorCandidate candidate) {
    final spans = <InlineSpan>[];

    for (final metric in FactorMetric.all) {
      final bool isSelected = metric == _metric;
      if (spans.isNotEmpty) {
        spans.add(const TextSpan(
          text: ' ',
          style: TextStyle(fontSize: 11, color: Colors.black38),
        ));
      }
      spans.add(TextSpan(
        text:
            '${FactorMetric.shortLabels[metric] ?? metric}${candidate.countFor(metric)}',
        style: TextStyle(
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.teal.shade800 : Colors.black45,
        ),
      ));
    }

    final starts = candidate.sampleStarts ?? 0;
    final bool winSelected = _metric == FactorMetric.win;
    spans.add(TextSpan(
      text: '  単回${pastRaceReturnText(candidate.winReturn)}',
      style: TextStyle(
        fontSize: 11,
        fontWeight: winSelected ? FontWeight.bold : FontWeight.normal,
        color: pastRaceReturnColor(candidate.winReturn, starts),
      ),
    ));
    spans.add(TextSpan(
      text: ' 複回${pastRaceReturnText(candidate.showReturn)}',
      style: TextStyle(
        fontSize: 11,
        fontWeight: winSelected ? FontWeight.normal : FontWeight.bold,
        color: pastRaceReturnColor(candidate.showReturn, starts),
      ),
    ));

    if (candidate.recordText != null) {
      spans.add(TextSpan(
        text: '  [${candidate.recordText}]',
        style: const TextStyle(fontSize: 10, color: Colors.black38),
      ));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 1.0),
      child: RichText(text: TextSpan(children: spans)),
    );
  }
}

// [追加] ファクター横断で該当数を集計して表示するカード (v.2026.9.5+26090506)
class FactorHitMatrixCard extends StatefulWidget {
  final Map<String, FactorCandidateResult> results;

  // [追加] 集計対象のファクターと列名。省略時は statisticsJson 由来の7ファクター (v.2026.9.5+26090506)
  final List<String>? factorOrder;
  final Map<String, String>? factorLabels;

  const FactorHitMatrixCard({
    super.key,
    required this.results,
    this.factorOrder,
    this.factorLabels,
  });

  @override
  State<FactorHitMatrixCard> createState() => _FactorHitMatrixCardState();
}

class _FactorHitMatrixCardState extends State<FactorHitMatrixCard> {
  String _metric = FactorMetric.show;

  List<String> get _order =>
      widget.factorOrder ?? FactorCandidateSelector.factorKeys;

  String _labelOf(String key) =>
      widget.factorLabels?[key] ??
      FactorCandidateSelector.factorLabels[key] ??
      key;

  @override
  Widget build(BuildContext context) {
    final summaries = FactorCandidateSelector.aggregate(
      widget.results,
      metric: _metric,
      factorOrder: _order,
    );
    final metricLabel = FactorMetric.labels[_metric] ?? _metric;

    return Card(
      elevation: 2,
      color: Colors.teal.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
        side: BorderSide(color: Colors.teal.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.grid_view, size: 18, color: Colors.teal.shade700),
                const SizedBox(width: 6),
                Text(
                  'ファクター該当数',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '基準指標',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MetricSelector(
                    selected: _metric,
                    onChanged: (value) => setState(() => _metric = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (summaries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '該当馬を選出できませんでした。出馬表データを取得すると表示されます。',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 12.0,
                  headingRowHeight: 36.0,
                  dataRowMinHeight: 36.0,
                  dataRowMaxHeight: 44.0,
                  headingRowColor:
                      MaterialStateProperty.all(Colors.teal.shade100),
                  columns: [
                    const DataColumn(
                        label: Text('馬', style: TextStyle(fontSize: 12))),
                    const DataColumn(
                        label: Text('該当', style: TextStyle(fontSize: 12))),
                    ..._order.map(
                      (key) => DataColumn(
                        label: Text(
                          _labelOf(key),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                  rows: summaries.map((summary) {
                    return DataRow(cells: [
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          HorseNumberBadge(
                            horseNumber: summary.horseNumber,
                            gateNumber: summary.gateNumber,
                            size: 22.0,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            summary.horseName,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )),
                      // [修正] 年齢タブ Step2: 「該当」の数は、足切りの数を引いた値 (v.2026.10.30+26103003)
                      DataCell(_buildHitCountChip(summary.netCount)),
                      ..._order.map(
                        (key) => DataCell(_buildRankCell(
                          summary.factorRanks[key],
                          summary.factorLifts[key],
                          isCut: summary.cutFactors.contains(key),
                        )),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            const SizedBox(height: 10),
            _NotesSection(notes: [
              '【この表の読み方】各タブで「$metricLabelの傾向に合う」として選ばれた馬を横断して集計しています。'
                  'セルの数字はそのファクター内での順位（1が最上位）で、色が濃いほど全体平均に対する倍率が高い馬です。'
                  '複数のファクターで名前が挙がっている馬ほど、過去データ上の裏付けが厚いと言えます。'
                  'ただしこれは「どのファクターから見ても条件に合う馬」を示すだけで、'
                  '強い馬を当てているわけではありません。'
                  '該当数が1つでも、そのファクターの倍率が突出しているならそちらが有力な場合もあります。'
                  '上の切替ボタンで基準指標を変えると、勝ち切る力を重視するか（勝率）、'
                  '堅実に上位に来る力を重視するか（連対率・複勝率）で顔ぶれが変わります。',
              'ペースと馬場状態の2ファクターだけは、上の切替ボタンに関係なく'
                  '常に「ミドルペース」「標準の馬場」で集計しています。'
                  'この2つは勝率・連対率・複勝率ではなく想定シナリオの3区分を持っているため、'
                  '中庸の想定に固定したほうが横断比較として素直になるからです。'
                  '想定を変えた顔ぶれは、それぞれのタブで切り替えてご確認ください。',
              '該当数はあくまで「何個のファクターで上位5頭に入ったか」であり、'
                  '各ファクターの重要度は等しくありません。'
                  'どのファクターを重視するかは、各タブの倍率と注意書きを読んだうえでご自身で決めてください。'
                  'この一覧は過去データの整理であって、今回の結果を予想したものではありません。',
              // [追加] 年齢タブ Step2: 「×」と該当数の説明 (v.2026.10.30+26103003)
              '赤い「×」は、そのファクターで「足切り」の区分（母数が十分あり、過去に馬券に絡みにくかった区分）に当たることを表します。'
                  '「該当」の数は、該当したファクターの数から「×」の数を引いた値で、並びもこの値の順です。'
                  '足切りは目安であり、今回の馬が来ないと決めるものではありません。',
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildHitCountChip(int count) {
    Color color;
    if (count >= 5) {
      color = Colors.red;
    } else if (count >= 4) {
      color = Colors.deepOrange;
    } else if (count >= 3) {
      color = Colors.orange;
    } else if (count >= 2) {
      color = Colors.blue;
    } else if (count < 0) {
      // [追加] 年齢タブ Step2: 足切りの数が該当数を上回るときは赤系 (v.2026.10.30+26103003)
      color = Colors.red.shade300;
    } else {
      color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildRankCell(int? rank, double? lift, {bool isCut = false}) {
    // [追加] 年齢タブ Step2: 足切りの区分に当たる馬は赤い「×」で示す (v.2026.10.30+26103003)
    if (isCut) {
      return Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.red.shade700, width: 1.5),
        ),
        child: Text(
          '×',
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700),
        ),
      );
    }

    if (rank == null) {
      return const Text('-', style: TextStyle(fontSize: 12, color: Colors.grey));
    }

    final Color color = _liftColor(lift ?? 1.0);

    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        '$rank',
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
