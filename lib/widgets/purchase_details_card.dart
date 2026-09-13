// lib/widgets/purchase_details_card.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/models/race_result_model.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/util/ticket_format.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/parts/horse_number_box.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/parts/nagashi_connector_painter.dart';

class PurchaseDetailsCard extends StatefulWidget {
  final Map<String, dynamic> parsedResult;
  final String betType;
  final RaceResult? raceResult;

  const PurchaseDetailsCard({
    super.key,
    required this.parsedResult,
    required this.betType,
    this.raceResult,
  });

  @override
  State<PurchaseDetailsCard> createState() => _PurchaseDetailsCardState();
}

class _PurchaseDetailsCardState extends State<PurchaseDetailsCard> {
  final GlobalKey _paintAreaKey = GlobalKey();
  final List<GlobalKey> _axisKeys = [];
  final List<GlobalKey> _opponentRowKeys = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  /// 罫線付きのながしレイアウトを生成する
  Widget _buildNagashiWithConnector({required List<int> axisHorses, required List<int> opponentHorses}) {
    _axisKeys.clear();
    _opponentRowKeys.clear();

    // 軸馬ウィジェットリストを生成
    final List<Widget> axisWidgets = axisHorses.map((horse) {
      final key = GlobalKey();
      _axisKeys.add(key);
      return Padding(
        padding: const EdgeInsets.only(bottom: 4.0),
        child: buildHorseNumberDisplay(horse, key: key, horseCountForSizing: 1).first,
      );
    }).toList();

    // 相手馬を常に4x5のグリッドで生成し、足りない分は '☆' で埋める
    const int numOpponentRows = 4;
    const int numOpponentCols = 5;
    const int totalCells = numOpponentRows * numOpponentCols;
    final int opponentCount = opponentHorses.length;
    // 枠の大きさを指定する場所
    final Size boxSizeForOpponent = getBoxSizeByHorseCount(opponentCount > 6 ? 7 : opponentCount);


    List<dynamic> opponentItems = List.from(opponentHorses);
    while (opponentItems.length < totalCells) {
      opponentItems.add('☆');
    }

    List<Widget> opponentRowWidgets = [];
    for (int i = 0; i < numOpponentRows; i++) {
      final key = GlobalKey();
      _opponentRowKeys.add(key);
      List<Widget> rowChildren = [];
      for (int j = 0; j < numOpponentCols; j++) {
        final item = opponentItems[i * numOpponentCols + j];
        if (item is int) {
          rowChildren.add(buildHorseNumberDisplay(item, horseCountForSizing: opponentCount).first);
        } else {
          rowChildren.add(
            SizedBox(
              width: boxSizeForOpponent.width + 4.0,
              height: boxSizeForOpponent.height + 4.0,
              child: Center(
                // ながし投票の相手馬が20頭に満たない場合のプレースホルダー('☆')のフォントサイズ
                child: Text('☆', style: TextStyle(fontSize: boxSizeForOpponent.width * 0.5, color: Colors.black)),
              ),
            ),
          );
        }
      }
      opponentRowWidgets.add(
        Padding(
          key: key,
          padding: const EdgeInsets.only(bottom: 1.0),
          child: Wrap(spacing: 6.0, children: rowChildren),
        ),
      );
    }

    final Widget axisColumn = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          '(軸)',
          style: TextStyle(
            color: Colors.black,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Column(children: axisWidgets),
      ],
    );
    final Widget opponentColumn = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          '(相手)',
          style: TextStyle(
            color: Colors.black,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: opponentRowWidgets),
      ],
    );

    return Stack(
      key: _paintAreaKey,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            axisColumn,
            const SizedBox(width: 15), // 罫線を描画するスペース
            opponentColumn,
          ],
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: NagashiConnectorPainter(
              canvasKey: _paintAreaKey,
              axisKeys: _axisKeys,
              opponentRowKeys: _opponentRowKeys,
            ),
          ),
        ),
      ],
    );
  }

  /// ボックス投票のグリッド内のセル（馬番または☆）を1つ生成する
  Widget _buildBoxHorseNumberCell(dynamic content, {required double scaleFactor}) {
    const double boxSize = 38.0;
    final double containerHeight = boxSize * scaleFactor;

    if (content is int) {
      // 馬番の場合
      return Expanded(
        child: Center(
          child: Container(
            width: boxSize,
            height: containerHeight,
            alignment: Alignment.center,
            decoration: BoxDecoration(border: Border.all(color: Colors.black)),
            child: Transform.scale(
              scaleY: scaleFactor,
              alignment: Alignment.center,
              child: FittedBox(
                // 高さを基準にスケールする
                fit: BoxFit.fitHeight,
                child:
                // 二桁の場合のみ横幅を圧縮する
                Transform.scale(
                  // content(馬番)が9より大きい(つまり二桁)なら横幅を85%に圧縮
                  scaleX: content > 9 ? 0.85 : 1.0,
                  scaleY: content > 9 ? 1.4 : 1.0,
                  child: Text(
                    content.toString(),
                    style: const TextStyle(
                      fontSize: 43,
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      // ☆を表示する部分
      return Expanded(
        child: Center(
          child: SizedBox(
            width: boxSize,
            height: containerHeight,
            child: Center(
              child: Text('☆', style: TextStyle(fontSize: boxSize * 0.6, color: Colors.black)),
            ),
          ),
        ),
      );
    }
  }

  /// ボックス投票用のグリッドレイアウト全体を生成する
  Widget _buildBoxGridLayout(List<int> horseNumbers) {
    const int itemsPerRow = 5;
    final int horseCount = horseNumbers.length;

    // 馬の数に応じて3段階のスケール比率を決定 ★★★
    double scaleFactor;
    if (horseCount < 6) {
      scaleFactor = 1.5;   // 5頭以下は最も縦長
    } else if (horseCount < 12) {
      scaleFactor = 1.25;  // 6～11頭は少し縦長
    } else {
      scaleFactor = 1.0;   // 12頭以上は正方形
    }

    const double cellWidth = 38.0 + 4.0;
    const double totalWidth = cellWidth * itemsPerRow;

    List<Widget> rows = [];

    // 1. 馬番を表示するための行を生成する
    if (horseCount > 0) {
      final int horseRows = (horseCount / itemsPerRow).ceil();
      for (int i = 0; i < horseRows; i++) {
        List<Widget> rowChildren = [];
        for (int j = 0; j < itemsPerRow; j++) {
          final int index = i * itemsPerRow + j;
          if (index < horseCount) {
            // スケール比率を渡してセルを生成
            rowChildren.add(_buildBoxHorseNumberCell(horseNumbers[index], scaleFactor: scaleFactor));
          } else {
            // 行内の☆も、同じ行の馬番と高さを揃えるためにスケール比率を渡す
            rowChildren.add(_buildBoxHorseNumberCell('☆', scaleFactor: scaleFactor));
          }
        }
        rows.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(children: rowChildren),
            )
        );
      }
    }

    // 新しい☆の表示ルール (5頭以下の場合のみ☆の行を追加)
    if (horseCount > 0 && horseCount <= 5) {
      List<Widget> starRowChildren = [];
      for (int j = 0; j < itemsPerRow; j++) {
        // ☆だけの行は常に正方形(スケール1.0)で表示
        starRowChildren.add(_buildBoxHorseNumberCell('☆', scaleFactor: 1.0));
      }
      rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(children: starRowChildren),
          )
      );
    }

    return SizedBox(
      width: totalWidth,
      child: Column(children: rows),
    );
  }

  /// 応援馬券のレイアウト
  List<Widget> _buildOuenBakenDetails(List<Map<String, dynamic>> purchaseDetails) {
    if (purchaseDetails.isEmpty) return [];

    final detail = purchaseDetails.first;
    final horseNumberData = detail['馬番'];
    final horseNumber = (horseNumberData is List ? horseNumberData[0] : horseNumberData) as int;
    final int? kingaku = detail['購入金額'];

    String horseNameToDisplay = 'キミノアイバ'; // デフォルト値
    if (widget.raceResult != null) {
      try {
        final horseNumberString = horseNumber.toString();
        final horseData = widget.raceResult!.horseResults.firstWhere(
              (h) => h.horseNumber.trim() == horseNumberString,
        );
        horseNameToDisplay = horseData.horseName;
      } catch (e) {
        // レース結果に馬が見つからない場合 (除外など) はデフォルト名のまま
      }
    }

    final Widget horseNumberWidget = buildHorseNumberDisplay(horseNumber, horseCountForSizing: 1).first;

    const TextStyle amountStyle = TextStyle(
      color: Colors.black,
      fontWeight: FontWeight.bold,
      fontSize: 14,
      height: 1.0,);
    const TextStyle kiminoAibaStyle = TextStyle(
        color: Colors.black,
        fontWeight:
        FontWeight.bold,
        fontSize: 13);

    // 1行目: 馬番とテキスト
    final Widget firstLine = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        horseNumberWidget,
        Text(' $horseNameToDisplay', style: kiminoAibaStyle),
      ],
    );

    // 2行目: 金額
    Widget amountLine = const SizedBox.shrink();
    if (kingaku != null) {
      const TextStyle starStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10);
      amountLine = Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Text('各', style: amountStyle),
          Text(getStars(kingaku), style: starStyle),
          Text('$kingaku円', style: amountStyle),
        ],
      );
    }

    return [
      IntrinsicWidth(
        // [修正] Column(stretch)がFittedBoxの無制約(幅Infinity)を直接受け取り
        // BoxConstraints forces an infinite width. で例外になるため、
        // IntrinsicWidthで有限の横幅に変換してからstretchさせる (v.13.41.1)
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            firstLine,
            amountLine,
          ],
        ),
      )
    ];
  }

  /// ながし投票のレイアウト
  Widget _buildNagashiDetails(Map<String, dynamic> detail, String currentBetType) {
    final String shikibetsuId = detail['式別'] ?? '';
    final String shikibetsu = bettingDict[shikibetsuId] ?? '';

    if (shikibetsu != '3連単') {
      final axisData = detail['軸'];
      final opponentData = detail['相手'];
      final List<int> axisHorses = axisData is List ? axisData.cast<int>() : (axisData is int ? [axisData] : []);
      final List<int> opponentHorses = opponentData is List ? opponentData.cast<int>() : (opponentData is int ? [opponentData] : []);
      return _buildNagashiWithConnector(axisHorses: axisHorses, opponentHorses: opponentHorses);
    } else {
      final List<Map<String, dynamic>> groupsData = [];
      if (shikibetsu == '3連単') {
        final horseGroups = (detail['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
        final int axisGroupCount = horseGroups.where((group) => group.length == 1).length;
        final bool isJikuNagashi = axisGroupCount == 1 || axisGroupCount == 2;
        for (final currentGroup in horseGroups) {
          if (currentGroup.isNotEmpty) {
            final bool isAxisGroup = isJikuNagashi && currentGroup.length == 1;
            groupsData.add({'label': isAxisGroup ? '(軸)' : '', 'horseNumbers': currentGroup});
          }
        }
      } else {
        if (detail.containsKey('軸')) groupsData.add({'label': '(軸)', 'horseNumbers': (detail['軸'] as List).cast<int>()});
        if (detail.containsKey('相手')) groupsData.add({'label': '(相手)', 'horseNumbers': (detail['相手'] as List).cast<int>()});
      }
      return buildHorizontalGroupLayout(
        groupsData,
        isFormation: true,
        shikibetsu: shikibetsu,
        betType: currentBetType,
      );
    }
  }

  /// フォーメーション投票のレイアウト
  Widget _buildFormationDetails(Map<String, dynamic> detail, String currentBetType) {
    final String shikibetsuId = detail['式別'] ?? '';
    final String shikibetsu = bettingDict[shikibetsuId] ?? '';

    final horseGroups = (detail['馬番'] as List).map((e) => (e as List).cast<int>()).toList();
    final List<Map<String, dynamic>> groupsData = [];
    if (shikibetsu == '3連単') {
      groupsData.addAll([
        {'horseNumbers': horseGroups.isNotEmpty ? horseGroups[0] : <int>[]},
        {'horseNumbers': horseGroups.length > 1 ? horseGroups[1] : <int>[]},
        {'horseNumbers': horseGroups.length > 2 ? horseGroups[2] : <int>[]},
      ]);
    } else if (shikibetsu == '3連複') {
      for (var group in horseGroups) {
        groupsData.add({'horseNumbers': group});
      }
    } else if (shikibetsu == '馬単') {
      groupsData.addAll([
        {'horseNumbers': horseGroups.isNotEmpty ? horseGroups[0] : <int>[]},
        {'horseNumbers': horseGroups.length > 1 ? horseGroups[1] : <int>[]},
      ]);
    }
    return buildHorizontalGroupLayout(
      groupsData,
      isFormation: true,
      shikibetsu: shikibetsu,
      betType: currentBetType,
    );
  }

  /// 通常・ボックス投票のレイアウト
  Widget _buildDefaultAndBoxDetails(Map<String, dynamic> detail, String currentBetType) {
    final String shikibetsuId = detail['式別'] ?? '';
    final String shikibetsu = bettingDict[shikibetsuId] ?? '';

    String currentSymbol = getHorseNumberSymbol(shikibetsu, currentBetType, uraStatus: detail['ウラ']);
    final dynamic horseNumbers = detail['馬番'];
    final int horseCount = horseNumbers is List ? horseNumbers.length : 1;
    final int? kingaku = detail['購入金額'];

    Widget horseDisplayWidget;

    // 投票種別が「ボックス」の場合、新しく作ったグリッドレイアウト関数を呼び出す
    if (currentBetType == 'ボックス' && horseNumbers is List) {
      horseDisplayWidget = _buildBoxGridLayout(horseNumbers.cast<int>());

    } else if (shikibetsu == '3連単' && currentBetType == '通常' && horseNumbers is List) {
      // (既存の3連単の処理はそのまま)
      final List<Map<String, dynamic>> groupsData = (horseNumbers as List).cast<int>().map((horseNum) {
        return {'horseNumbers': [horseNum]};
      }).toList();

      horseDisplayWidget = buildHorizontalGroupLayout(
        groupsData,
        isFormation: false,
        shikibetsu: shikibetsu,
        betType: currentBetType,
      );
    } else {
      // ボックスと3連単・通常以外の、これまで通りの処理
      final Widget horseNumbersDisplay = Wrap(
        spacing: 4.0,
        runSpacing: 4.0,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [...buildHorseNumberDisplay(horseNumbers, symbol: currentSymbol, horseCountForSizing: horseCount)],
      );

      if ((shikibetsu == '単勝' || shikibetsu == '複勝') && widget.raceResult != null) {
        String? horseNameToDisplay;
        try {
          final horseNumberInt = horseNumbers as int;
          final horseNumberString = horseNumberInt.toString();
          final horseData = widget.raceResult!.horseResults.firstWhere(
                (h) => h.horseNumber.trim() == horseNumberString,
          );
          horseNameToDisplay = horseData.horseName;
        } catch (e) {
          // Not found
        }

        if (horseNameToDisplay != null) {
          horseDisplayWidget = Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              horseNumbersDisplay,
              const SizedBox(width: 8.0),
              Text(
                horseNameToDisplay,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          );
        } else {
          horseDisplayWidget = horseNumbersDisplay;
        }
      } else {
        horseDisplayWidget = horseNumbersDisplay;
      }
    }

    // 金額表示ウィジェット (3連単・通常の場合もここで生成される)
    Widget amountDisplay = const SizedBox.shrink();
    if (kingaku != null && currentBetType == '通常') {
      const TextStyle starStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 10);
      const TextStyle amountStyle = TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, height: 1.0,);
      amountDisplay = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 16.0),
          Text(getStars(kingaku), style: starStyle),
          Text('$kingaku円', style: amountStyle),
        ],
      );
    }

    // 最終的に馬番表示と金額表示を結合する
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        horseDisplayWidget,
        amountDisplay,
      ],
    );
  }


  /// 【リファクタリング】メインの分岐処理
  /// 投票種別に応じて、上記で作成した各レイアウト構築メソッドを呼び出すように変更
  List<Widget> _buildPurchaseDetailsInternal(dynamic purchaseData, String currentBetType) {
    List<Map<String, dynamic>> purchaseDetails = (purchaseData as List).cast<Map<String, dynamic>>();

    // 応援馬券は他の券種と構造が異なるため、ここで特別に処理する
    if (currentBetType == '応援馬券') {
      return _buildOuenBakenDetails(purchaseDetails);
    }

    return purchaseDetails.map((detail) {
      Widget content;

      // 投票種別に応じて適切なレイアウト構築メソッドを呼び出す
      switch (currentBetType) {
        case 'ながし':
          content = _buildNagashiDetails(detail, currentBetType);
          break;
        case 'フォーメーション':
          content = _buildFormationDetails(detail, currentBetType);
          break;
        case '通常':
        case 'ボックス':
        default: // フォールバックとして通常・ボックスの処理を使用
          content = _buildDefaultAndBoxDetails(detail, currentBetType);
          break;
      }

      // 以下の部分は、どの投票種別にも共通するラッパー（囲い）の役割を果たす
      return Padding(
        padding: const EdgeInsets.only(bottom: 2.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            content,
            if (detail['ウラ'] == 'あり')
              const Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: Text('ウラ: あり', style: TextStyle(color: Colors.black)),
              ),
          ],
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.parsedResult.containsKey('購入内容')) {
      return const SizedBox.shrink();
    }

    final bool isCenterAligned =
        widget.betType == '応援馬券' || widget.betType == 'ながし' || widget.betType == 'フォーメーション';

    return LayoutBuilder(
      builder: (context, constraints) {
        return SizedBox(
          width: constraints.maxWidth.isFinite ? constraints.maxWidth : null,
          height: constraints.maxHeight.isFinite ? constraints.maxHeight : null,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: isCenterAligned ? Alignment.center : Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _buildPurchaseDetailsInternal(widget.parsedResult['購入内容'], widget.betType),
              ),
            ),
          ),
        );
      },
    );
  }
}