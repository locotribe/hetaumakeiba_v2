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

    String firstPlaceNum = "";
    try {
      firstPlaceNum = horses.firstWhere((h) => h.rank == '1').horseNumber;
    } catch (_) {}

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

    // ▼ 追加: 縦に並ぶ最大頭数を計算
    int maxVerticalCount = 1;
    for (var item in items) {
      if (item is List<String> && item.length > maxVerticalCount) {
        maxVerticalCount = item.length;
      }
    }

    // 馬の配置間隔とコンテナの高さの自動計算
    double verticalPitch = 28.0; // 馬アイコンのサイズ(24) + 余白
    double startY = 32.0; // 上部のコーナー名テロップ用の余白
    double containerHeight = startY + (maxVerticalCount * verticalPitch) + 8.0;
    containerHeight = math.max(containerHeight, 80.0); // 最低高さを保証

    double currentX = 70.0;
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
          String rankStr = ""; // ▼ 追加: 着順を取得する変数を追加
          for (var h in horses) {
            if (h.horseNumber == horseToken) {
              frameNumStr = h.frameNumber;
              rankStr = h.rank; // ▼ 着順を保存
              break;
            }
          }

          // ▼ 追加: 着順によってアイコンとフォントのサイズを変更する
          double markerSize = 24.0;
          double markerFontSize = 12.0;
          if (rankStr == '1') {
            markerSize = 30.0; // 1着は一番大きく
            markerFontSize = 15.0;
          } else if (rankStr == '2' || rankStr == '3') {
            markerSize = 28.0; // 2, 3着も少し大きく
            markerFontSize = 14.0;
          }

          double yPos = startY + (j * verticalPitch);
          double xPos = currentX;
          if (isLeading) xPos -= 12.0;

          // ▼ 追加: 大きくなった分、中心位置をずらして元の座標の中心に合わせる
          double offsetAdjust = (markerSize - 24.0) / 2;

          bool isFirstPlace = (rankStr == '1');

          horseWidgets.add(
            Positioned(
              left: isLeft ? null : xPos - offsetAdjust,          // ▼ offsetAdjustを引く
              right: isLeft ? (xPos - offsetAdjust) : null,       // ▼ offsetAdjustを引く
              top: yPos - offsetAdjust,                           // ▼ offsetAdjustを引く
              child: _buildHorseMarker(
                horseToken,
                frameNumStr,
                isBlinkingRed: isFirstPlace,
                size: markerSize,        // ▼ 変更したサイズを渡す
                fontSize: markerFontSize,  // ▼ 変更したフォントサイズを渡す
              ),
            ),
          );
        }
      }
    }

    double screenWidth = MediaQuery.of(context).size.width - 32;
    double lineOffset = math.max(screenWidth * 0.2, 170.0);
    double trackWidth = math.max(currentX + 50.0, screenWidth);

    Widget headerOverlay = Positioned(
      top: 6,
      left: isLeft ? null : 6,
      right: isLeft ? 6 : null,
      child: IgnorePointer( // ← ここに IgnorePointer を追加
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
      ),
    );

    // ▼ 修正: オーバーレイをやめ、緑の枠の下に配置するためのWidgetを作成
    Widget top3Widget = Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 16.0), // 緑枠との隙間
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: top3Horses.map((horseNum) {
          String fNum = "1";
          String horseId = "";
          for (var h in horses) {
            if (h.horseNumber == horseNum) {
              fNum = h.frameNumber;
              horseId = h.horseId;
              break;
            }
          }

          String? ownerImagePath;
          String popAndOddsText = "";

          if (predictionHorses != null && horseId.isNotEmpty) {
            try {
              final matchedHorse = predictionHorses!.firstWhere((p) => p.horseId == horseId);
              ownerImagePath = matchedHorse.ownerImageLocalPath;

              String pop = matchedHorse.popularity != null ? '${matchedHorse.popularity}人気' : '';
              String odds = matchedHorse.odds != null ? '${matchedHorse.odds}倍' : '';
              if (pop.isNotEmpty || odds.isNotEmpty) {
                popAndOddsText = '$pop ${odds.isNotEmpty ? '($odds)' : ''}'.trim();
              }
            } catch (e) {}
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 6.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 3.0, offset: Offset(1, 2))],
                  ),
                  child: _buildHorseMarker(horseNum, fNum, size: 18, fontSize: 10),
                ),
                const SizedBox(width: 8),
                if (ownerImagePath != null && ownerImagePath.isNotEmpty)
                  Image.file(File(ownerImagePath), width: 20, height: 20, fit: BoxFit.contain, errorBuilder: (c, e, s) => const SizedBox(width: 20, height: 20))
                else
                  const SizedBox(width: 20, height: 20),
                if (popAndOddsText.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    popAndOddsText,
                    style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );

    // ▼ 修正: 自動計算した高さを持つ緑のトラック部分
    Widget trackContainer = Container(
      height: containerHeight,
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
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.only(
                left: isLeft ? 40.0 : lineOffset,
                right: isLeft ? lineOffset : 40.0,
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: trackWidth,
                  height: containerHeight,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Positioned.fill(child: ColoredBox(color: Colors.transparent)),
                      ...horseWidgets,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // IgnorePointerでラップして、コーナー名の上でもスクロール可能にする
          headerOverlay,
        ],
      ),
    );

    // ▼ 最終的にトラックと先頭3頭情報を縦に並べて返す
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        trackContainer,
        top3Widget,
      ],
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

    // ▼ _buildCornerTrack と同様のロジックでY座標を計算する
    int maxVerticalCount = 1;
    for (var item in items) {
      if (item is List<String> && item.length > maxVerticalCount) {
        maxVerticalCount = item.length;
      }
    }

    double verticalPitch = 28.0;
    double startY = 32.0;

    for (var item in items) {
      if (item is List<String>) {
        int count = item.length;
        for (int j = 0; j < count; j++) {
          String horseToken = item[j].replaceAll('*', '');
          double yPos = startY + (j * verticalPitch);
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

  /// ゴール板（固定ラインとパララックススクロール＋上がりテロップ＋電光掲示板）
  Widget _buildFinishLine(BuildContext context, List<HorseResult> sortedHorses, String lastCornerPassage, {required bool isLeft, required bool isRight}) {
    double screenWidth = MediaQuery.of(context).size.width - 32;
    // 画面の20% か、掲示板の幅(155)＋余白(15)＝170px のうち、大きい方をゴール線の位置にする
    double lineOffset = math.max(screenWidth * 0.2, 170.0);

    Map<String, double> lastCornerYMap = _getLastCornerYPositions(lastCornerPassage);

    double currentX = 0.0;
    // ▼ 電光掲示板ウィジェットが大きいため、初期の高さを250.0に拡張して見切れを防ぐ
    double maxNeededHeight = 320.0;
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

      // 衝突回避（当たり判定はデフォルトの24のままで計算してレイアウト崩れを防ぎます）
      bool hasOverlap() {
        Rect currentRect = Rect.fromLTWH(currentX, finalY, 24, 24);
        for (var rect in placedRects) {
          if (currentRect.overlaps(rect.inflate(-2.0))) return true;
        }
        return false;
      }

      while (hasOverlap()) { finalY += 26.0; }

      placedRects.add(Rect.fromLTWH(currentX, finalY, 24, 24));
      maxNeededHeight = math.max(maxNeededHeight, finalY + 60.0);

      // ▼ 追加: 着順によってサイズを変更する
      double markerSize = 24.0;
      double markerFontSize = 12.0;
      if (horse.rank == '1') {
        markerSize = 30.0;
        markerFontSize = 15.0;
      } else if (horse.rank == '2' || horse.rank == '3') {
        markerSize = 28.0;
        markerFontSize = 14.0;
      }

      // ▼ 追加: 大きくなった分、中心位置をずらす
      double offsetAdjust = (markerSize - 24.0) / 2;

      horseWidgets.add(
        Positioned(
          left: isLeft ? null : currentX - offsetAdjust,           // ▼ offsetAdjustを引く
          right: isLeft ? (currentX - offsetAdjust) : null,        // ▼ offsetAdjustを引く
          top: finalY - offsetAdjust,                              // ▼ offsetAdjustを引く
          child: _buildHorseMarker(
            horse.horseNumber,
            horse.frameNumber,
            isBlinkingRed: horse.rank == '1',
            size: markerSize,        // ▼ サイズを渡す
            fontSize: markerFontSize,  // ▼ フォントサイズを渡す
          ),
        ),
      );
    }

    double trackWidth = currentX + (screenWidth * 0.8);

    // ==========================================
    // ▼ JRA電光掲示板用のデータを抽出
    // ==========================================
    String venueName = "中央";
    if (raceId.length >= 6) {
      Map<String, String> venueMap = {
        '01': '札幌', '02': '函館', '03': '福島', '04': '新潟', '05': '東京',
        '06': '中山', '07': '中京', '08': '京都', '09': '阪神', '10': '小倉'
      };
      venueName = venueMap[raceId.substring(4, 6)] ?? "中央";
    }
    String raceNum = raceId.length >= 2 ? int.tryParse(raceId.substring(raceId.length - 2))?.toString() ?? "" : "";

    List<String> top5Horses = sortedHorses.take(5).map((h) => h.horseNumber).toList();
    List<String> top5Margins = sortedHorses.skip(1).take(4).map((h) => h.margin.replaceAll('.', ' ')).toList();

    String turfCondition = "--";
    String dirtCondition = "--";
    if (raceResult != null && raceResult!.raceInfo.contains('芝')) {
      final match = RegExp(r'芝[^\:]*\:\s*(良|稍重|重|不良)').firstMatch(raceResult!.raceInfo);
      if (match != null) turfCondition = match.group(1) ?? "良";
    }
    if (raceResult != null && raceResult!.raceInfo.contains('ダ')) {
      final match = RegExp(r'ダ[^\:]*\:\s*(良|稍重|重|不良)').firstMatch(raceResult!.raceInfo);
      if (match != null) dirtCondition = match.group(1) ?? "良";
    }

    // ▼ 新規修正: ラップタイム配列から3F・4Fを正確に計算する
    String time4FCalc = "--";
    String time3FCalc = "--";
    if (raceResult != null && raceResult!.lapTimes.isNotEmpty) {
      try {
        List<double> laps = [];
        for (var text in raceResult!.lapTimes) {
          // 「ペース」などの累計タイム行は計算に混ぜないようスキップ
          if (text.contains('ペース') || text.contains('通過')) continue;

          final matches = RegExp(r'(\d+\.\d+)').allMatches(text);
          List<double> tempLaps = [];
          for (final m in matches) {
            double val = double.parse(m.group(1)!);
            // 念のため、1ハロンのタイムとしてあり得る数値（20秒未満）のみを対象とする
            if (val < 20.0) {
              tempLaps.add(val);
            }
          }
          // 有効なラップタイムが取得できたらそれを採用してループを抜ける
          if (tempLaps.length >= 3) {
            laps = tempLaps;
            break;
          }
        }

        // 3Fの計算 (最後の3ハロンを合計)
        if (laps.length >= 3) {
          double sum3F = laps[laps.length - 3] + laps[laps.length - 2] + laps[laps.length - 1];
          time3FCalc = sum3F.toStringAsFixed(1);
        }
        // 4Fの計算 (最後の4ハロンを合計)
        if (laps.length >= 4) {
          double sum4F = laps[laps.length - 4] + laps[laps.length - 3] + laps[laps.length - 2] + laps[laps.length - 1];
          time4FCalc = sum4F.toStringAsFixed(1);
        }
      } catch (_) {}
    }

    // ▼ 左上のゴールテロップ（JRA電光掲示板）
    Widget headerOverlay = Positioned(
      top: 6,
      left: isLeft ? null : 6,
      right: isLeft ? 6 : null,
      child: RaceResultBoard(
        location: venueName,
        raceNumber: raceNum,
        horseNumbers: top5Horses,
        margins: top5Margins,
        turfCondition: turfCondition,
        dirtCondition: dirtCondition,
        time: sortedHorses.isNotEmpty ? sortedHorses.first.time : "--",
        time4F: time4FCalc, // 計算した4Fタイム
        time3F: time3FCalc, // 計算した3Fタイム（馬の上がりではなくレースラップから）
      ),
    );
    // ==========================================

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
            left: isLeft ? null : lineOffset + -5,
            right: isLeft ? lineOffset + -5 : null,
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
  Widget _buildHorseMarker(String horseNum, String frameNum, {double size = 24, double fontSize = 12, bool isBlinkingRed = false}) {
    // 1着馬の場合は、アニメーションする専用のウィジェットを返す
    if (isBlinkingRed) {
      return BlinkingRedHorseMarker(
        horseNum: horseNum,
        frameNum: frameNum,
        size: size,
        fontSize: fontSize,
      );
    }

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
        // ▼ 1着以外のすべての馬に薄い影を適用
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
        // ▼ 変更点: horseNumber ではなく horseId で検索する
        final matchedHorse = predictionHorses!.firstWhere(
                (p) => p.horseId == h.horseId
        );
        ownerImagePath = matchedHorse.ownerImageLocalPath;
      } catch (e) {
        // 見つからなかった場合は何もしない
      }
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

// ==========================================
// ▼ 新規追加: 電光掲示板風ウィジェット（レイアウト再調整版）
// ==========================================
class RaceResultBoard extends StatelessWidget {
  final String location;
  final String raceNumber;
  final List<String> horseNumbers;
  final List<String> margins;
  final String turfCondition;
  final String dirtCondition;
  final String time;
  final String time4F;
  final String time3F;

  const RaceResultBoard({
    super.key,
    this.location = "東京",
    this.raceNumber = "11",
    this.horseNumbers = const ["18", "1", "10", "4", "11"],
    this.margins = const ["クビ", "クビ", "1 1/4", "クビ"],
    this.turfCondition = "良",
    this.dirtCondition = "良",
    this.time = "1.32.3",
    this.time4F = "46.7",
    this.time3F = "34.9",
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 155,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.grey, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 6),
          _buildRanks(),
          const SizedBox(height: 8),
          _buildBottomStats(),
        ],
      ),
    );
  }

  // --- ヘッダー部分 ---
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          children: location.split('').map((char) => Text(
            char,
            style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.1),
          )).toList(),
        ),
        const SizedBox(width: 4),
        Text(raceNumber, style: const TextStyle(color: Colors.orange, fontSize: 30, fontWeight: FontWeight.bold, height: 1.0)),
        const Padding(
          padding: EdgeInsets.only(bottom: 2, left: 4),
          child: Text("R", style: TextStyle(color: Colors.white, fontSize: 14)),
        ),
        const SizedBox(width: 8), // ▼ Spacer() を削除し、固定の隙間(8px)に変更して左に寄せる
        Container(
          width: 58,
          height: 30,
          padding: const EdgeInsets.only(bottom: 2.5), // ▼ 下にだけ3pxの余白を追加（数値はお好みで調整してください）
          color: Colors.red,
          child: const FittedBox(
            fit: BoxFit.contain,
            child: Text(
              "確定",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
            ),
          ),
        )
      ],
    );
  }

  // --- 着順と着差部分 ---
  Widget _buildRanks() {
    const romanNumerals = ["Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ"];
    const double rowHeight = 26.0;

    return SizedBox(
      height: rowHeight * 5,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(5, (i) {
                return SizedBox(
                  height: rowHeight,
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(romanNumerals[i], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12, height: 1.1)),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 34,
                        height: 24,
                        color: const Color(0xFF222222),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 4),
                        child: Text(
                          horseNumbers.length > i ? horseNumbers[i] : "-",
                          style: const TextStyle(color: Colors.orange, fontSize: 22, fontFamily: 'monospace', fontWeight: FontWeight.bold, height: 1.1),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          // 着差（右側の列）の配置部分
          Positioned(
            left: 64,
            top: rowHeight / 2,
            bottom: rowHeight / 2,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start, // ＞を左揃えにする
              children: List.generate(4, (i) {
                return SizedBox(
                  height: rowHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text("＞", style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.1)),
                      const SizedBox(width: 2),

                      // ▼ ここを修正：幅を固定し、FittedBoxで文字サイズを自動調整
                      Container(
                        width: 46, // 背景の幅を固定（文字数に関わらず全て同じ幅になります）
                        height: 18,
                        color: const Color(0xFF222222),
                        alignment: Alignment.center,
                        // FittedBoxを追加し、枠からはみ出る場合は自動で縮小（scaleDown）させる
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2.0), // 文字が枠ギリギリにつかないよう僅かな余白
                            child: Text(
                              margins.length > i ? margins[i] : "",
                              style: const TextStyle(color: Colors.orange, fontSize: 15, fontWeight: FontWeight.bold, height: 1.1),
                            ),
                          ),
                        ),
                      ),

                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // --- 下部の馬場状態とタイム部分 ---
  Widget _buildBottomStats() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.start, // ▼ spaceBetween から start に変更して左寄せにする
      children: [
        // 左側：馬場状態
        Column(
          children: [
            const Text("芝", style: TextStyle(color: Colors.white, fontSize: 12, height: 1.0)),
            Container(
              color: const Color(0xFF222222),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: Text(turfCondition, style: const TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold, height: 1.1)),
            ),
            const SizedBox(height: 4),
            const Text("ダート", style: TextStyle(color: Colors.white, fontSize: 10, height: 1.0)),
            Container(
              color: const Color(0xFF222222),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              child: Text(dirtCondition, style: const TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold, height: 1.1)),
            ),
          ],
        ),
        const SizedBox(width: 8),
        // 右側：タイム
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // レコード表示用のグレー空きスペース
            Row(
              children: [
                const SizedBox(width: 36), // ラベル幅32 + 余白4
                Container(
                  width: 50,
                  height: 18,
                  color: const Color(0xFF222222),
                ),
              ],
            ),
            const SizedBox(height: 2),
            _buildTimeRow("タイム", time, 16),
            const SizedBox(height: 2),
            _buildTimeRow("4F", time4F, 16),
            const SizedBox(height: 2),
            _buildTimeRow("3F", time3F, 16),
          ],
        )
      ],
    );
  }

  Widget _buildTimeRow(String label, String value, double fontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        SizedBox(
          width: 32, // ラベルの幅を固定
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.right),
        ),
        const SizedBox(width: 4),
        _buildAlignedTimeGrid(value, fontSize),
      ],
    );
  }

  // タイムの桁とインデントを完璧に合わせるための固定幅グリッド
  Widget _buildAlignedTimeGrid(String val, double fontSize) {
    String min = "";
    String sec = "--";
    String ms = "";

    if (val != "--" && val.isNotEmpty) {
      String normalized = val.replaceAll(':', '.');
      List<String> parts = normalized.split('.');
      if (parts.length >= 3) {
        min = parts[parts.length - 3];
        sec = parts[parts.length - 2];
        ms = parts[parts.length - 1];
      } else if (parts.length == 2) {
        sec = parts[0];
        ms = parts[1];
      } else if (parts.length == 1) {
        sec = parts[0];
      }
    }

    double minWidth = 14;
    double secWidth = 24;
    double msWidth = 14;
    double dotWidth = 2;

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        if (min.isNotEmpty)
          _buildTimeBox(min, minWidth, fontSize)
        else
          SizedBox(width: minWidth),

        if (min.isNotEmpty)
          _buildDot(dotWidth, fontSize)
        else
          SizedBox(width: dotWidth),

        _buildTimeBox(sec, secWidth, fontSize),

        if (ms.isNotEmpty)
          _buildDot(dotWidth, fontSize)
        else
          SizedBox(width: dotWidth),

        if (ms.isNotEmpty)
          _buildTimeBox(ms, msWidth, fontSize)
        else
          SizedBox(width: msWidth),
      ],
    );
  }

  Widget _buildDot(double width, double fontSize) {
    return SizedBox(
      width: width,
      height: 18, // ▼ 高さをボックスと合わせる
      child: Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Text(".", style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.bold, height: 1.0)),
        ),
      ),
    );
  }

  Widget _buildTimeBox(String val, double width, double fontSize) {
    return Container(
      width: width,
      height: 18, // ▼ 高さを20から18に縮めて上下余白を減らす
      color: const Color(0xFF222222),
      alignment: Alignment.center,
      child: Text(
        val,
        style: TextStyle(
            color: Colors.orange,
            fontSize: fontSize,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            height: 1.1
        ),
      ),
    );
  }
}
// ==========================================
// ▼ 新規追加: 点滅する1着馬のマーカーウィジェット
// ==========================================
class BlinkingRedHorseMarker extends StatefulWidget {
  final String horseNum;
  final String frameNum;
  final double size;
  final double fontSize;

