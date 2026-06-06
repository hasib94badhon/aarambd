import 'package:flutter/material.dart';

class UserStarWidget extends StatefulWidget {
  final bool showEditIcon;
  final String? phone;
  final String? name;
  final String? profilePicture;
  final String? tin;
  final String? nid;
  final int postCount;
  final int view;
  final String? sub_type;
  final int usercall;

  const UserStarWidget({
    super.key,
    this.showEditIcon = false,
    required this.phone,
    required this.name,
    required this.profilePicture,
    required this.tin,
    required this.nid,
    required this.postCount,
    required this.view,
    required this.sub_type,
    required this.usercall,
  });

  @override
  State<UserStarWidget> createState() => _UserStarWidgetState();
}

class _UserStarWidgetState extends State<UserStarWidget> {
  int calculateStars() {
    int stars = 0;

    if (widget.phone != null &&
        widget.phone!.isNotEmpty &&
        widget.name != null &&
        widget.name!.isNotEmpty &&
        widget.profilePicture != null &&
        widget.profilePicture!.isNotEmpty) {
      stars++;
    }

    if (widget.tin != null && widget.tin!.isNotEmpty ||
        widget.nid != null && widget.nid!.isNotEmpty) {
      stars++;
    }

    // this margin or target has given based on one month
    if (widget.view >= 1500 && widget.usercall > 500) {
      stars++;
    }

    // this margin or target has given based on one month
    if (widget.postCount >= 150) {
      stars++;
    }

    if (widget.sub_type == 'paid') {
      stars++;
    }

    return stars;
  }

  // ⭐ Shiny star (UI-only)
  Widget buildStar(int index, int starCount) {
    final bool isActive = index < starCount;

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
    final int starCount = calculateStars(); // <- always fresh!

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
        children: [
          Row(
            children: List.generate(5, (index) => buildStar(index, starCount)),
          ),

        ],
      ),
    );
  }
}
