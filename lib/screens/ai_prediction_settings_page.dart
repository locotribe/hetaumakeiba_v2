// lib/screens/ai_prediction_settings_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiPredictionSettingsPage extends StatefulWidget {
  final String? raceId; // raceIdを受け取れるようにする

  const AiPredictionSettingsPage({super.key, this.raceId});

  @override
  State<AiPredictionSettingsPage> createState() => _AiPredictionSettingsPageState();
}

class _AiPredictionSettingsPageState extends State<AiPredictionSettingsPage> {
  // 各ファクターの重みをint(ポイント)で保持するように変更
  int _legTypeWeight = 20;
  int _courseFitWeight = 20;
  int _trackConditionWeight = 15;
  int _humanFactorWeight = 15;
  int _conditionWeight = 10;
  int _earlySpeedWeight = 5;
  int _finishingKickWeight = 10;
  int _staminaWeight = 5;

  // ポイントの合計と残りを計算するプロパティ
  int get _totalWeight =>
      _legTypeWeight +
          _courseFitWeight +
          _trackConditionWeight +
          _humanFactorWeight +
          _conditionWeight +
          _earlySpeedWeight +
          _finishingKickWeight +
          _staminaWeight;

  // プリセットの定義 (合計100ポイントになるように調整)
  final Map<String, Map<String, int>> _presets = {
    'バランス重視': {
      'legType': 20, 'courseFit': 20, 'trackCondition': 15, 'humanFactor': 15, 'condition': 10, 'earlySpeed': 5, 'finishingKick': 10, 'stamina': 5,
    },
    '的中重視': {
      'legType': 15, 'courseFit': 25, 'trackCondition': 15, 'humanFactor': 20, 'condition': 10, 'earlySpeed': 5, 'finishingKick': 5, 'stamina': 5,
    },
    '大穴狙い': {
      'legType': 25, 'courseFit': 10, 'trackCondition': 20, 'humanFactor': 10, 'condition': 10, 'earlySpeed': 10, 'finishingKick': 15, 'stamina': 0,
    },
  };

  String _selectedPreset = 'カスタム';
  List<String> _customPresetNames = []; // カスタムプリセット名リスト
  static const int _maxCustomPresets = 5; // 保存できるプリセットの上限

  @override
  void initState() {
    super.initState();
    _loadWeights();
  }

  // SharedPreferencesのキーを生成するヘルパーメソッド
  String _key(String base) {
    if (widget.raceId != null && widget.raceId!.isNotEmpty) {
      return '${base}_${widget.raceId}';
    }
    // グローバル設定用のキー
    return base;
  }

  Future<void> _loadWeights() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _customPresetNames = prefs.getStringList('custom_preset_names') ?? [];

