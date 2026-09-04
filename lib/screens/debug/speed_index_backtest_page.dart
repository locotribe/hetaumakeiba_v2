// lib/screens/debug/speed_index_backtest_page.dart

// [追加] フェーズ6 スピード指数バックテスト・ハーネス（隠しデバッグ画面）。
// 過去レース群にRaceAnalyzer.simulateRaceDevelopmentを「スピード指数あり／なし」で
// 走らせ、シミュ着順予測と実着順のスピアマン順位相関を比較するための開発者専用ツール。
// memory/スピード指数_バックテストハーネス仕様.md の実装指示に従う。
// UI層のみを担当し、中核ロジックはlib/logic/analysis/speed_index_backtest_runner.dart
// (SpeedIndexBacktestRunner)とlib/logic/analysis/speed_index_backtest_aggregator.dart
// (SpeedIndexBacktestAggregator)に切り出している（単体テストから直接呼べるようにするため）。
// 段階1〜4: 共有ユーティリティ抽出(本体挙動不変) + 1レースでdevWith/devNone取得確認 +
// ρ_with/ρ_none/Δρの1レース表示 + 全レースループと距離帯/ペース/confidence別集計を実装する (v.2026.9.4)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/db/repositories/horse_repository.dart';
import 'package:hetaumakeiba_v2/db/repositories/race_repository.dart';
import 'package:hetaumakeiba_v2/logic/analysis/speed_index_backtest_aggregator.dart';
import 'package:hetaumakeiba_v2/logic/analysis/speed_index_backtest_runner.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';

class SpeedIndexBacktestPage extends StatefulWidget {
  const SpeedIndexBacktestPage({super.key});

  @override
  State<SpeedIndexBacktestPage> createState() =>
      _SpeedIndexBacktestPageState();
}

class _SpeedIndexBacktestPageState extends State<SpeedIndexBacktestPage> {
  final RaceRepository _raceRepo = RaceRepository();
  final HorseRepository _horseRepo = HorseRepository();

  bool _isLoadingCandidates = true;
  bool _isRunning = false;
  String? _error;
  List<RaceResult> _candidates = []; // raceId降順(新しい順)の対象レース全件
  RaceResult? _selectedRace;
  SpeedIndexBacktestSingleRaceResult? _result;

  // [追加] 段階4: 全件実行の対象範囲（直近N件、デフォルト300件）(v.2026.9.4)
  final TextEditingController _rangeController =
      TextEditingController(text: '300');
  bool _isBatchRunning = false;
  int _batchDone = 0;
  int _batchTotal = 0;
  List<SpeedIndexBacktestSingleRaceResult> _batchResults = [];
  int _batchErrorCount = 0;
  SpeedIndexBacktestAggregate? _aggregate;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  @override
  void dispose() {
    _rangeController.dispose();
    super.dispose();
  }

  // [追加] §3 対象レースの選定（JRA/非障害/確定/有効着順5頭以上）。全件を保持し、
  // 単発実行の候補一覧・全件実行の対象範囲の両方に使う (v.2026.9.4)
  Future<void> _loadCandidates() async {
    setState(() {
      _isLoadingCandidates = true;
      _error = null;
    });
    try {
      final all = await _raceRepo.getAllRaceResults();
      final eligible =
          all.values.where(SpeedIndexBacktestRunner.isEligibleRace).toList()
            ..sort((a, b) => b.raceId.compareTo(a.raceId)); // raceIdは日付を含むため新しい順
      setState(() {
        _candidates = eligible;
        _selectedRace = _candidates.isNotEmpty ? _candidates.first : null;
        _isLoadingCandidates = false;
      });
    } catch (e) {
      setState(() {
        _error = '候補レースの取得に失敗しました: $e';
        _isLoadingCandidates = false;
      });
    }
  }

