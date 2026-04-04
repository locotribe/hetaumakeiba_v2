// lib/widgets/odds_tabs/odds_analysis_tab.dart

import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/race_data.dart';
import '../../utils/gate_color_utils.dart';

class _HorseAnalysis {
  final PredictionHorseDetail horse;
  final int ninki;
  final double tanshoOdds;
  final double uRatio;
  final double utRatio;
  final double wRatio;
  String mark = '';
  String type = '';
  String reason = '';
  String confidenceScore = '';

  _HorseAnalysis({
    required this.horse,
    required this.ninki,
    required this.tanshoOdds,
    required this.uRatio,
    required this.utRatio,
    required this.wRatio,
  });
}

class OddsAnalysisTab extends StatefulWidget {
  final Map<String, List<Map<String, String>>> allOddsData;
  final PredictionRaceData raceData;

  const OddsAnalysisTab({
    super.key,
    required this.allOddsData,
    required this.raceData,
  });

  @override
  State<OddsAnalysisTab> createState() => _OddsAnalysisTabState();
}

class _OddsAnalysisTabState extends State<OddsAnalysisTab> {
  List<_HorseAnalysis> _analyzedList = [];
  bool _hasSufficientData = false;
  String _recommendedApproach = '';

  @override
  void initState() {
    super.initState();
    _analyzeOdds();
  }

  @override
  void didUpdateWidget(OddsAnalysisTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _analyzeOdds();
  }

