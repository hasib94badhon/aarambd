// location_container.dart
import 'package:flutter/material.dart';

class LocationContainer extends StatelessWidget {
  final BuildContext parentContext;
  final List users;

  const LocationContainer({
    Key? key,
    required this.parentContext,
    required this.users,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_on, color: Colors.redAccent, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: parentContext,
                  builder: (context) {
                    return AlertDialog(
                      backgroundColor: Colors.orange[100]!,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(40),
                      ),
                      contentPadding: EdgeInsets.zero,
                      content: Stack(
                        children: [
                          // Placeholder for the map widget
                          Container(
                            height: 600,
                            width: 450,
                          ),
                          // Address display
                          Positioned(
                            top: 15,
                            left: 15,
                            right: 15,
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: Text(
                                users[0].location,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          // Distance display
                          Positioned(
                            bottom: 15,
                            left: 15,
                            right: 15,
                            child: Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(40),
                              ),
                              child: Text(
                                users[0].user_distance,// Placeholder
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              child: Text(
                users.isNotEmpty ? users[0].address : 'Unknown',
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
