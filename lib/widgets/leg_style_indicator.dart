// lib/widgets/leg_style_indicator.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/analysis/leg_style_analyzer.dart';

class LegStyleIndicator extends StatelessWidget {
  final LegStyleProfile? legStyleProfile;

  const LegStyleIndicator({super.key, this.legStyleProfile});

  Color _getColorForPercentage(double percentage) {
    if (percentage >= 0.5) {
      return Colors.red; // 50%～ : 赤
    } else if (percentage >= 0.2) {
      return Colors.orange; // 20%～49% : オレンジ
    } else if (percentage > 0) {
      return Colors.blue; // 1%～19% : 青
    } else {
      return Colors.grey.shade500; // 0% : 無色 (薄いグレー)
    }
  }

  double _getOpacityForPercentage(double percentage) {
    if (percentage == 0) return 0.2; // 無色の場合は薄く
    // 10%単位で不透明度を計算 (例: 25% -> 0.3, 81% -> 0.9)
    return ((percentage * 10).ceil() / 10.0).clamp(0.1, 1.0);
  }

  // [追加] 脚質詳細ダイアログの1行（脚質／割合(orマクリ回数)／着度数／勝率） (v.2026.9.24+26092403)
  Widget _buildStyleDetailRow({
    required String label,
    required String middleText,
    required String recordText,
    required String winRateText,
    bool isHeader = false,
  }) {
    final TextStyle textStyle = isHeader
        ? const TextStyle(fontSize: 12, color: Colors.grey)
        : const TextStyle(fontSize: 13);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          SizedBox(width: 44, child: Text(label, style: textStyle)),
          SizedBox(
            width: 52,
            child: Text(middleText, style: textStyle, textAlign: TextAlign.right),
          ),
          Expanded(
            child: Text(recordText, style: textStyle, textAlign: TextAlign.center),
          ),
          SizedBox(
            width: 52,
            child: Text(winRateText, style: textStyle, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  void _showLegStyleDetailsDialog(BuildContext context, LegStyleProfile profile) {
    showDialog(
      context: context,
      builder: (context) {
        final distribution = profile.styleDistribution;
        const legStylesOrder = ['逃げ', '先行', '差し', '追込'];

        // [追加] マクリの着度数・回数・勝率を算出（回数>0のときだけ行を表示する） (v.2026.9.24+26092403)
        final List<int> makuriRecord =
            profile.styleRecordCounts['マクリ'] ?? const [0, 0, 0, 0];
        final int makuriCount =
            makuriRecord[0] + makuriRecord[1] + makuriRecord[2] + makuriRecord[3];
        final double makuriWinRate = (profile.styleWinRates['マクリ'] ?? 0.0) * 100;

        return AlertDialog(
          title: Text('脚質詳細 (${profile.primaryStyle})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('各脚質の割合:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                // [追加] 見出し行（割合／着度数／勝率） (v.2026.9.24+26092403)
                _buildStyleDetailRow(
                  label: '',
                  middleText: '割合',
                  recordText: '着度数',
                  winRateText: '勝率',
                  isHeader: true,
                ),
                // [追加] 4脚質の割合・着度数・勝率 (v.2026.9.24+26092403)
                ...legStylesOrder.map((style) {
                  final percentage = (distribution[style] ?? 0.0) * 100;
                  final record =
                      profile.styleRecordCounts[style] ?? const [0, 0, 0, 0];
                  final winRate = (profile.styleWinRates[style] ?? 0.0) * 100;
                  return _buildStyleDetailRow(
                    label: style,
                    middleText: '${percentage.toStringAsFixed(1)}%',
                    recordText:
                        '${record[0]}-${record[1]}-${record[2]}-${record[3]}',
                    winRateText: '${winRate.toStringAsFixed(1)}%',
                  );
                }).toList(),
                // [追加] マクリ行。割合の代わりに回数を表示し、回数>0のときのみ出す (v.2026.9.24+26092403)
                if (makuriCount > 0)
                  _buildStyleDetailRow(
                    label: 'マクリ',
                    middleText: '$makuriCount回',
                    recordText:
                        '${makuriRecord[0]}-${makuriRecord[1]}-${makuriRecord[2]}-${makuriRecord[3]}',
                    winRateText: '${makuriWinRate.toStringAsFixed(1)}%',
                  ),
                const Divider(height: 24),
                const Text('インジケーター凡例:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildLegendItem(_getColorForPercentage(0.5), '50%以上'),
                _buildLegendItem(_getColorForPercentage(0.2), '20% ～ 49%'),
                _buildLegendItem(_getColorForPercentage(0.01), '1% ～ 19%'),
                _buildLegendItem(_getColorForPercentage(0), '0%'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          _LegStyleSymbol(color: color, opacity: _getOpacityForPercentage(color == Colors.grey.shade500 ? 0.0 : 1.0)),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (legStyleProfile == null) {
      return const Text('-');
    }

    final distribution = legStyleProfile!.styleDistribution;
    const legStylesOrder = ['逃げ', '先行', '差し', '追込'];

    return InkWell(
      onTap: () => _showLegStyleDetailsDialog(context, legStyleProfile!),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40, // テキスト部分の幅を固定
            child: Text(
              legStyleProfile!.primaryStyle,
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          ...legStylesOrder.map((style) {
            final percentage = distribution[style] ?? 0.0;
            return _LegStyleSymbol(
              color: _getColorForPercentage(percentage),
              opacity: _getOpacityForPercentage(percentage),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _LegStyleSymbol extends StatelessWidget {
  final Color color;
  final double opacity;

  const _LegStyleSymbol({required this.color, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.0),
      child: Text(
        '◀',
        style: TextStyle(
          fontSize: 16,
          color: color.withOpacity(opacity),
        ),
      ),
    );
  }
}