  Future<void> _runSelectedRace() async {
    final race = _selectedRace;
    if (race == null) return;
    setState(() {
      _isRunning = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await SpeedIndexBacktestRunner.runSingleRace(
        race,
        horseRepo: _horseRepo,
      );
      setState(() {
        _result = result;
        _isRunning = false;
      });
    } catch (e) {
      setState(() {
        _error = '実行に失敗しました: $e';
        _isRunning = false;
      });
    }
  }

  // [追加] 段階4: 対象範囲(直近N件)でrunBatchを実行し、集計する (v.2026.9.4)
  Future<void> _runBatch() async {
    final n = int.tryParse(_rangeController.text.trim());
    if (n == null || n <= 0 || _candidates.isEmpty) return;
    final targets = _candidates.take(n).toList();

    setState(() {
      _isBatchRunning = true;
      _batchDone = 0;
      _batchTotal = targets.length;
      _batchErrorCount = 0;
      _batchResults = [];
      _aggregate = null;
      _error = null;
    });

    final results = await SpeedIndexBacktestRunner.runBatch(
      targets,
      horseRepo: _horseRepo,
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() {
          _batchDone = done;
        });
      },
      onError: (race, error) {
        _batchErrorCount++;
      },
    );

    if (!mounted) return;
    setState(() {
      _batchResults = results;
      _aggregate = SpeedIndexBacktestAggregator.aggregate(results);
      _isBatchRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('スピード指数バックテスト（開発者用）')),
      body: _isLoadingCandidates
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                    _buildSingleRaceSection(),
                    const Divider(height: 32),
                    _buildBatchSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSingleRaceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '■ 単発実行（1レースでdevWith/devNone・ρ_with/ρ_none/Δρを確認）',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (_candidates.isEmpty)
          const Text('対象となるJRA確定済みレースが見つかりません。')
        else
          DropdownButton<RaceResult>(
            isExpanded: true,
            value: _selectedRace,
            items: _candidates
                .take(50)
                .map((r) => DropdownMenuItem(
                      value: r,
                      child: Text(
                        '${r.raceId} ${r.raceTitle}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _selectedRace = v),
          ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed:
              (_selectedRace == null || _isRunning) ? null : _runSelectedRace,
          child: _isRunning
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('選択レースで実行'),
        ),
        const SizedBox(height: 12),
        if (_result != null) _buildSingleRaceResultView(_result!),
      ],
    );
  }

  // [追加] ρ表示用のフォーマット。null(n<5等でスキップ)は"—(n=X)"と表示する (v.2026.9.4)
  String _formatRho(SpeedIndexBacktestRhoResult r) {
    if (r.rho == null) return '—(n=${r.n})';
    return '${r.rho!.toStringAsFixed(4)} (n=${r.n})';
  }

  Widget _buildSingleRaceResultView(SpeedIndexBacktestSingleRaceResult result) {
    final dRhoRaw = result.dRhoRaw;
    final dRhoTairetsu = result.dRhoTairetsu;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('raceId: ${result.raceResult.raceId}'),
        Text('raceName: ${result.raceResult.raceTitle}'),
        Text('asOf: ${result.asOf.toIso8601String().substring(0, 10)}'),
        Text(
            '${result.surface} ${result.distanceBand} / ${result.pace} / 平均confidence=${result.meanConfidence.toStringAsFixed(3)}'),
        Text('有効頭数: ${result.horseCount}'),
        Text('リーク防止で除外した過去走数（全馬合計）: ${result.excludedForFutureLeakCount}'),
        const SizedBox(height: 12),
        const Text('■ 主指標：直線処理後の生スコア(outFinalPositionScores)によるρ',
            style: TextStyle(fontWeight: FontWeight.bold)),
        Text('ρ_with（あり）: ${_formatRho(result.rhoWithRaw)}'),
        Text('ρ_none（なし）: ${_formatRho(result.rhoNoneRaw)}'),
        Text(
          'Δρ(主指標) = ρ_with − ρ_none: '
          '${dRhoRaw == null ? "—" : dRhoRaw.toStringAsFixed(4)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text('■ 副指標：直線隊列(development[\'直線\'])によるρ',
            style: TextStyle(fontWeight: FontWeight.bold)),
        Text('ρ_with（あり）: ${_formatRho(result.rhoWithTairetsu)}'),
        Text('ρ_none（なし）: ${_formatRho(result.rhoNoneTairetsu)}'),
        Text('Δρ(副指標) = ρ_with − ρ_none: '
            '${dRhoTairetsu == null ? "—" : dRhoTairetsu.toStringAsFixed(4)}'),
        Text(
            '直線の隊列が「あり／なし」で異なるか: ${result.tairetsuDiffers ? "異なる" : "同じ"}'),
        const SizedBox(height: 12),
        const Text('■ devWith（スピード指数あり）',
            style: TextStyle(fontWeight: FontWeight.bold)),
        for (final corner in kSpeedIndexBacktestAllCorners)
          Text('$corner: ${result.devWith[corner]}'),
        const SizedBox(height: 12),
        const Text('■ devNone（スピード指数なし）',
            style: TextStyle(fontWeight: FontWeight.bold)),
        for (final corner in kSpeedIndexBacktestAllCorners)
          Text('$corner: ${result.devNone[corner]}'),
      ],
    );
  }

  Widget _buildBatchSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '■ 全件実行（対象範囲をループし全体／距離帯別／ペース別／confidence帯別のΔρを集計）',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Text('対象候補レース数（JRA/非障害/確定/有効着順5頭以上）: ${_candidates.length}'),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('対象範囲: 直近'),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: TextField(
                controller: _rangeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text('件'),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed:
              (_candidates.isEmpty || _isBatchRunning) ? null : _runBatch,
          child: _isBatchRunning
              ? SizedBox(
                  height: 20,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text('実行中… $_batchDone/$_batchTotal'),
                    ],
                  ),
                )
              : const Text('全件実行（集計）'),
        ),
        const SizedBox(height: 12),
        if (_aggregate != null) _buildAggregateView(_aggregate!),
      ],
    );
  }

  Widget _buildAggregateView(SpeedIndexBacktestAggregate agg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('対象R数: ${_batchResults.length}（うちエラーでスキップ: $_batchErrorCount）'),
        const SizedBox(height: 8),
        _buildGroupStatsTile('全体', agg.overall),
        const SizedBox(height: 12),
        const Text('■ 距離帯別', style: TextStyle(fontWeight: FontWeight.bold)),
        for (final entry in agg.byDistanceBand.entries)
          _buildGroupStatsTile(entry.key, entry.value),
        const SizedBox(height: 12),
        const Text('■ ペース別', style: TextStyle(fontWeight: FontWeight.bold)),
        for (final entry in agg.byPace.entries)
          _buildGroupStatsTile(entry.key, entry.value),
        const SizedBox(height: 12),
        const Text('■ confidence帯別',
            style: TextStyle(fontWeight: FontWeight.bold)),
        for (final entry in agg.byConfidenceBand.entries)
          _buildGroupStatsTile(entry.key, entry.value),
      ],
    );
  }

  Widget _buildGroupStatsTile(String label, SpeedIndexBacktestGroupStats s) {
    final meanDRho = s.meanDRhoRaw;
    final posRatio = s.positiveDRhoRawRatio;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(
        '$label: 対象R=${s.raceCount} ρ算出可=${s.rhoCount} '
        'ρ_with平均=${s.meanRhoWithRaw?.toStringAsFixed(4) ?? "—"} '
        'ρ_none平均=${s.meanRhoNoneRaw?.toStringAsFixed(4) ?? "—"} '
        'Δρ平均=${meanDRho?.toStringAsFixed(4) ?? "—"} '
        'Δρ>0比率=${posRatio == null ? "—" : "${(posRatio * 100).toStringAsFixed(1)}%"} '
        '隊列変化率=${(s.tairetsuDiffRatio * 100).toStringAsFixed(1)}%',
      ),
    );
  }
}