  const BlinkingRedHorseMarker({
    super.key,
    required this.horseNum,
    required this.frameNum,
    this.size = 24,
    this.fontSize = 12,
  });

  @override
  State<BlinkingRedHorseMarker> createState() => _BlinkingRedHorseMarkerState();
}

class _BlinkingRedHorseMarkerState extends State<BlinkingRedHorseMarker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // 1秒かけてゆっくり点滅（往復）させる
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // 最小0.3 〜 最大1.0 の間でなめらかに変化する値を生成
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color bgColor = widget.frameNum.gateBackgroundColor;
    Color textColor = widget.frameNum.gateTextColor;
    bool hasBorder = widget.frameNum == "1" || widget.frameNum == "8" || widget.frameNum.isEmpty;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: bgColor,
            shape: BoxShape.circle,
            border: hasBorder ? Border.all(color: Colors.black26, width: 1) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(_animation.value), // 透明度が変化
                blurRadius: 3.0 + (_animation.value * 4.0),     // ぼかし具合が変化
                spreadRadius: 1.0 + (_animation.value * 2.0),   // 広がりが変化
                offset: const Offset(0, 0),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: child,
        );
      },
      child: Text(
        widget.horseNum,
        style: TextStyle(
          color: textColor,
          fontSize: widget.fontSize,
          fontWeight: FontWeight.bold,
          height: 1.0,
        ),
      ),
    );
  }
}