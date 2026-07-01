import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PostSortingButtons extends StatelessWidget {
  final String selectedSort;
  final Function(String) onSortSelected;

  const PostSortingButtons({
    Key? key,
    required this.selectedSort,
    required this.onSortSelected,
  }) : super(key: key);

  static const Color _blue = Color(0xFF1A56DB);

  @override
  Widget build(BuildContext context) {
    final sortOptions = [
      {
        'label': 'Recent',
        'value': 'recent',
        'icon': Icons.access_time_rounded,
      },
      {
        'label': 'Most Viewed',
        'value': 'most_viewed',
        'icon': Icons.visibility_outlined,
      },
      {
        'label': 'Discussed',
        'value': 'most_commented',
        'icon': Icons.chat_bubble_outline_rounded,
      },
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8EDF5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: List.generate(sortOptions.length, (index) {
          final opt = sortOptions[index];
          final isSelected = selectedSort == opt['value'];
          final isLast = index == sortOptions.length - 1;
          final nextSelected = !isLast &&
              selectedSort == sortOptions[index + 1]['value'];

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onSortSelected(opt['value'] as String);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? _blue : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: _blue.withValues(alpha: 0.28),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                )
                              ]
                            : [],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            opt['icon'] as IconData,
                            size: 14,
                            color: isSelected
                                ? Colors.white
                                : const Color(0xFF94A3B8),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            opt['label'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF6B7280),
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (!isLast && !isSelected && !nextSelected)
                  Container(
                    width: 1,
                    height: 16,
                    color: const Color(0xFFE8EDF5),
                  ),
              ],
            ),
          );
        }),








      ),
    );
  }
}