      _legTypeWeight = prefs.getInt(_key('legTypeWeight')) ?? _presets['バランス重視']!['legType']!;
      _courseFitWeight = prefs.getInt(_key('courseFitWeight')) ?? _presets['バランス重視']!['courseFit']!;
      _trackConditionWeight = prefs.getInt(_key('trackConditionWeight')) ?? _presets['バランス重視']!['trackCondition']!;
      _humanFactorWeight = prefs.getInt(_key('humanFactorWeight')) ?? _presets['バランス重視']!['humanFactor']!;
      _conditionWeight = prefs.getInt(_key('conditionWeight')) ?? _presets['バランス重視']!['condition']!;
      _earlySpeedWeight = prefs.getInt(_key('earlySpeedWeight')) ?? _presets['バランス重視']!['earlySpeed']!;
      _finishingKickWeight = prefs.getInt(_key('finishingKickWeight')) ?? _presets['バランス重視']!['finishingKick']!;
      _staminaWeight = prefs.getInt(_key('staminaWeight')) ?? _presets['バランス重視']!['stamina']!;
      _selectedPreset = prefs.getString(_key('selectedPreset')) ?? 'カスタム';
    });
  }

  Future<void> _saveWeights() async {
    if (_totalWeight != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('合計ポイントが100になるように調整してください。')),
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key('legTypeWeight'), _legTypeWeight);
    await prefs.setInt(_key('courseFitWeight'), _courseFitWeight);
    await prefs.setInt(_key('trackConditionWeight'), _trackConditionWeight);
    await prefs.setInt(_key('humanFactorWeight'), _humanFactorWeight);
    await prefs.setInt(_key('conditionWeight'), _conditionWeight);
    await prefs.setInt(_key('earlySpeedWeight'), _earlySpeedWeight);
    await prefs.setInt(_key('finishingKickWeight'), _finishingKickWeight);
    await prefs.setInt(_key('staminaWeight'), _staminaWeight);
    await prefs.setString(_key('selectedPreset'), _selectedPreset);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を反映しました。')),
      );
      Navigator.of(context).pop(true);
    }
  }

  void _applyPreset(String presetName) {
    final presetWeights = _presets[presetName];
    if (presetWeights == null) return;

    setState(() {
      _legTypeWeight = presetWeights['legType']!;
      _courseFitWeight = presetWeights['courseFit']!;
      _trackConditionWeight = presetWeights['trackCondition']!;
      _humanFactorWeight = presetWeights['humanFactor']!;
      _conditionWeight = presetWeights['condition']!;
      _earlySpeedWeight = presetWeights['earlySpeed']!;
      _finishingKickWeight = presetWeights['finishingKick']!;
      _staminaWeight = presetWeights['stamina']!;
      _selectedPreset = presetName;
    });
  }

  Future<void> _applyCustomPreset(String presetName) async {
    final prefs = await SharedPreferences.getInstance();
    final presetJson = prefs.getString('preset_data_$presetName');
    if (presetJson != null) {
      final presetData = json.decode(presetJson) as Map<String, dynamic>;
      setState(() {
        _legTypeWeight = presetData['legType']!;
        _courseFitWeight = presetData['courseFit']!;
        _trackConditionWeight = presetData['trackCondition']!;
        _humanFactorWeight = presetData['humanFactor']!;
        _conditionWeight = presetData['condition']!;
        _earlySpeedWeight = presetData['earlySpeed']!;
        _finishingKickWeight = presetData['finishingKick']!;
        _staminaWeight = presetData['stamina']!;
        _selectedPreset = presetName;
      });
    }
  }

  void _resetToDefault() {
    _applyPreset('バランス重視');
  }

  void _updateWeight(Function(int) update, int currentValue, int change) {
    final newValue = currentValue + change;
    if (newValue < 0) return;

    if (_totalWeight - currentValue + newValue > 100) return;

    setState(() {
      update(newValue);
      _selectedPreset = 'カスタム';
    });
  }

  Future<void> _showSavePresetDialog() async {
    if (_totalWeight != 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('合計ポイントが100でないと保存できません。')),
      );
      return;
    }

    if (_customPresetNames.length >= _maxCustomPresets) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('カスタムプリセットは$_maxCustomPresets個まで保存できます。')),
      );
      return;
    }

    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('カスタムプリセットを保存'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'プリセット名を入力'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('キャンセル')),
          TextButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty && !_presets.containsKey(name) && !_customPresetNames.contains(name)) {
                Navigator.of(context).pop(name);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('その名前は使用できません。')),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _saveCustomPreset(result);
    }
  }

  Future<void> _saveCustomPreset(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final presetData = {
      'legType': _legTypeWeight,
      'courseFit': _courseFitWeight,
      'trackCondition': _trackConditionWeight,
      'humanFactor': _humanFactorWeight,
      'condition': _conditionWeight,
      'earlySpeed': _earlySpeedWeight,
      'finishingKick': _finishingKickWeight,
      'stamina': _staminaWeight,
    };
    await prefs.setString('preset_data_$name', json.encode(presetData));

    final updatedNames = List<String>.from(_customPresetNames)..add(name);
    await prefs.setStringList('custom_preset_names', updatedNames);

    setState(() {
      _customPresetNames = updatedNames;
      _selectedPreset = name;
    });
  }

  Future<void> _deleteCustomPreset(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('preset_data_$name');
    final updatedNames = List<String>.from(_customPresetNames)..remove(name);
    await prefs.setStringList('custom_preset_names', updatedNames);
    setState(() {
      _customPresetNames = updatedNames;
      if (_selectedPreset == name) {
        _selectedPreset = 'カスタム';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appBarTitle = widget.raceId == null ? 'AIチューニング (全体設定)' : 'AIチューニング';
    return Scaffold(
      appBar: AppBar(
        title: Text(appBarTitle),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: CustomBackground(
              overallBackgroundColor: Color.fromRGBO(231, 234, 234, 1.0),
              stripeColor: Color.fromRGBO(219, 234, 234, 0.6),
              fillColor: Color.fromRGBO(172, 234, 231, 1.0),
            ),
          ),
          ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildPresetSection(),
              const SizedBox(height: 16),
              _buildCustomPresetList(),
              const SizedBox(height: 24),
              _buildCustomSliderSection(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(onPressed: _resetToDefault, child: const Text('デフォルトに戻す')),
                  ElevatedButton(
                    onPressed: _totalWeight == 100 ? _saveWeights : null,
                    child: const Text('この設定を反映'),
                  ),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomPresetList() {
    if (_customPresetNames.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('カスタムプリセット', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _customPresetNames.length,
          itemBuilder: (context, index) {
            final name = _customPresetNames[index];
            return Slidable(
              key: Key(name),
              endActionPane: ActionPane(
                motion: const ScrollMotion(),
                extentRatio: 0.20,
                children: [
                  SlidableAction(
                    onPressed: (context) => _deleteCustomPreset(name),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    icon: Icons.delete,
                    label: '削除',
                  ),
                ],
              ),
              child: Card(
                child: ListTile(
                  title: Text(name),
                  selected: _selectedPreset == name,
                  onTap: () => _applyCustomPreset(name),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPresetSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('プリセット', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          children: [
            // バランス重視 -> デフォルトに戻す, のロジックは _resetToDefault に集約
            ChoiceChip(label: const Text('バランス重視'), selected: _selectedPreset == 'バランス重視', onSelected: (val) => _applyPreset('バランス重視')),
            ChoiceChip(label: const Text('的中重視'), selected: _selectedPreset == '的中重視', onSelected: (val) => _applyPreset('的中重視')),
            ChoiceChip(label: const Text('大穴狙い'), selected: _selectedPreset == '大穴狙い', onSelected: (val) => _applyPreset('大穴狙い')),
          ],
        )
      ],
    );
  }

  Widget _buildCustomSliderSection() {
    final totalColor = _totalWeight == 100 ? Colors.green : Colors.red;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('カスタム設定', style: Theme.of(context).textTheme.titleLarge),
            Text('合計: $_totalWeight / 100', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: totalColor)),
          ],
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.save),
          label: const Text('現在の設定をプリセットに保存'),
          onPressed: _showSavePresetDialog,
        ),
        const SizedBox(height: 8),
        _buildPointAllocationTile('脚質・展開適性', _legTypeWeight, (val) => setState(() => _legTypeWeight = val)),
        _buildPointAllocationTile('コース適性', _courseFitWeight, (val) => setState(() => _courseFitWeight = val)),
        _buildPointAllocationTile('馬場適性', _trackConditionWeight, (val) => setState(() => _trackConditionWeight = val)),
        _buildPointAllocationTile('人的要因', _humanFactorWeight, (val) => setState(() => _humanFactorWeight = val)),
        _buildPointAllocationTile('コンディション', _conditionWeight, (val) => setState(() => _conditionWeight = val)),
        _buildPointAllocationTile('先行力', _earlySpeedWeight, (val) => setState(() => _earlySpeedWeight = val)),
        _buildPointAllocationTile('瞬発力', _finishingKickWeight, (val) => setState(() => _finishingKickWeight = val)),
        _buildPointAllocationTile('スタミナ', _staminaWeight, (val) => setState(() => _staminaWeight = val)),
      ],
    );
  }

  // ポイントを割り振るための新しいUIタイル
  Widget _buildPointAllocationTile(String title, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(title)),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline),
            onPressed: () => _updateWeight((v) => onChanged(v), value, -10),
          ),
          Expanded(
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 100,
              divisions: 10,
              label: value.toString(),
              onChanged: (double newValue) {
                _updateWeight((v) => onChanged(v), value, newValue.toInt() - value);
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => _updateWeight((v) => onChanged(v), value, 10),
          ),
          SizedBox(width: 40, child: Text('$value', textAlign: TextAlign.right)),
        ],
      ),
    );
  }
}