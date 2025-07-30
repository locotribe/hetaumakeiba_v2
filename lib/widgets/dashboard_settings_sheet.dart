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
  late List<String> _currentVisibleCards;

  @override
  void initState() {
    super.initState();
    _currentVisibleCards = List.from(widget.visibleCards);
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('dashboard_visible_cards', _currentVisibleCards);
    widget.onSettingsChanged(_currentVisibleCards);
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
                  final item = _currentVisibleCards.removeAt(oldIndex);
                  _currentVisibleCards.insert(newIndex, item);
                  _saveSettings();
                });
              },
              children: availableCards.entries.map((entry) {
                final key = entry.key;
                final title = entry.value;
                final isVisible = _currentVisibleCards.contains(key);

                return SwitchListTile(
                  key: ValueKey(key),
                  title: Text(title),
                  value: isVisible,
                  onChanged: (bool value) {
                    setState(() {
                      if (value) {
                        if (!_currentVisibleCards.contains(key)) {
                          _currentVisibleCards.add(key);
                        }
                      } else {
                        _currentVisibleCards.remove(key);
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
