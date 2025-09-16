// lib/widgets/leg_style_indicator.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/ai/leg_style_analyzer.dart';

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
      return Colors.grey.shade300; // 0% : 無色 (薄いグレー)
    }
  }

  double _getOpacityForPercentage(double percentage) {
    if (percentage == 0) return 0.2; // 無色の場合は薄く
    // 10%単位で不透明度を計算 (例: 25% -> 0.3, 81% -> 0.9)
    return ((percentage * 10).ceil() / 10.0).clamp(0.1, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    if (legStyleProfile == null) {
      return const Text('-');
    }

    final distribution = legStyleProfile!.styleDistribution;
    const legStylesOrder = ['逃げ', '先行', '差し', '追い込み'];

    return Row(
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