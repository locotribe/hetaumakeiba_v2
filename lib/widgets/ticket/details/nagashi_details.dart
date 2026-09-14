// lib/widgets/ticket/details/nagashi_details.dart

import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/logic/combination_calculator.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/parts/horse_number_box.dart';
import 'package:hetaumakeiba_v2/widgets/ticket/parts/nagashi_connector_painter.dart';

class NagashiDetails extends StatefulWidget {
  final Map<String, dynamic> detail;
  final String betType;
  const NagashiDetails({super.key, required this.detail, required this.betType});

  @override
  State<NagashiDetails> createState() => _NagashiDetailsState();
}

class _NagashiDetailsState extends State<NagashiDetails> {
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

  @override
  Widget build(BuildContext context) {
    return _buildNagashiDetails(widget.detail, widget.betType);
  }
}
