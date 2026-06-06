
import 'package:flutter/material.dart';

class ExpandableDescription extends StatefulWidget {
  final String text;
  const ExpandableDescription({super.key, required this.text});

  @override
  State<ExpandableDescription> createState() => _ExpandableDescriptionState();
}

class _ExpandableDescriptionState extends State<ExpandableDescription> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final displayText =
    widget.text.trim().isEmpty ? "No description added" : widget.text;

    final showButton = displayText.length > 150;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        children: [
          Text(
            displayText,
            textAlign: TextAlign.center,
            maxLines: _isExpanded ? null : 5,
            overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 15.5,
              height: 1.5,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (showButton)
            TextButton(
              onPressed: () {
                setState(() => _isExpanded = !_isExpanded);
              },
              child: Text(
                _isExpanded ? "See less" : "See more",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueAccent,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