  void _analyzeOdds() {
    final tanshoData = widget.allOddsData['b1'] ?? [];
    final umarenData = widget.allOddsData['b4'] ?? [];
    final wideData = widget.allOddsData['b5'] ?? [];
    final umatanData = widget.allOddsData['b6'] ?? [];

    if (tanshoData.isEmpty || umarenData.isEmpty || wideData.isEmpty || umatanData.isEmpty) {
      setState(() => _hasSufficientData = false);
      return;
    }

    Map<int, double> tanshoSupport = {};
    Map<int, double> tanshoOddsMap = {};
    Map<int, double> umarenSupport = {};
    Map<int, double> umatanSupport = {};
    Map<int, double> wideSupport = {};

    for (var item in tanshoData) {
      final combo = item['combination'] ?? '';
      if (combo.startsWith('1_') || (!combo.contains('_') && combo.length <= 2)) {
        int horseNum = int.tryParse(combo.contains('_') ? combo.split('_').last : combo) ?? 0;
        double odds = double.tryParse(item['odds'] ?? '') ?? 0.0;
        if (horseNum > 0 && odds > 0) {
          tanshoSupport[horseNum] = 1.0 / odds;
          tanshoOddsMap[horseNum] = odds;
        }
      }
    }

    var sortedTansho = tanshoOddsMap.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    Map<int, int> ninkiMap = {};
    for (int i = 0; i < sortedTansho.length; i++) {
      ninkiMap[sortedTansho[i].key] = i + 1;
    }

    List<int> parseCombo(String combo) {
      String s = combo;
      if (s.contains('-')) {
        s = s.split('-').last;
      } else if (s.contains('_')) {
        s = s.split('_').last;
      }

      if (s.length >= 4) {
        return [
          int.tryParse(s.substring(0, 2)) ?? 0,
          int.tryParse(s.substring(2, 4)) ?? 0
        ];
      }
      return [];
    }

    for (var item in umarenData) {
      double odds = double.tryParse(item['odds']?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '') ?? 0.0;
      if (odds > 0) {
        var horses = parseCombo(item['combination'] ?? '');
        if (horses.length == 2) {
          if (tanshoSupport.containsKey(horses[0])) umarenSupport[horses[0]] = (umarenSupport[horses[0]] ?? 0) + 1.0 / odds;
          if (tanshoSupport.containsKey(horses[1])) umarenSupport[horses[1]] = (umarenSupport[horses[1]] ?? 0) + 1.0 / odds;
        }
      }
    }

    for (var item in wideData) {
      String oddsStr = item['odds']?.replaceAll(RegExp(r'[^\d.-]'), ' ').split(' ').firstWhere((e) => e.isNotEmpty, orElse: () => '') ?? '';
      double odds = double.tryParse(oddsStr) ?? 0.0;
      if (odds > 0) {
        var horses = parseCombo(item['combination'] ?? '');
        if (horses.length == 2) {
          if (tanshoSupport.containsKey(horses[0])) wideSupport[horses[0]] = (wideSupport[horses[0]] ?? 0) + 1.0 / odds;
          if (tanshoSupport.containsKey(horses[1])) wideSupport[horses[1]] = (wideSupport[horses[1]] ?? 0) + 1.0 / odds;
        }
      }
    }

    for (var item in umatanData) {
      double odds = double.tryParse(item['odds']?.replaceAll(RegExp(r'[^0-9.]'), '') ?? '') ?? 0.0;
      if (odds > 0) {
        var horses = parseCombo(item['combination'] ?? '');
        if (horses.length == 2) {
          if (tanshoSupport.containsKey(horses[0])) umatanSupport[horses[0]] = (umatanSupport[horses[0]] ?? 0) + 1.0 / odds;
        }
      }
    }

    double totalTansho = tanshoSupport.values.fold(0.0, (a, b) => a + b);
    double totalUmaren = umarenSupport.values.fold(0.0, (a, b) => a + b);
    double totalUmatan = umatanSupport.values.fold(0.0, (a, b) => a + b);
    double totalWide = wideSupport.values.fold(0.0, (a, b) => a + b);

    List<_HorseAnalysis> list = [];
    for (var horse in widget.raceData.horses) {
      int hn = horse.horseNumber;
      if (!tanshoSupport.containsKey(hn)) continue;

      double tOdds = tanshoOddsMap[hn] ?? 0.0;
      double tShare = totalTansho > 0 ? (tanshoSupport[hn]! / totalTansho) : 0;
      double uShare = totalUmaren > 0 ? ((umarenSupport[hn] ?? 0) / totalUmaren) : 0;
      double utShare = totalUmatan > 0 ? ((umatanSupport[hn] ?? 0) / totalUmatan) : 0;
      double wShare = totalWide > 0 ? ((wideSupport[hn] ?? 0) / totalWide) : 0;

      list.add(_HorseAnalysis(
        horse: horse,
        ninki: ninkiMap[hn] ?? 0,
        tanshoOdds: tOdds,
        uRatio: tShare > 0 ? uShare / tShare : 0,
        utRatio: tShare > 0 ? utShare / tShare : 0,
        wRatio: tShare > 0 ? wShare / tShare : 0,
      ));
    }

    var sortedByU = List<_HorseAnalysis>.from(list)..sort((a, b) => b.uRatio.compareTo(a.uRatio));

    // 【◎ 本命】
    var honmeiCandidates = sortedByU.where((e) => e.mark.isEmpty && e.tanshoOdds < 100.0 && e.ninki <= 5).toList();
    if (honmeiCandidates.isNotEmpty) {
      var h = honmeiCandidates.first;
      h.mark = '◎';
      h.type = '本命・絶対軸';
      double gap = honmeiCandidates.length > 1 ? h.uRatio - honmeiCandidates[1].uRatio : 0.5;
      if (h.uRatio >= 1.3 && gap >= 0.2) {
        h.confidenceScore = 'S (鉄板)';
        h.reason = '圧倒的な連勝支持を集めており、2番手以降を大きく引き離す不動の軸です。アタマ固定や1頭軸として最適です。';
      } else if (h.uRatio >= 1.15) {
        h.confidenceScore = 'A (優秀)';
        h.reason = '上位人気馬の中で連勝馬券での支持が最も高く、手堅い軸として信頼できます。';
      } else {
        h.confidenceScore = 'B (僅差)';
        h.reason = '連勝支持はトップですが他馬との差はわずかです。混戦からの押し出しの可能性があり、連軸向きです。';
      }
    }

    // 【○ 対抗】
    var taikouCandidates = sortedByU.where((e) => e.mark.isEmpty && e.tanshoOdds < 100.0 && e.ninki <= 7).toList();
    if (taikouCandidates.isNotEmpty) {
      var h = taikouCandidates.first;
      h.mark = '○';
      h.type = '対抗・逆転候補';
      if (h.uRatio >= 1.1) {
        h.confidenceScore = 'A (優秀)';
        h.reason = '本命に次ぐ連対期待値があり、しっかりとした資金流入が確認できます。◎が崩れた場合の逆転候補筆頭です。';
      } else {
        h.confidenceScore = 'B (標準)';
        h.reason = 'オッズ通りの支持を集めています。相手筆頭として無難な選択です。';
      }
    }

    // 【▲ 単穴】
    var tananaCandidates = list.where((e) => e.mark.isEmpty && e.tanshoOdds < 100.0).toList()..sort((a, b) => b.utRatio.compareTo(a.utRatio));
    if (tananaCandidates.isNotEmpty && tananaCandidates.first.utRatio > 1.05) {
      var h = tananaCandidates.first;
      h.mark = '▲';
      h.type = '単穴・一発候補';
      h.confidenceScore = h.utRatio >= 1.2 ? 'A (強力)' : 'B (標準)';
      h.reason = '単勝以上に馬単（1着）として買われており、一発で突き抜ける可能性を秘めています。';
    }

    // 【★ 穴】
    var anaCandidates = list.where((e) => e.mark.isEmpty && e.tanshoOdds < 100.0 && e.ninki >= 6).toList();
    if (anaCandidates.isNotEmpty) {
      anaCandidates.sort((a, b) => max(b.uRatio, b.wRatio).compareTo(max(a.uRatio, a.wRatio)));
      var h = anaCandidates.first;
      double maxRatio = max(h.uRatio, h.wRatio);
      if (maxRatio > 1.1) {
        h.mark = '★';
        h.type = '特注穴・高配当の鍵';
        if (maxRatio >= 1.5) {
          h.confidenceScore = 'S (異常投票)';
          h.reason = '極めて異常な資金流入が検知されました。3着以内に激走し高配当を演出する要注意馬です。';
        } else {
          h.confidenceScore = 'A (高期待値)';
          h.reason = '人気はありませんが、連勝馬券で確かな支持を集めておりヒモ穴として優秀です。';
        }
      }
    }

    // 【消】 明確な危険馬
    for (var h in list.where((e) => e.mark.isEmpty && e.tanshoOdds < 100.0 && e.ninki <= 4)) {
      if (h.uRatio < 0.7 && h.wRatio < 0.7) {
        h.mark = '消';
        h.type = '過剰人気・危険な罠';
        if (h.uRatio < 0.6 && h.wRatio < 0.6) {
          h.confidenceScore = 'S (完全消し)';
          h.reason = '連勝馬券での支持が致命的に低く、大衆の罠である可能性が極めて高いです。切って妙味を狙えます。';
        } else {
          h.confidenceScore = 'A (軽視推奨)';
          h.reason = '単勝ばかりが売れており、連勝馬券では見放されています。見掛け倒しで飛ぶ確率が高いです。';
        }
      }
    }

    // 【△ 連下】
    var renkaCandidates = list.where((e) => e.mark.isEmpty && e.tanshoOdds < 100.0 && (e.uRatio >= 1.05 || e.wRatio >= 1.05)).toList();
    renkaCandidates.sort((a, b) => max(b.uRatio, b.wRatio).compareTo(max(a.uRatio, a.wRatio)));
    int renkaCount = 0;
    for (var h in renkaCandidates) {
      if (renkaCount >= 4) break;
      h.mark = '△';
      h.type = '連下・ヒモ候補';
      h.confidenceScore = 'B';
      h.reason = 'オッズ以上に連で売れており、3着以内に滑り込む相手候補として買える1頭です。';
      renkaCount++;
    }

    // 【× バツ】
    var batsuCandidates = list.where((e) => e.mark.isEmpty && e.tanshoOdds < 100.0 && e.ninki <= 8 && e.uRatio >= 0.8).toList();
    batsuCandidates.sort((a, b) => b.uRatio.compareTo(a.uRatio));
    int batsuCount = 0;
    for (var h in batsuCandidates) {
      if (batsuCount >= 2) break;
      h.mark = '×';
      h.type = '押さえ評価';
      h.confidenceScore = 'C';
      h.reason = '目立ったオッズの異常はありませんが、能力的に押さえておきたい1頭です。';
      batsuCount++;
    }

    // 【夢】
    var dreamCandidates = list.where((e) => e.mark.isEmpty).toList();
    if (dreamCandidates.isNotEmpty) {
      dreamCandidates.sort((a, b) => max(b.uRatio, b.wRatio).compareTo(max(a.uRatio, a.wRatio)));
      var h = dreamCandidates.first;
      h.mark = '夢';
      h.type = '爆穴・ロマン枠';
      h.confidenceScore = 'C (ロマン・宝くじ)';
      h.reason = '厳しい基準からは漏れましたが、無印の伏兵陣の中では最も連勝馬券（ワイド等）で怪しい支持を集めている1頭です。100円だけ夢を買うならこの馬です。';
    }

    // [修正] 人気がある（単勝9.9倍以下）のに印がなかった馬を「危険な人気馬」として強調抽出 (v5.0)
    for (var h in list.where((e) => e.mark.isEmpty && e.tanshoOdds <= 9.9)) {
      h.mark = '危';
      h.type = '危険な人気馬';
      if (h.uRatio < 0.7) {
        h.confidenceScore = 'S (完全消し推奨)';
        h.reason = 'これだけの支持を集めながら連勝馬券のシェアが致命的に低く、プロからは完全に見放されています。飛ぶ確率が非常に高い罠馬です。';
      } else {
        h.confidenceScore = 'A (軽視推奨)';
        h.reason = '人気上位ですが、連勝馬券での支持が凡庸であり期待値がありません。積極的に買う理由は薄く、切って妙味を狙うべき1頭です。';
      }
    }

    // 残った上位人気馬（10倍以上15倍以下などの準人気馬）
    for (var h in list.where((e) => e.mark.isEmpty && e.ninki <= 5)) {
      h.mark = '危';
      h.type = '見送り・凡庸';
      h.confidenceScore = 'B (静観・ヒモまで)';
      h.reason = '掲示板圏内の人気ですが、オッズに見合うだけの連勝支持がありません。ヒモまでとするか、思い切って切るのが妥当です。';
    }

    // 残った全馬を「静」に分類
    for (var h in list.where((e) => e.mark.isEmpty)) {
      h.mark = '静';
      h.type = '静観・完全消し';
      h.confidenceScore = 'C (消し)';
      h.reason = 'オッズ通りの低い支持に留まっており、プロの資金流入などの怪しい動きも検知されませんでした。今回は見送りが妥当です。';
    }

    list.sort((a, b) => _getMarkPriority(a.mark).compareTo(_getMarkPriority(b.mark)));

    bool hasHonmei = list.any((e) => e.mark == '◎');
    bool hasTaikou = list.any((e) => e.mark == '○');
    int holeCount = list.where((e) => e.mark == '★' || e.mark == '△').length;

    if (!hasHonmei) {
      _recommendedApproach = '大混戦。プロの明確な資金集中が見られません。見送り（ケン）を推奨するか、買う場合は▲や★の単複・ワイドの手広く薄い狙いが無難です。';
    } else if (hasHonmei && hasTaikou && holeCount <= 1) {
      _recommendedApproach = '上位拮抗。◎と○の馬連・ワイド1点、または◎からの単勝を推奨します。波乱の可能性は低めです。';
    } else if (hasHonmei && holeCount >= 2) {
      _recommendedApproach = 'ヒモ荒れ警戒。◎を軸とした馬連流し、または◎から手広く流す三連複フォーメーションを推奨します。';
    } else {
      _recommendedApproach = '軸信頼。◎からの馬連・馬単流しを推奨します。';
    }

    setState(() {
      _analyzedList = list;
      _hasSufficientData = true;
    });
  }

