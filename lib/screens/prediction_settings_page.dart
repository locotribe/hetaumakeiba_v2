// lib/screens/prediction_settings_page.dart
import 'package:flutter/material.dart';
import 'package:hetaumakeiba_v2/widgets/custom_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PredictionSettingsPage extends StatefulWidget {
  const PredictionSettingsPage({super.key});

  @override
  State<PredictionSettingsPage> createState() => _PredictionSettingsPageState();
}

class _PredictionSettingsPageState extends State<PredictionSettingsPage> {
  // 各ファクターの重みを保持するState変数（ダミーの初期値）
  double _legTypeWeight = 30.0;
  double _courseFitWeight = 25.0;
  double _trackConditionWeight = 20.0;
  double _humanFactorWeight = 15.0;
  double _conditionWeight = 10.0;

  String _selectedPreset = 'カスタム';

  // デフォルトの重み設定
  final Map<String, double> _defaultWeights = {
    'legType': 30.0, 'courseFit': 25.0, 'trackCondition': 20.0, 'humanFactor': 15.0, 'condition': 10.0,
  };

  @override
  void initState() {
    super.initState();
    _loadWeights();
  }

  Future<void> _loadWeights() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _legTypeWeight = prefs.getDouble('legTypeWeight') ?? _defaultWeights['legType']!;
      _courseFitWeight = prefs.getDouble('courseFitWeight') ?? _defaultWeights['courseFit']!;
      _trackConditionWeight = prefs.getDouble('trackConditionWeight') ?? _defaultWeights['trackCondition']!;
      _humanFactorWeight = prefs.getDouble('humanFactorWeight') ?? _defaultWeights['humanFactor']!;
      _conditionWeight = prefs.getDouble('conditionWeight') ?? _defaultWeights['condition']!;
      _selectedPreset = prefs.getString('selectedPreset') ?? 'カスタム';
    });
  }

  Future<void> _saveWeights() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('legTypeWeight', _legTypeWeight);
    await prefs.setDouble('courseFitWeight', _courseFitWeight);
    await prefs.setDouble('trackConditionWeight', _trackConditionWeight);
    await prefs.setDouble('humanFactorWeight', _humanFactorWeight);
    await prefs.setDouble('conditionWeight', _conditionWeight);
    await prefs.setString('selectedPreset', _selectedPreset);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました。')),
      );
    }
  }

  void _applyPreset(String presetName) {
    Map<String, double> presetWeights;
    switch (presetName) {
      case '的中重視':
        presetWeights = {'legType': 20, 'courseFit': 30, 'trackCondition': 15, 'humanFactor': 25, 'condition': 10};
        break;
      case '大穴狙い':
        presetWeights = {'legType': 40, 'courseFit': 10, 'trackCondition': 30, 'humanFactor': 10, 'condition': 10};
        break;
      case 'バランス重視':
      default:
        presetWeights = _defaultWeights;
        break;
    }
    setState(() {
      _legTypeWeight = presetWeights['legType']!;
      _courseFitWeight = presetWeights['courseFit']!;
      _trackConditionWeight = presetWeights['trackCondition']!;
      _humanFactorWeight = presetWeights['humanFactor']!;
      _conditionWeight = presetWeights['condition']!;
      _selectedPreset = presetName;
    });
  }

  void _resetToDefault() {
    setState(() {
      _legTypeWeight = _defaultWeights['legType']!;
      _courseFitWeight = _defaultWeights['courseFit']!;
      _trackConditionWeight = _defaultWeights['trackCondition']!;
      _humanFactorWeight = _defaultWeights['humanFactor']!;
      _conditionWeight = _defaultWeights['condition']!;
      _selectedPreset = 'バランス重視';
    });
  }

  void _onSliderChanged() {
    setState(() {
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
                  ElevatedButton(onPressed: _saveWeights, child: const Text('この設定を保存する')),
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
            ChoiceChip(label: const Text('バランス重視'), selected: _selectedPreset == 'バランス重視', onSelected: (val) => _applyPreset('バランス重視')),
            ChoiceChip(label: const Text('的中重視'), selected: _selectedPreset == '的中重視', onSelected: (val) => _applyPreset('的中重視')),
            ChoiceChip(label: const Text('大穴狙い'), selected: _selectedPreset == '大穴狙い', onSelected: (val) => _applyPreset('大穴狙い')),
          ],
        )
      ],
    );
  }

  Widget _buildCustomSliderSection() {
    final totalWeight = _legTypeWeight + _courseFitWeight + _trackConditionWeight + _humanFactorWeight + _conditionWeight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('カスタム設定', style: Theme.of(context).textTheme.titleLarge),
            Text('合計: ${totalWeight.toStringAsFixed(0)}%', style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
        const SizedBox(height: 8),
        _buildSliderTile('脚質・展開適性', _legTypeWeight, (val) => setState(() { _legTypeWeight = val; _onSliderChanged(); })),
        _buildSliderTile('コース適性', _courseFitWeight, (val) => setState(() { _courseFitWeight = val; _onSliderChanged(); })),
        _buildSliderTile('馬場適性', _trackConditionWeight, (val) => setState(() { _trackConditionWeight = val; _onSliderChanged(); })),
        _buildSliderTile('人的要因', _humanFactorWeight, (val) => setState(() { _humanFactorWeight = val; _onSliderChanged(); })),
        _buildSliderTile('コンディション', _conditionWeight, (val) => setState(() { _conditionWeight = val; _onSliderChanged(); })),
      ],
    );
  }

  Widget _buildSliderTile(String title, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 120, child: Text(title)),
        Expanded(
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            divisions: 20,
            label: value.toStringAsFixed(0),
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 40, child: Text('${value.toStringAsFixed(0)}%')),
      ],
    );
  }
}