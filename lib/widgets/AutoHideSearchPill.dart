import 'package:aaram_bd/widgets/SearchPillButton.dart';
import 'package:flutter/material.dart';

class AutoHideSearchPill extends StatefulWidget {
  final ScrollController scrollController;
  final VoidCallback onTap;
  final String label;

  const AutoHideSearchPill({
    Key? key,
    required this.scrollController,
    required this.onTap,
    this.label = 'Search',
  }) : super(key: key);

  @override
  State<AutoHideSearchPill> createState() => _AutoHideSearchPillState();
}

class _AutoHideSearchPillState extends State<AutoHideSearchPill>
    with SingleTickerProviderStateMixin {
  bool _visible = true;
  double _lastOffset = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final offset = widget.scrollController.position.pixels;
    final goingDown = offset > _lastOffset + 4;   // small threshold
    final goingUp   = offset < _lastOffset - 4;

    if (goingDown && _visible) {
      setState(() => _visible = false);
    } else if (goingUp && !_visible) {
      setState(() => _visible = true);
    }
    _lastOffset = offset;
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    return AnimatedSlide(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      offset: _visible ? Offset.zero : const Offset(0, 1.2),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: _visible ? 1 : 0,
        child: Positioned(
          right: 16,
          bottom: 24 + bottomSafe,
          child: SearchPillButton(onTap: widget.onTap),
        ),
      ),
    );
  }
}
