// profile_picture_dialog.dart
import 'package:flutter/material.dart';

class ProfilePictureDialog extends StatelessWidget {
  final String? photoUrl;
  final double size;

  const ProfilePictureDialog({Key? key, this.photoUrl, this.size = 110})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.4),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: (photoUrl != null && photoUrl!.isNotEmpty)
                      ? Image.network(
                          photoUrl!,
                          fit: BoxFit.cover,
                          width: 280,
                          height: 280,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(Icons.person,
                                size: 110, color: Colors.white);
                          },
                        )
                      : const Icon(Icons.person, size: 110, color: Colors.white),
                ),
              ),
            );
          },
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(width: 3, color: Colors.white),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.4),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipOval(
          child: (photoUrl != null && photoUrl!.isNotEmpty)
              ? Image.network(
                  photoUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(Icons.person,
                        size: size * 0.45, color: Colors.white);
                  },
                )
              : Icon(Icons.person, size: size * 0.45, color: Colors.white),
        ),
      ),
    );
  }
}