  int _getMarkPriority(String mark) {
    switch (mark) {
      case '◎': return 1;
      case '○': return 2;
      case '▲': return 3;
      case '△': return 4;
      case '★': return 5;
      case '×': return 6;
      case '消': return 7;
      case '夢': return 8;
      case '危': return 9;
      case '静': return 10;
      default: return 99;
    }
  }

  Color _getGateBgColor(int gateNum) {
    return gateNum.gateBackgroundColor;
  }

  Color _getGateTextColor(int gateNum) {
    return gateNum.gateTextColor;
  }

  TextSpan _buildRatioSpan(String label, double ratio) {
    int pct = (ratio * 100).toInt();
    Color color;
    FontWeight weight = FontWeight.normal;

    if (pct >= 120) {
      color = Colors.red.shade700;
      weight = FontWeight.bold;
    } else if (pct >= 105) {
      color = Colors.black;
      weight = FontWeight.bold;
    } else if (pct >= 80) {
      color = Colors.grey.shade600;
    } else {
      color = Colors.blue.shade700;
    }

    return TextSpan(
      children: [
        TextSpan(text: '$label ', style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
        TextSpan(text: '[$pct%]  ', style: TextStyle(color: color, fontWeight: weight, fontSize: 13)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasSufficientData) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                '分析に必要なオッズデータを\n自動取得・計算しています...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(8.0),
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4.0),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'この分析ツールの仕組みと見方',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 6),
              Text(
                '本ツールは「単勝オッズ（大衆人気）」と「連勝馬券（プロ・大口の資金動向）」の売れ方のギャップを計算し、オッズの歪み（期待値）を抽出するシステムです。\n絶対の的中を保証するものではなく、市場の評価を算数で解き明かした「ひとつの読み物・参考指標」として、馬券の取捨選択にお役立てください。',
                style: TextStyle(fontSize: 13, height: 1.4, color: Colors.black87),
              ),
            ],
          ),
        ),

        Container(
          margin: const EdgeInsets.only(bottom: 12.0),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.blueGrey.shade50,
            border: Border.all(color: Colors.blueGrey.shade200),
            borderRadius: BorderRadius.circular(4.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '【 レース推奨アプローチ 】',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                _recommendedApproach,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),

        ..._analyzedList.map((analysis) {
          final horse = analysis.horse;
          final gateNum = horse.gateNumber;

          final isDream = analysis.mark == '夢';
          final isDanger = analysis.mark == '危' || analysis.mark == '消';
          final isNegative = isDanger || analysis.mark == '静';

          // [修正] 単勝9.9倍以下を「赤いオッズ」として判定 (v5.0)
          final isRedOdds = analysis.tanshoOdds <= 9.9;

          Color markColor = Colors.black87;
          if (isDream) markColor = Colors.pink.shade700;
          else if (isDanger) markColor = Colors.red.shade900;
          else if (isNegative) markColor = Colors.grey.shade600;

          return Card(
            elevation: isDream ? 2 : 1,
            margin: const EdgeInsets.symmetric(vertical: 4.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: isDream ? BorderSide(color: Colors.pink.shade300, width: 1.5)
                  : (isDanger && isRedOdds ? BorderSide(color: Colors.red.shade300, width: 1.5) : BorderSide.none),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontFamily: 'sans-serif', color: Colors.black87),
                      children: [
                        TextSpan(
                          text: '${analysis.mark} 【${analysis.type}】 ',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: markColor),
                        ),
                        TextSpan(
                          text: '── 信頼度: ${analysis.confidenceScore}',
                          style: TextStyle(fontSize: 14, color: isDream ? Colors.pink.shade600 : (isDanger ? Colors.red.shade700 : Colors.grey.shade700), fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _getGateBgColor(gateNum),
                          borderRadius: BorderRadius.circular(2),
                          border: gateNum == 1 ? Border.all(color: Colors.grey.shade400) : Border.all(color: Colors.black.withOpacity(0.2)),
                        ),
                        child: Text(
                          horse.horseNumber.toString(),
                          style: TextStyle(color: _getGateTextColor(gateNum), fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          horse.horseName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isNegative ? Colors.grey.shade800 : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '(${analysis.ninki}番人気 / ',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                      // [修正] 単勝9.9倍以下の場合は赤太字で表示 (v5.0)
                      Text(
                        '${analysis.tanshoOdds.toStringAsFixed(1)}倍',
                        style: TextStyle(
                          fontSize: 13,
                          color: isRedOdds ? Colors.red : Colors.grey.shade700,
                          fontWeight: isRedOdds ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      Text(
                        ')',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(fontFamily: 'sans-serif'),
                      children: [
                        const TextSpan(text: '支持強度： ', style: TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.bold)),
                        _buildRatioSpan('馬連', analysis.uRatio),
                        _buildRatioSpan('馬単', analysis.utRatio),
                        _buildRatioSpan('ワイド', analysis.wRatio),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '※ ${analysis.reason}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
}