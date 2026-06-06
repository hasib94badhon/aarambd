import 'package:flutter/material.dart';

class NoAdsAnimatedIcon extends StatefulWidget {
  @override
  _NoAdsAnimatedIconState createState() => _NoAdsAnimatedIconState();
}

class _NoAdsAnimatedIconState extends State<NoAdsAnimatedIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    // Controller for animation: 1 second duration, repeating forward and reverse
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 1),
    );

    // Tween for scaling between 1.0 and 1.3 (normal size to 30% bigger)
    _animation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _controller.repeat(reverse: true); // repeat animation continuously
  }

  @override
  void dispose() {
    _controller.dispose(); // clean up controller when widget is removed
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ScaleTransition(
        scale: _animation, // apply the scaling animation here
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.campaign, // megaphone icon (you can change to another if you want)
              size: 60,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'No Advertisement',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
