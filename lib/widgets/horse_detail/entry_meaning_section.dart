// lib/widgets/horse_detail/entry_meaning_section.dart

// [追加] 陣営の本気度指数 実施順6: 馬詳細タブ「情報・血統」の最下部に出す「出走の意味」。
// 計算の状態の注記、レース全体の注記（灰色の帯）、その馬の行（左端のラベル・事実・根拠の印・解釈）を並べる。
// データは受け取るだけで、読み込み・計算はしない (v.2026.10.3+26100308)

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/entry_meaning.dart';
import 'package:hetaumakeiba_v2/logic/entry_meaning_snapshot.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';

class EntryMeaningSection extends StatelessWidget {
  final PredictionHorseDetail horse;

  /// 出走の意味の計算結果（レース結果があるレースでは保存分）。まだ無ければ null
  final EntryMeaningSnapshot? snapshot;

  /// 計算（または保存分の読み出し）が1回終わったか
  final bool loaded;

  /// レース結果があるレース（保存分を出すだけ）か
  final bool isResultView;

  const EntryMeaningSection({
    super.key,
    required this.horse,
    required this.snapshot,
    required this.loaded,
    required this.isResultView,
  });

  /// 根拠の印の色（規則=青、一般論=橙、事実=灰、規則の限界=赤）
  static Color basisColor(EntryMeaningBasis basis) {
    switch (basis) {
      case EntryMeaningBasis.rule:
        return Colors.blue.shade700;
      case EntryMeaningBasis.general:
        return Colors.orange.shade800;
      case EntryMeaningBasis.fact:
        return Colors.grey.shade600;
      case EntryMeaningBasis.ruleLimit:
        return Colors.red.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = snapshot;
    if (current == null) {
      if (!loaded) {
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }
      return _message(isResultView
          ? 'レース前に計算していないため表示しません'
          : '出走の意味を計算できませんでした');
    }
    if (!current.meanings.isSupported) {
      return _message('地方・障害のレース、または開催日が読めないレースは対象外です');
    }

    final children = <Widget>[];
    final status = _statusText(current);
    if (status != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          status,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      ));
    }
    if (current.meanings.raceNotes.isNotEmpty) {
      children.add(_buildRaceNotes(current.meanings.raceNotes));
    }
    children.add(_buildHorseLines(current.horseOf(horse.horseId)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  /// 計算の状態の注記。出さないときは null。
  String? _statusText(EntryMeaningSnapshot current) {
    if (isResultView) {
      final t = current.computedAt;
      final when =
          '${t.month}/${t.day} ${t.hour}:${t.minute.toString().padLeft(2, '0')}';
      final suffix = current.preparation == EntryMeaningPreparation.done
          ? ''
          : '（過去走の取り直しが終わる前の計算）';
      return '$whenに計算した内容です$suffix';
    }
    switch (current.preparation) {
      case EntryMeaningPreparation.done:
        return null;
      case EntryMeaningPreparation.inProgress:
        return '過去走を取り直し中です。終わると自動で更新します';
      case EntryMeaningPreparation.failed:
        return '過去走の取り直しに失敗したため、今ある過去走で判定しています';
    }
  }

  /// レース全体の注記（灰色の帯。ラベルは最初の行だけ）
  Widget _buildRaceNotes(List<EntryMeaningLine> notes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < notes.length; i++)
            _buildLine(i == 0 ? entryMeaningGroupLabel(notes[i].kind) : '',
                notes[i]),
        ],
      ),
    );
  }

  /// その馬の行
  Widget _buildHorseLines(HorseEntryMeaning? meaning) {
    if (meaning == null) {
      return _message('この馬の計算結果がありません');
    }
    if (meaning.isScratched) {
      return _message('出走取消');
    }
    if (meaning.lines.isEmpty) {
      return _message('該当する事柄はありません');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in meaning.lines)
          _buildLine(entryMeaningGroupLabel(line.kind), line),
      ],
    );
  }

  /// 1行: 左端のラベル／事実＋根拠の印／（あれば）→ 解釈
  Widget _buildLine(String label, EntryMeaningLine line) {
    final color = basisColor(line.basis);
    final interpretation = line.interpretation;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: line.fact,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.black87),
                      ),
                      const WidgetSpan(child: SizedBox(width: 4)),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: _buildBasisBadge(line.basis, color),
                      ),
                    ],
                  ),
                ),
                if (interpretation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      '→ $interpretation',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 根拠の印（色付きの小さな枠）
  Widget _buildBasisBadge(EntryMeaningBasis basis, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        entryMeaningBasisLabel(basis),
        style: TextStyle(fontSize: 10, color: color, height: 1.2),
      ),
    );
  }

  /// 灰色の1行
  Widget _message(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      ),
    );
  }
}
