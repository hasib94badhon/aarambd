import 'package:flutter/material.dart';

/// Renders a 5-star badge for a user's average review rating (from the
/// `user_reviews` table, via GET /review/summary). Replaces the previous
/// profile-completeness/engagement heuristic with the real average left by
/// other users.
class UserStarWidget extends StatelessWidget {
  final double rating;
  final int reviewCount;

  const UserStarWidget({
    super.key,
    required this.rating,
    this.reviewCount = 0,
  });

  // ⭐ Shiny star (UI-only)
  Widget _buildStar(int index) {
    final bool isActive = index < rating.round().clamp(0, 5);

    final Color activeColor = Colors.amber.shade400;
    final Color inactiveColor = Colors.grey.shade400;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? Colors.amber.shade50 : Colors.grey.shade100,
          border: Border.all(
            color: isActive ? Colors.amber.shade200 : Colors.grey.shade300,
            width: 1,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.35),
                blurRadius: 10,
                spreadRadius: 1,
              )
            else
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Icon(
          Icons.star_rounded,
          size: 12,
          color: isActive ? activeColor : inactiveColor,
          shadows: isActive
              ? [
                  Shadow(
                    color: Colors.amber.withValues(alpha: 0.55),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade50,
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.blue.shade100.withValues(alpha: 0.8),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, _buildStar),
      ),
    );
  }
}
