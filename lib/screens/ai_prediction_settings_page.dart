// lib/screens/ai_prediction_settings_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiPredictionSettingsPage extends StatefulWidget {
  const AiPredictionSettingsPage({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadWeights();
  }

  Future<void> _loadWeights() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // getIntを使い、デフォルト値もintにする
      _legTypeWeight = prefs.getInt('legTypeWeight') ?? _presets['バランス重視']!['legType']!;
      _courseFitWeight = prefs.getInt('courseFitWeight') ?? _presets['バランス重視']!['courseFit']!;
      _trackConditionWeight = prefs.getInt('trackConditionWeight') ?? _presets['バランス重視']!['trackCondition']!;
      _humanFactorWeight = prefs.getInt('humanFactorWeight') ?? _presets['バランス重視']!['humanFactor']!;
      _conditionWeight = prefs.getInt('conditionWeight') ?? _presets['バランス重視']!['condition']!;
      _earlySpeedWeight = prefs.getInt('earlySpeedWeight') ?? _presets['バランス重視']!['earlySpeed']!;
      _finishingKickWeight = prefs.getInt('finishingKickWeight') ?? _presets['バランス重視']!['finishingKick']!;
      _staminaWeight = prefs.getInt('staminaWeight') ?? _presets['バランス重視']!['stamina']!;
      _selectedPreset = prefs.getString('selectedPreset') ?? 'カスタム';
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
    // setIntで保存
    await prefs.setInt('legTypeWeight', _legTypeWeight);
    await prefs.setInt('courseFitWeight', _courseFitWeight);
    await prefs.setInt('trackConditionWeight', _trackConditionWeight);
    await prefs.setInt('humanFactorWeight', _humanFactorWeight);
    await prefs.setInt('conditionWeight', _conditionWeight);
    await prefs.setInt('earlySpeedWeight', _earlySpeedWeight);
    await prefs.setInt('finishingKickWeight', _finishingKickWeight);
    await prefs.setInt('staminaWeight', _staminaWeight);
    await prefs.setString('selectedPreset', _selectedPreset);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました。')),
      );
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

  void _resetToDefault() {
    _applyPreset('バランス重視');
  }

  // ポイントを更新するロジック
  void _updateWeight(Function(int) update, int currentValue, int change) {
    final newValue = currentValue + change;
    if (newValue < 0) return; // 0未満にはしない

    // 合計が100を超える場合は更新しない
    if (_totalWeight - currentValue + newValue > 100) return;

    setState(() {
      update(newValue);
      _selectedPreset = 'カスタム';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIチューニング'),
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
              const SizedBox(height: 24),
              _buildCustomSliderSection(),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  OutlinedButton(onPressed: _resetToDefault, child: const Text('デフォルトに戻す')),
                  // 合計が100でない場合はボタンを非活性化
                  ElevatedButton(
                    onPressed: _totalWeight == 100 ? _saveWeights : null,
                    child: const Text('この設定を保存する'),
                  ),
                ],
              )
            ],
          ),
        ],
      ),
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
    // 合計ポイントの表示スタイルを更新
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
        // 各項目を新しいUIに変更
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