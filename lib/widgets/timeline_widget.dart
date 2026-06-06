import 'package:aaram_bd/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:aaram_bd/screens/advert_screen.dart';



final String host = Config.host;
class UserDetail {
  final String address;
  final String business_name;
  final String category;
  final String photo;
  final String phone;
  final int shop_id;
  final int service_id;
  final int userId;
  final bool isservice;
  final String extra;

  UserDetail(
      {required this.address,
      required this.business_name,
      required this.category,
      required this.photo,
      required this.phone,
      required this.userId,
      required this.shop_id,
      required this.service_id,
      required this.isservice,
      required this.extra});

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    int serviceId = json['service_id'] ?? 0;
    int shopId = json['shop_id'] ?? 0;

    // Initialize the extra field with an empty string
    String extra = '';

    // Add location if present
    if (json['location'] != null && json['location'].isNotEmpty) {
      extra += 'Location: ${json['location']} ';
    }

    // Add view if present
    if (json['view'] != null && json['view'] != 0) {
      extra += 'Total View: ${json['view']} ';
    }

    // Add call if present
    if (json['call'] != null && json['call'] != 0) {
      extra += 'Total Call: ${json['call']} ';
    }

    String day = json['days_since_creation'];
    // Add days_since_creation if present
    if (json['days_since_creation'] != "" && json['days_since_creation'] != 0) {
      if (day == "0") {
        extra += 'Active Today';
      } else if (day == "1") {
        extra += 'Active 1 day Ago';
      } else {
        extra += 'Active ${json['days_since_creation']} days ago';
      }
    }
    return UserDetail(
      address: json['location'] ?? '',
      category: json['cat_name'] ?? '',
      business_name: json['name'] ?? '',
      photo: json['photo'] ?? '',
      phone: json['phone'] ?? 0,
      userId: serviceId != 0 ? serviceId : shopId,
      service_id: serviceId,
      shop_id: shopId,
      isservice: serviceId != 0,
      extra: extra.trim(), //ensure there no trailing spaces
    );
  }
}

class TimelineWidget extends StatefulWidget {
   
  final int cat_id;
  final String dataType; // Add dataType parameter

  const TimelineWidget({
    Key? key,
    required this.cat_id,
    required this.dataType, // Accept dataType in constructor
  }) : super(key: key);

  @override
  State<TimelineWidget> createState() => _TimelineWidgetState();
}

class _TimelineWidgetState extends State<TimelineWidget> {
  late Future<List<UserDetail>> serviceData;
  late Future<List<UserDetail>> shopData;
  String sortBy = '';

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  void fetchData() {
    serviceData = fetchPosts(widget.cat_id.toString(), 'service', sortBy);
    shopData = fetchPosts(widget.cat_id.toString(), 'shop', sortBy);
  }

  Future<List<UserDetail>> fetchPosts(
      String cat_id, String dataType, String sortBy) async {
    String info = '';
    final String url =
        '$host/get_data_by_category?data_type=${widget.dataType}&cat_id=${widget.cat_id}&sort_by=$sortBy';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (widget.dataType == 'service') {
          info = 'service_information';
        } else {
          info = 'shop_information';
        }
        final userDetails = jsonResponse[info] != null
            ? (jsonResponse[info] as List)
                .map((data) => UserDetail.fromJson(data))
                .toList()
            : <UserDetail>[];
        return userDetails;
      } else {
        throw Exception('Failed to load posts');
      }
    } catch (e) {
      throw Exception('An unexpected error occurred: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<UserDetail>>(
      future: Future.wait([serviceData, shopData])
          .then((results) => results.expand((x) => x).toList()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          } else if (snapshot.hasData) {
            final posts = snapshot.data!;
            return Container(
              color: Colors.white,
              height: 130, // Slightly taller for better spacing
              child: ListView.builder(
                itemCount: posts.length,
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) {
                  var post = posts[index];

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AdvertScreen(
                            userId: post.userId.toString(),
                            isService: post.isservice,
                            advertData: AdvertData(
                              userId: post.userId.toString(),
                              isService: post.isservice,
                              additionalData: post.isservice
                                  ? {'service_id': post.service_id}
                                  : {'shop_id': post.shop_id},
                            ),
                          ),
                        ),
                      );
                    },
                    child: Container(
                      width: 120,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 3, vertical: 5),
                       padding: const EdgeInsets.symmetric(
                           vertical: 3, horizontal: 2),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color.fromARGB(255, 132, 238, 217), // Aquamarine green
                            Color.fromARGB(255, 64, 185, 255), // Deep blue-purple
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 10,
                            spreadRadius: 3,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Profile Image with shadow and fallback
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.network(
                                post.photo != null && post.photo.isNotEmpty
                                    ? post.photo
                                    : 'https://via.placeholder.com/150?text=No+Image',
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.network(
                                    'https://via.placeholder.com/150?text=No+Image',
                                    width: 100,
                                    height: 100,
                                    fit: BoxFit.cover,
                                  );
                                },
                              ),
                            ),
                          ),


                          // Business Name
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              post.business_name,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.6,
                                shadows: [
                                  Shadow(
                                    color: Colors.black45,
                                    blurRadius: 6,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),


                          // Category Name
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(
                              post.category,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Color(0xFFD0FFD6), // Soft mint text
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.4,
                                shadows: [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          } else {
            return Center(child: Text("No posts available"));
          }
        }
        return Center(child: CircularProgressIndicator());
      },
    );
  }
}
