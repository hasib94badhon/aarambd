import 'package:flutter/material.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';

class CustomBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavigation({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final iconList = [
      Icons.dashboard_outlined,
      Icons.hive_rounded,
      Icons.engineering_rounded,
      Icons.view_carousel_rounded,
      Icons.person,
    ];

    final labelList = [
      'Feeds',
      'Top',
      'Experts',
      'Mart',
      'My Profile',
    ];

    const brand = Color(0xFF1A56DB);
    const inactive = Color(0xFF5A5A5A);

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF6FAFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
        border: const Border(
          top: BorderSide(color: Color(0x142F80ED), width: 1),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6, top: 6),
        child: AnimatedBottomNavigationBar.builder(
          itemCount: iconList.length,
          backgroundColor: Colors.transparent,
          tabBuilder: (int index, bool isActive) {
            final color = isActive ? brand : inactive;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Icon(
                    iconList[index],
                    size: isActive ? 34 : 28,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  style: TextStyle(
                    fontSize: isActive ? 14.5 : 13.0,
                    color: color,
                    fontWeight:
                        isActive ? FontWeight.w800 : FontWeight.w500,
                  ),
                  child: Text(labelList[index]),
                ),
                const SizedBox(height: 4),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isActive ? 1.0 : 0.0,
                  child: Container(
                    width: 18,
                    height: 3,
                    decoration: BoxDecoration(
                      color: brand,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            );
          },
          activeIndex: currentIndex,
          gapLocation: GapLocation.none,
          notchSmoothness: NotchSmoothness.softEdge,
          leftCornerRadius: 16,
          elevation: 0,
          height: 68,
          onTap: onTap,
        ),
      ),
    );
  }
}
