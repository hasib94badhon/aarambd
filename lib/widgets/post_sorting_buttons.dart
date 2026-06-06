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

  @override
  Widget build(BuildContext context) {
    final l10n = context.watch<LanguageProvider>().l10n;

    final List<Map<String, dynamic>> sortOptions = [
      {'label': l10n.sortRecent, 'value': 'recent'},
      {'label': l10n.sortViewed, 'value': 'most_viewed'},
      {'label': l10n.sortCommented, 'value': 'most_commented'},
    ];

    return Container(
      width: MediaQuery.of(context).size.width * 1,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[50]!, Colors.blue[100]!],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.blueGrey,
            blurRadius: 6,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              l10n.sortPosts,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: sortOptions.map((sortOption) {
                final isSelected = selectedSort == sortOption['value'];
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              Colors.green.shade400,
                              Colors.green.shade600
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : LinearGradient(
                            colors: [Colors.white, Colors.grey.shade200],
                          ),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? Colors.green.withValues(alpha: 0.4)
                            : Colors.grey.withValues(alpha: 0.2),
                        spreadRadius: 2,
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: InkWell(
                    onTap: () => onSortSelected(sortOption['value']),
                    borderRadius: BorderRadius.circular(30),
                    splashColor: Colors.green.withValues(alpha: 0.2),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      child: Text(
                        sortOption['label'],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color:
                              isSelected ? Colors.white : Colors.black87,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
