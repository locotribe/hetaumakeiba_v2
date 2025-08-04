// lib/widgets/dashboard_settings_sheet.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// 設定可能なカードのキーと表示名のマップ
const Map<String, String> availableCards = {
  'yearly_summary': '年間収支',
  'grade_summary': 'グレード別収支',
  'venue_summary': '競馬場別収支',
  'distance_summary': '距離別収支',
  'track_summary': '馬場状態別収支',
  'ticket_type_summary': '式別収支',
  'purchase_method_summary': '方式別収支',
};

class DashboardSettingsSheet extends StatefulWidget {
  final List<String> visibleCards;
  final ValueChanged<List<String>> onSettingsChanged;

  const DashboardSettingsSheet({
    super.key,
    required this.visibleCards,
    required this.onSettingsChanged,
  });

  @override
  State<DashboardSettingsSheet> createState() => _DashboardSettingsSheetState();
}

class _DashboardSettingsSheetState extends State<DashboardSettingsSheet> {
  late List<String> _cardOrder;
  late Set<String> _visibleKeys;

  @override
  void initState() {
    super.initState();
    _visibleKeys = widget.visibleCards.toSet();

    // 表示されているカード順を優先しつつ、全カードの順序リストを作成
    _cardOrder = List.from(widget.visibleCards);
    for (final key in availableCards.keys) {
      if (!_cardOrder.contains(key)) {
        _cardOrder.add(key);
      }
    }
  }

  Future<void> _saveSettings() async {
    // 現在の順序リストから、表示がオンになっているものだけを抽出
    final newVisibleCards = _cardOrder.where((key) => _visibleKeys.contains(key)).toList();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dashboard_visible_cards', newVisibleCards);
    widget.onSettingsChanged(newVisibleCards);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ダッシュボード表示設定',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ReorderableListView(
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = _cardOrder.removeAt(oldIndex);
                  _cardOrder.insert(newIndex, item);
                  _saveSettings();
                });
              },
              // 表示するリストの元を、状態として管理している `_cardOrder` に変更
              children: _cardOrder.map((key) {
                final title = availableCards[key] ?? '不明';
                final isVisible = _visibleKeys.contains(key);

                return SwitchListTile(
                  key: ValueKey(key),
                  title: Text(title),
                  value: isVisible,
                  onChanged: (bool value) {
                    setState(() {
                      if (value) {
                        _visibleKeys.add(key);
                      } else {
                        _visibleKeys.remove(key);
                      }
                      _saveSettings();
                    });
                  },
                  secondary: const Icon(Icons.drag_handle),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}