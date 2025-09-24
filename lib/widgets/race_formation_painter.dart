// lib/widgets/race_formation_painter.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';

// 馬の情報を描画用にまとめるためのヘルパークラス
class _HorseInfoForPaint {
  final int horseNumber;
  final int gateNumber;
  _HorseInfoForPaint(this.horseNumber, this.gateNumber);
}

// 俯瞰図を表示するためのメインウィジェット
class RaceFormationDiagram extends StatelessWidget {
  final String prediction; // "(1,2)-3-4" のような隊列文字列
  final List<PredictionHorseDetail> horses; // 全出走馬のリスト

  const RaceFormationDiagram({
    super.key,
    required this.prediction,
    required this.horses,
  });

  // 枠番に応じた色を取得するヘルパー
  Color _getGateColor(int gateNumber) {
    switch (gateNumber) {
      case 1: return Colors.white;
      case 2: return Colors.black;
      case 3: return Colors.red;
      case 4: return Colors.blue;
      case 5: return Colors.yellow;
      case 6: return Colors.green;
      case 7: return Colors.orange;
      case 8: return Colors.pink.shade200;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 隊列文字列を解析して、描画用のデータ構造に変換
    final List<List<_HorseInfoForPaint>> horseGroups = [];
    final horseMap = {for (var h in horses) h.horseNumber: h};

    // 正規表現で()で囲まれたグループと単独の馬番を抽出
    final RegExp exp = RegExp(r'\((\d+(?:,\d+)*)\)|(\d+)');
    exp.allMatches(prediction).forEach((match) {
      final List<_HorseInfoForPaint> group = [];
      String content = match.group(1) ?? match.group(2)!;
      content.split(',').forEach((numStr) {
        final horseNumber = int.parse(numStr);
        final horseDetail = horseMap[horseNumber];
        if (horseDetail != null) {
          group.add(_HorseInfoForPaint(horseDetail.horseNumber, horseDetail.gateNumber));
        }
      });
      if (group.isNotEmpty) {
        horseGroups.add(group);
      }
    });

    return SizedBox(
      height: 120, // 描画領域の高さ
      width: double.infinity,
      child: CustomPaint(
        painter: _RaceFormationPainter(
          horseGroups: horseGroups,
          getGateColor: _getGateColor,
        ),
      ),
    );
  }
}

// 実際の描画処理を行うCustomPainter
class _RaceFormationPainter extends CustomPainter {
  final List<List<_HorseInfoForPaint>> horseGroups;
  final Color Function(int) getGateColor;

  _RaceFormationPainter({required this.horseGroups, required this.getGateColor});

  @override
  void paint(Canvas canvas, Size size) {
    // --- コースの描画 ---
    final trackPaint = Paint()
      ..color = Colors.green.shade100
      ..style = PaintingStyle.fill;
    final trackPath = Path()
      ..moveTo(0, size.height * 0.2)
      ..quadraticBezierTo(size.width * 0.5, -size.height * 0.2, size.width, size.height * 0.2)
      ..lineTo(size.width, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.5, size.height * 1.2, 0, size.height * 0.8)
      ..close();
    canvas.drawPath(trackPath, trackPaint);

    final linePaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(trackPath, linePaint);


    // --- 馬の描画 ---
    const horseRadius = 10.0;
    final double groupSpacingY = (size.height - 2 * horseRadius) / (horseGroups.length + 1);

    for (int i = 0; i < horseGroups.length; i++) {
      final group = horseGroups[i];
      final double groupY = groupSpacingY * (i + 1);
      final double groupSpacingX = size.width / (group.length + 1);

      // 枠番でソートして内側の馬から描画
      group.sort((a, b) => a.gateNumber.compareTo(b.gateNumber));

      for (int j = 0; j < group.length; j++) {
        final horse = group[j];
        final double horseX = groupSpacingX * (j + 1);

        // 円の色
        final circlePaint = Paint()..color = getGateColor(horse.gateNumber);
        if (horse.gateNumber == 1 || horse.gateNumber == 5) {
          circlePaint.style = PaintingStyle.stroke;
          circlePaint.strokeWidth = 1.5;
          circlePaint.color = Colors.black;
          canvas.drawCircle(Offset(horseX, groupY), horseRadius, Paint()..color = Colors.white);
        }

        canvas.drawCircle(Offset(horseX, groupY), horseRadius, circlePaint);

        // テキストの色
        final textColor = (horse.gateNumber == 1 || horse.gateNumber == 5) ? Colors.black : Colors.white;
        final textPainter = TextPainter(
          text: TextSpan(
            text: horse.horseNumber.toString(),
            style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(canvas, Offset(horseX - textPainter.width / 2, groupY - textPainter.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}