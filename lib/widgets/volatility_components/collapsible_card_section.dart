// lib/widgets/volatility_components/collapsible_card_section.dart

// [追加] ローテ・血統タブの見た目の調整 Step4: 見出しだけのカードをタップすると、下に中身のカードを開閉する部品。最初は閉じる。開閉は保存しない（タブを開き直すと閉じる） (v.2026.10.19+26101909)

import 'package:flutter/material.dart';

class CollapsibleCardSection extends StatefulWidget {
  /// 見出し（閉じているときも出る）
  final String title;

  /// 開いたときに見出しの下に出す中身（それ自体がカードでよい）
  final Widget child;

  const CollapsibleCardSection({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  State<CollapsibleCardSection> createState() => _CollapsibleCardSectionState();
}

class _CollapsibleCardSectionState extends State<CollapsibleCardSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          widget.child,
        ],
      ],
    );
  }
}
