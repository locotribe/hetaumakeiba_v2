// lib/widgets/race_page_tabs/race_detail_tab.dart

import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/models/race_data.dart';
import 'package:hetaumakeiba_v2/utils/gate_color_utils.dart';

class RaceDetailTab extends StatelessWidget {
  final String raceId;
  final RaceResult? raceResult;
  final List<PredictionHorseDetail>? predictionHorses;

  const RaceDetailTab({
    super.key,
    required this.raceId,
    this.raceResult,
    this.predictionHorses,
  });

  @override
  Widget build(BuildContext context) {
    if (raceResult == null || raceResult!.cornerPassages.isEmpty) {
      return const Center(
        child: Text('コーナー通過順位のデータがありません'),
      );
    }

    final bool isLeftDirection = raceResult!.raceInfo.contains('左');
    final bool isRightDirection = raceResult!.raceInfo.contains('右');

    // 勝ち時計を取得（ゴール板の横に表示するため）
    String winningTime = '';
    try {
      final firstPlace = raceResult!.horseResults.firstWhere((h) => h.rank == '1');
      winningTime = firstPlace.time;
    } catch (e) {
      // 取得できない場合は空文字
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'コーナー順位',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // 各コーナーの描画
          ...raceResult!.cornerPassages.map((passage) {
            return _buildCornerTrack(
              context,
              passage,
              raceResult!.horseResults,
              isLeft: isLeftDirection,
              isRight: isRightDirection,
            );
          }),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // ゴール板（フィニッシュ）のタイトル行
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'ゴール板（着差）',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              if (winningTime.isNotEmpty)
                Text(
                  '勝ち時計: $winningTime',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ゴール板の描画
          _buildFinishLine(
            context,
            raceResult!.horseResults,
            raceResult!.cornerPassages.isNotEmpty ? raceResult!.cornerPassages.last : '',
            isLeft: isLeftDirection,
            isRight: isRightDirection,
          ),

          // ラップタイムの描画
          if (raceResult!.lapTimes.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'ラップタイム',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildLapTimes(raceResult!.lapTimes),
          ],

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // ▼ 誤って消してしまっていた凡例（表）を復活 ▼
          _buildLegend(raceResult!.horseResults),

          const SizedBox(height: 32), // 一番下の余白
        ],
      ),
    );
  }

  /// 1つのコーナーごとのコースと馬の配置を描画する
  Widget _buildCornerTrack(BuildContext context, String passage, List<HorseResult> horses, {required bool isLeft, required bool isRight}) {
    String title = '';
    String data = passage;

    final match = RegExp(r'^(.*?コーナー|.*?角)[:\s]*(.*)$').firstMatch(passage);
    if (match != null) {
      title = match.group(1) ?? '';
      data = match.group(2) ?? passage;
    } else if (passage.contains('コーナー')) {
      final parts = passage.split('コーナー');
      title = '${parts[0]}コーナー';
      data = parts[1].replaceFirst(RegExp(r'^[:\s]+'), '');
    }

    String seq = data.replaceAll(' ', '').replaceAll(')(', '),(');
    seq = seq.replaceAllMapped(RegExp(r'\)([0-9\*])'), (m) => '),${m[1]}');
    seq = seq.replaceAllMapped(RegExp(r'([0-9])\('), (m) => '${m[1]},(');

    List<dynamic> items = [];
    int i = 0;
    List<String> currentGroup = [];
    bool inParentheses = false;
    String currentToken = "";

    while (i < seq.length) {
      String c = seq[i];
      if (c == '(') {
        inParentheses = true;
        if (currentToken.isNotEmpty) { currentGroup.add(currentToken); currentToken = ""; }
      } else if (c == ')') {
        inParentheses = false;
        if (currentToken.isNotEmpty) { currentGroup.add(currentToken); currentToken = ""; }
        if (currentGroup.isNotEmpty) { items.add(List<String>.from(currentGroup)); currentGroup.clear(); }
      } else if (c == ',' || c == '-' || c == '=') {
        if (inParentheses) {
          if (currentToken.isNotEmpty) { currentGroup.add(currentToken); currentToken = ""; }
        } else {
          if (currentToken.isNotEmpty) {
            currentGroup.add(currentToken); currentToken = "";
            items.add(List<String>.from(currentGroup)); currentGroup.clear();
          }
          items.add(c);
        }
      } else {
        currentToken += c;
      }
      i++;
    }
    if (currentToken.isNotEmpty) currentGroup.add(currentToken);
    if (currentGroup.isNotEmpty) items.add(List<String>.from(currentGroup));

    double currentX = 20.0;
    List<Widget> horseWidgets = [];
    List<String> top3Horses = [];

    for (var item in items) {
      if (item is String) {
        if (item == ',') currentX += 30.0;
        if (item == '-') currentX += 60.0;
        if (item == '=') currentX += 90.0;
      } else if (item is List<String>) {
        List<String> groupHorses = item;
        int count = groupHorses.length;

        for (int j = 0; j < count; j++) {
          String horseToken = groupHorses[j];
          bool isLeading = false;

          if (horseToken.startsWith('*')) {
            isLeading = true;
            horseToken = horseToken.substring(1);
          }

          if (top3Horses.length < 3) {
            top3Horses.add(horseToken);
          }

          String frameNumStr = "1";
          for (var h in horses) {
            if (h.horseNumber == horseToken) {
              frameNumStr = h.frameNumber;
              break;
            }
          }

          // ▼ 修正: Y座標の配置領域を圧縮し、上下のテロップ（帯）に被らないようにする
          // 利用可能領域を y=36 から y=100 (幅64px) に限定
          double yPos = (count == 1) ? 68.0 : 36.0 + (j * (64.0 / (count - 1)));
          double xPos = currentX;
          if (isLeading) xPos -= 12.0;

          horseWidgets.add(
            Positioned(
              left: isLeft ? null : xPos,
              right: isLeft ? xPos : null,
              top: yPos,
              child: _buildHorseMarker(horseToken, frameNumStr),
            ),
          );
        }
      }
    }

    double trackWidth = currentX + 50.0;
    if (trackWidth < 350) trackWidth = 350;

    // 左上のコーナー名テロップ (少しコンパクトに)
    Widget headerOverlay = Positioned(
      top: 6,
      left: isLeft ? null : 6,
      right: isLeft ? 6 : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isLeft ? '$title ⇨' : '⇦ $title',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );

    // 下部の先頭3頭表示テロップ (少し高さを抑える)
    Widget bottomOverlay = Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 30, // 34から30に縮小
        color: Colors.black.withOpacity(0.7),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          children: [
            const Text(
              '先頭:',
              style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            ...top3Horses.map((horseNum) {
              String fNum = "1";
              for (var h in horses) {
                if (h.horseNumber == horseNum) {
                  fNum = h.frameNumber;
                  break;
                }
              }
              return Padding(
                padding: const EdgeInsets.only(right: 6.0),
                // 馬アイコンも少し小さく(18px)
                child: _buildHorseMarker(horseNum, fNum, size: 18, fontSize: 10),
              );
            }),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Container(
        height: 160, // 高さを160に拡張
        decoration: BoxDecoration(
          color: const Color(0xFF8BC34A),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: isLeft,
              child: SizedBox(
                width: trackWidth,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: horseWidgets,
                ),
              ),
            ),
            headerOverlay,
            bottomOverlay,
          ],
        ),
      ),
    );
  }

  /// 最後のコーナーデータから、各馬のY座標を計算してMapで返す
  Map<String, double> _getLastCornerYPositions(String passage) {
    Map<String, double> yMap = {};
    if (passage.isEmpty) return yMap;

    final match = RegExp(r'^(.*?コーナー|.*?角)[:\s]*(.*)$').firstMatch(passage);
    String data = match != null ? (match.group(2) ?? passage) : passage.replaceFirst(RegExp(r'^.*?コーナー[:\s]*'), '');
    String seq = data.replaceAll(' ', '').replaceAll(')(', '),(');
    seq = seq.replaceAllMapped(RegExp(r'\)([0-9\*])'), (m) => '),${m[1]}');
    seq = seq.replaceAllMapped(RegExp(r'([0-9])\('), (m) => '${m[1]},(');

    List<dynamic> items = [];
    int i = 0;
    List<String> currentGroup = [];
    bool inParentheses = false;
    String currentToken = "";

    while (i < seq.length) {
      String c = seq[i];
      if (c == '(') {
        inParentheses = true;
        if (currentToken.isNotEmpty) { currentGroup.add(currentToken); currentToken = ""; }
      } else if (c == ')') {
        inParentheses = false;
        if (currentToken.isNotEmpty) { currentGroup.add(currentToken); currentToken = ""; }
        if (currentGroup.isNotEmpty) { items.add(List<String>.from(currentGroup)); currentGroup.clear(); }
      } else if (c == ',' || c == '-' || c == '=') {
        if (inParentheses) {
          if (currentToken.isNotEmpty) { currentGroup.add(currentToken); currentToken = ""; }
        } else {
          if (currentToken.isNotEmpty) {
            currentGroup.add(currentToken); currentToken = "";
            items.add(List<String>.from(currentGroup)); currentGroup.clear();
          }
          items.add(c);
        }
      } else {
        currentToken += c;
      }
      i++;
    }
    if (currentToken.isNotEmpty) currentGroup.add(currentToken);
    if (currentGroup.isNotEmpty) items.add(List<String>.from(currentGroup));

    for (var item in items) {
      if (item is List<String>) {
        int count = item.length;
        for (int j = 0; j < count; j++) {
          String horseToken = item[j].replaceAll('*', '');
          // コーナーと同じ圧縮されたY座標式を使用
          double yPos = (count == 1) ? 68.0 : 36.0 + (j * (64.0 / (count - 1)));
          yMap[horseToken] = yPos;
        }
      }
    }
    return yMap;
  }

  /// 着差の文字列をX座標（ピクセル）に変換する
  double _parseMarginToPixels(String margin) {
    if (margin.isEmpty || margin == '同着') return 0.0;
    if (margin.contains('ハナ')) return 3.0;
    if (margin.contains('アタマ')) return 6.0;
    if (margin.contains('クビ')) return 9.0;
    if (margin == '1/2') return 15.0;
    if (margin == '3/4') return 22.0;
    if (margin == '1') return 30.0;
    if (margin == '1.1/4') return 37.0;
    if (margin == '1.1/2') return 45.0;
    if (margin == '1.3/4') return 52.0;
    if (margin == '2') return 60.0;
    if (margin == '2.1/2') return 75.0;
    if (margin == '3') return 90.0;
    if (margin.contains('大')) return 150.0;

    double? val = double.tryParse(margin);
    if (val != null) return val * 30.0;

    final match = RegExp(r'^(\d+)\.(\d+)/(\d+)$').firstMatch(margin);
    if (match != null) {
      double whole = double.parse(match.group(1)!);
      double num = double.parse(match.group(2)!);
      double den = double.parse(match.group(3)!);
      return (whole + (num / den)) * 30.0;
    }

    final match2 = RegExp(r'^(\d+)/(\d+)$').firstMatch(margin);
    if (match2 != null) {
      double num = double.parse(match2.group(1)!);
      double den = double.parse(match2.group(2)!);
      return (num / den) * 30.0;
    }

    return 30.0;
  }

  /// ゴール板（固定ラインとパララックススクロール＋上がりテロップ）
  Widget _buildFinishLine(BuildContext context, List<HorseResult> sortedHorses, String lastCornerPassage, {required bool isLeft, required bool isRight}) {
    double screenWidth = MediaQuery.of(context).size.width - 32;
    double lineOffset = screenWidth * 0.2;

    Map<String, double> lastCornerYMap = _getLastCornerYPositions(lastCornerPassage);

    double currentX = 0.0;
    double maxNeededHeight = 160.0;
    List<Widget> horseWidgets = [];
    List<Rect> placedRects = [];

    // 1着〜3着の上がりタイム
    String agariText = "上り3F  ";
    for (int i = 1; i <= 3; i++) {
      try {
        final horse = sortedHorses.firstWhere((h) => h.rank == i.toString());
        if (horse.agari.isNotEmpty) {
          agariText += "$i着: ${horse.agari}   ";
        }
      } catch (e) {}
    }

    for (var horse in sortedHorses) {
      double marginPx = _parseMarginToPixels(horse.margin);
      currentX += marginPx;
      double finalY = lastCornerYMap[horse.horseNumber] ?? 68.0;

      // 衝突回避
      bool hasOverlap() {
        Rect currentRect = Rect.fromLTWH(currentX, finalY, 24, 24);
        for (var rect in placedRects) {
          if (currentRect.overlaps(rect.inflate(-2.0))) return true;
        }
        return false;
      }

      while (hasOverlap()) { finalY += 26.0; }

      placedRects.add(Rect.fromLTWH(currentX, finalY, 24, 24));
      // 下の上がりテロップ（高さ30）に被らないようにmaxNeededHeightを自動拡張
      maxNeededHeight = math.max(maxNeededHeight, finalY + 60.0);

      horseWidgets.add(
        Positioned(
          left: isLeft ? null : currentX,
          right: isLeft ? currentX : null,
          top: finalY,
          child: _buildHorseMarker(horse.horseNumber, horse.frameNumber),
        ),
      );
    }

    double trackWidth = currentX + (screenWidth * 0.8);

    // 左上のゴールテロップ
    Widget headerOverlay = Positioned(
      top: 6,
      left: isLeft ? null : 6,
      right: isLeft ? 6 : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          isLeft ? 'ゴール ⇨' : '⇦ ゴール',
          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );

    // 下部の上がりタイムテロップ
    Widget bottomOverlay = Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        height: 30,
        color: Colors.black.withOpacity(0.7),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.centerLeft,
        child: Text(
          agariText,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
        ),
      ),
    );

    return Container(
      height: maxNeededHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF8BC34A).withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Stack(
        children: [
          // スクロールする馬たち
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: isLeft,
            child: Padding(
              padding: EdgeInsets.only(
                left: isLeft ? 40.0 : lineOffset,
                right: isLeft ? lineOffset : 40.0,
              ),
              child: SizedBox(
                width: trackWidth,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: horseWidgets,
                ),
              ),
            ),
          ),
          // ゴール線
          Positioned(
            left: isLeft ? null : lineOffset + 12,
            right: isLeft ? lineOffset + 12 : null,
            top: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.8),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 0))],
                ),
              ),
            ),
          ),
          headerOverlay,
          bottomOverlay,
        ],
      ),
    );
  }

  /// ラップタイムのUI表示
  Widget _buildLapTimes(List<String> lapTimes) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1))]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: lapTimes.map((text) => Padding(
          padding: const EdgeInsets.only(bottom: 6.0),
          child: Text(
            text,
            style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w500
            ),
          ),
        )).toList(),
      ),
    );
  }

  /// 枠色に合わせた馬の丸アイコンを生成
  Widget _buildHorseMarker(String horseNum, String frameNum, {double size = 24, double fontSize = 12}) {
    Color bgColor = frameNum.gateBackgroundColor;
    Color textColor = frameNum.gateTextColor;
    bool hasBorder = frameNum == "1" || frameNum == "8" || frameNum.isEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
        border: hasBorder ? Border.all(color: Colors.black26, width: 1) : null,
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 2, offset: Offset(1, 1))],
      ),
      alignment: Alignment.center,
      child: Text(
        horseNum,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
    );
  }

  /// 3列縦並びの凡例
  Widget _buildLegend(List<HorseResult> horses) {
    int itemsPerColumn = (horses.length / 3).ceil();
    List<Widget> col1 = [];
    List<Widget> col2 = [];
    List<Widget> col3 = [];

    for (int i = 0; i < horses.length; i++) {
      Widget item = _buildLegendItem(horses[i]);
      if (i < itemsPerColumn) {
        col1.add(item);
      } else if (i < itemsPerColumn * 2) {
        col2.add(item);
      } else {
        col3.add(item);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: col1)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: col2)),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: col3)),
      ],
    );
  }

  /// 凡例の1行分
  Widget _buildLegendItem(HorseResult h) {
    String shortName = h.horseName.length > 3
        ? h.horseName.substring(0, 3)
        : h.horseName;

    String? ownerImagePath;
    if (predictionHorses != null) {
      try {
        final matchedHorse = predictionHorses!.firstWhere(
                (p) => p.horseNumber.toString() == h.horseNumber
        );
        ownerImagePath = matchedHorse.ownerImageLocalPath;
      } catch (e) {}
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '${h.rank}着',
              style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.bold),
            ),
          ),

          _buildHorseMarker(h.horseNumber, h.frameNumber),
          const SizedBox(width: 4),

          if (ownerImagePath != null && ownerImagePath.isNotEmpty)
            Image.file(
                File(ownerImagePath),
                width: 20,
                height: 20,
                errorBuilder: (c, e, s) => const SizedBox(width: 20, height: 20)
            )
          else
            const SizedBox(width: 20, height: 20),

          const SizedBox(width: 4),

          Expanded(
            child: Text(
              shortName,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}