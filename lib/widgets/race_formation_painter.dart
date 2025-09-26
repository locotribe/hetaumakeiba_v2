// lib/widgets/race_formation_painter.dart

import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:hetaumakeiba_v2/models/ai_prediction_race_data.dart';
import 'package:hetaumakeiba_v2/models/course_preset_model.dart';

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
  final CoursePreset? coursePreset; // コース情報を追加

  const RaceFormationDiagram({
    super.key,
    required this.prediction,
    required this.horses,
    this.coursePreset, // コンストラクタに追加
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
          coursePreset: coursePreset, // Painterにコース情報を渡す
        ),
      ),
    );
  }
}

// 実際の描画処理を行うCustomPainter
class _RaceFormationPainter extends CustomPainter {
  final List<List<_HorseInfoForPaint>> horseGroups;
  final Color Function(int) getGateColor;
  final CoursePreset? coursePreset; // coursePresetを受け取る

  _RaceFormationPainter({required this.horseGroups, required this.getGateColor, this.coursePreset});

  @override
  void paint(Canvas canvas, Size size) {
    // --- コースの描画 ---
    final trackPaint = Paint()
      ..color = Colors.green.shade100
      ..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromLTWH(0, size.height * 0.1, size.width, size.height * 0.8);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(50));
    canvas.drawRRect(rrect, trackPaint);
    canvas.drawRRect(rrect, linePaint);

    // --- 馬の描画 ---
    const horseRadius = 10.0;
    final double totalGroups = horseGroups.isNotEmpty ? horseGroups.length.toDouble() : 1.0;
    final double availableWidth = size.width * 0.8; // 左右に少し余白を持たせる
    final double startX = size.width * 0.1;

    for (int i = 0; i < horseGroups.length; i++) {
      final group = horseGroups[i];
      // 隊列の位置をコースの右から左へ（ゴール方向）に配置
      final double groupX = startX + availableWidth * (1 - (i / (totalGroups > 1 ? totalGroups - 1 : 1.0)));

      final double totalHorsesInGroup = group.length.toDouble();
      final double availableHeight = size.height * 0.7; // 縦の配置可能領域を調整
      final double startY = size.height * 0.15;

      // 枠番でソートして内側の馬から描画
      group.sort((a, b) => a.gateNumber.compareTo(b.gateNumber));

      for (int j = 0; j < group.length; j++) {
        final horse = group[j];
        // 馬を縦方向に均等に配置
        double horseY = startY + availableHeight * (j / (totalHorsesInGroup > 1 ? totalHorsesInGroup - 1 : 1.0).clamp(1.0, double.infinity));
        // 偶数番目の馬を少しずらして自然に見せる
        final double jitter = (j % 2 == 0) ? -horseRadius * 0.3 : horseRadius * 0.3;
        final double horseX = groupX + jitter;


        // 円の色
        final circlePaint = Paint()..color = getGateColor(horse.gateNumber);
        if (horse.gateNumber == 1) { // 1枠は白なので枠線を描画
          circlePaint.style = PaintingStyle.stroke;
          circlePaint.strokeWidth = 1.5;
          circlePaint.color = Colors.black;
          canvas.drawCircle(Offset(horseX, horseY), horseRadius, Paint()..color = Colors.white..style = PaintingStyle.fill);
        }

        canvas.drawCircle(Offset(horseX, horseY), horseRadius, circlePaint);

        // テキストの色
        final textColor = (horse.gateNumber == 1 || horse.gateNumber == 5) ? Colors.black : Colors.white;
        final textPainter = TextPainter(
          text: TextSpan(
            text: horse.horseNumber.toString(),
            style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        textPainter.paint(canvas, Offset(horseX - textPainter.width / 2, horseY - textPainter.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RaceFormationPainter oldDelegate) {
    return oldDelegate.horseGroups != horseGroups || oldDelegate.coursePreset != coursePreset;
  }
}