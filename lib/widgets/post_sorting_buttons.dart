import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:aaram_bd/localization/language_provider.dart';

class PostSortingButtons extends StatelessWidget {
  final String selectedSort;
  final Function(String) onSortSelected;

  const PostSortingButtons({
    Key? key,
    required this.selectedSort,
    required this.onSortSelected,
  }) : super(key: key);

  static const Color _brandBlue = Color(0xFF1A56DB);

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().l10n;

    final List<Map<String, dynamic>> sortOptions = [
      {
        'label': l10n.sortRecent,
        'value': 'recent',
        'icon': Icons.access_time_rounded,
      },
      {
        'label': l10n.sortViewed,
        'value': 'most_viewed',
        'icon': Icons.remove_red_eye_outlined,
      },
      {
        'label': l10n.sortCommented,
        'value': 'most_commented',
        'icon': Icons.chat_bubble_outline_rounded,
      },
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 6, 14, 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: sortOptions.map((opt) {
          final isSelected = selectedSort == opt['value'];
          return Expanded(
            child: GestureDetector(
              onTap: () => onSortSelected(opt['value'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: isSelected ? _brandBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: _brandBlue.withValues(alpha: 0.28),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      opt['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : Colors.black38,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      opt['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? Colors.white : Colors.black45,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
