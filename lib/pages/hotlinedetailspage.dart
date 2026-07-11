import 'package:aaram_bd/model/hotline_category_model.dart';
import 'package:aaram_bd/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
 // Update this to your actual model path

class HotlineDetailsPage extends StatelessWidget {
  final HotlineCategoryModel category;

  const HotlineDetailsPage({Key? key, required this.category}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  appBar: AppBar(
    title: Text(category.category),
    backgroundColor: Colors.white,
  ),
  body: ListView.builder(
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
    itemCount: category.names.length,
    itemBuilder: (context, index) {
      final name = category.names[index];
      final phone = category.phones.length > index ? category.phones[index] : 'N/A';
      final photo = category.photos.length > index ? category.photos[index] : '';

      return Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.6),
              spreadRadius: 2,
              blurRadius: 12,
              offset: Offset(4, 6), // X, Y
            ),
            BoxShadow(
              color: Colors.black12,
              spreadRadius: 1,
              blurRadius: 5,
              offset: Offset(-1, -2),
            ),
          ],
          border: Border.all(color: Colors.red.shade100, width: 0.5),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: photo.isNotEmpty
                  ? Colors.transparent
                  : Colors.red.shade200,
              backgroundImage: photo.isNotEmpty ? NetworkImage(photo) : null,
              child: photo.isEmpty
                  ? Icon(Icons.phone, color: Colors.white, size: 28)
                  : null,
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 17,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    phone,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            Container(
  decoration: BoxDecoration(
    color: Colors.green.shade100, // background color
    shape: BoxShape.circle,
    boxShadow: [
      BoxShadow(
        color: Colors.green.withValues(alpha: 0.4), // shadow color
        blurRadius: 8,
        offset: const Offset(2, 4),
      ),
    ],
  ),
  child: IconButton(
    icon: const Icon(Icons.call, size: 26, color: Colors.green),
    onPressed: () async {
      if (phone != 'N/A' && phone.isNotEmpty) {
        final Uri phoneUri = Uri(scheme: 'tel', path: phone);
        if (await canLaunchUrl(phoneUri)) {
          await launchUrl(phoneUri);
        } else {
          showAppToast(context, "Couldn't launch phone dialer",
              icon: Icons.error_outline_rounded);
        }
      }
    },
  ),
)

          ],
        ),
      );
    },
  ),
);

  }
}
