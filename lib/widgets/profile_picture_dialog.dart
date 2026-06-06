// profile_picture_dialog.dart
import 'package:flutter/material.dart';

class ProfilePictureDialog extends StatelessWidget {
  final String? photoUrl;

  const ProfilePictureDialog({Key? key, this.photoUrl}) : super(key: key);

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
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(width: 4, color: Colors.tealAccent),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      spreadRadius: 5,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: (photoUrl != null && photoUrl!.isNotEmpty)
                      ? Image.network(
                          photoUrl!,
                          fit: BoxFit.cover,
                          width: 240,
                          height: 240,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.person,
                                size: 100, color: Colors.white);
                          },
                        )
                      : Icon(Icons.person, size: 100, color: Colors.white),
                ),
              ),
            );
          },
        );
      },
      child: Container(
        width: 110,
        height: 110,
        margin: EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(width: 3, color: Colors.white),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.5),
              spreadRadius: 2,
              blurRadius: 10,
              offset: Offset(0, 3),
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
                        size: 50, color: Colors.white);
                  },
                )
              : Icon(Icons.person, size: 50, color: Colors.white),
        ),
      ),
    );
  }
}
