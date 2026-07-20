import 'package:aaram_bd/config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../screens/advert_screen.dart';

// Replace with your actual host
final String host = Config.host;

// Album model
class Album {
  final String name;
  final String category;
  final int user_viewed;
  final int service_id;
  final int shop_id;
  final bool is_service;
  final String photo;
  final int user_called;
  final String? type;

  Album({
    required this.name,
    required this.category,
    required this.user_viewed,
    required this.service_id,
    required this.shop_id,
    required this.is_service,
    required this.photo,
    this.user_called = 0,
    this.type,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    String fullPhoto = json['photo'] ?? '';
    String firstPhoto = fullPhoto.contains(',')
        ? fullPhoto.split(',').first.trim()
        : fullPhoto.trim();

    return Album(
      name: json['name'] ?? '',
      category: json['cat_name'] ?? '',
      user_viewed: json['user_viewed'] ?? 0,
      service_id: json['service_id'] ?? 0,
      shop_id: json['shop_id'] ?? 0,
      is_service: json['service_id'] != null,
      photo: firstPhoto,
      user_called: json['user_called'] ?? 0,
      type: json['type'],
    );
  }
}

// AdvertData model used by AdvertScreen

class MostViewedUserSlider extends StatelessWidget {
  final List<Album> users;

  const MostViewedUserSlider({Key? key, required this.users}) : super(key: key);

  Future<void> navigateToAdvertScreen(BuildContext context, Album user) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? loginUserId = prefs.getString('user_id');
    final String id =
        user.is_service ? user.service_id.toString() : user.shop_id.toString();
    final String idParam = user.is_service ? 'service_id=$id' : 'shop_id=$id';
    final String url = '/get_service_or_shop_data?$idParam&sort_by=recent';

    try {
      final response =
          await Config.apiPost(url, {'login_user_id': loginUserId}, context);

      if (response != null && response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final dataKey = user.is_service ? 'service_data' : 'shop_data';
        final dataList = jsonResponse[dataKey];

        if (dataList is List && dataList.isNotEmpty) {
          // The tapped profile's real user_id (not the viewer's own id, and
          // not the service/shop record id) — needed so AdvertScreen's review
          // summary / view tracking targets the right person.
          final String profileUserId =
              (dataList[0] as Map<String, dynamic>)['user_id']?.toString() ??
                  '';
          final advertData = AdvertData(
            userId: profileUserId,
            isService: user.is_service,
            additionalData: dataList[0] as Map<String, dynamic>,
          );

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AdvertScreen(
                advertData: advertData,
                userId: profileUserId,
                isService: user.is_service,
              ),
            ),
          );
        } else {
          print('❌ No data found.');
        }
      } else {
        print('❌ Failed with status: ${response?.statusCode}');
      }
    } catch (e) {
      print('❌ Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: users.length,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        itemBuilder: (context, index) {
          final user = users[index];
          final hasPhoto = user.photo.isNotEmpty;

          return GestureDetector(
              onTap: () => navigateToAdvertScreen(context, user),
              child: Container(
                width: 170,
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  // border: Border.all(color: Colors.blue),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Colors.black12, Colors.black26],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withValues(alpha: 0.3),
                                blurRadius: 8,
                                spreadRadius: 2,
                                offset: Offset(4, 4),
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 2,
                                offset: Offset(-4, -4),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: hasPhoto
                                ? Image.network(
                                    user.photo,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Center(
                                      child: Icon(Icons.broken_image, size: 30),
                                    ),
                                  )
                                : const Center(
                                    child: Icon(Icons.image_not_supported,
                                        size: 30),
                                  ),
                          ),
                        ),
                        if (user.type == "paid")
                          Positioned(
                            top: 5,
                            right: 5,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: const Icon(Icons.verified,
                                  size: 23, color: Colors.teal),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 18,
                      child: Text(
                        user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      height: 18,
                      child: Text(
                        user.category,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(
                      height: 17,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.phone_callback,
                                  size: 13, color: Colors.teal),
                              const SizedBox(width: 2),
                              Text(
                                '${Config.formatLargeNumber(user.user_called)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0.5, 0.5),
                                      blurRadius: 1,
                                      color: Colors.black26,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 5),
                          Row(
                            children: [
                              const Icon(Icons.visibility,
                                  size: 13, color: Colors.teal),
                              const SizedBox(width: 2),
                              Text(
                                '${Config.formatLargeNumber(user.user_viewed)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.black54,
                                  shadows: [
                                    Shadow(
                                      offset: Offset(0.5, 0.5),
                                      blurRadius: 1,
                                      color: Colors.black26,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  ],
                ),
              ));
        },
      ),
    );
  }
}
