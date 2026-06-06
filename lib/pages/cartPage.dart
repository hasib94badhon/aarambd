import 'dart:async';
import 'package:aaram_bd/config.dart';
import 'dart:convert';
import 'dart:io';
import 'package:aaram_bd/screens/advert_screen.dart';
import 'package:aaram_bd/screens/favorite_screen.dart';
import 'package:aaram_bd/widgets/SearchPillButton.dart';
import 'package:aaram_bd/widgets/user_current_location.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:aaram_bd/screens/Search_Category.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:aaram_bd/widgets/user_current_location.dart';

// Import FavoriteScreen

final String host = Config.host;

// Data model for category counts
class CategoryCount {
  final int categoryCount;
  final String categoryName;
  final String cat_id;
  final photo;

  CategoryCount({
    required this.categoryCount,
    required this.categoryName,
    required this.cat_id,
    required this.photo,
  });

  factory CategoryCount.fromJson(Map<String, dynamic> json) {
    return CategoryCount(
      categoryCount: json['count'],
      categoryName: json['cat_name'],
      cat_id: json['cat_id'],
      photo: json['cat_logo'],
    );
  }
}

// Data model for user details
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

  UserDetail({
    required this.address,
    required this.business_name,
    required this.category,
    required this.photo,
    required this.phone,
    required this.userId,
    required this.shop_id,
    required this.service_id,
    required this.isservice,
  });

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    int serviceId = json['service_id'] ?? 0;
    int shopId = json['shop_id'] ?? 0;
    return UserDetail(
      address: json['location'] ?? '',
      category: json['cat_name'] ?? '',
      business_name: json['name'] ?? '',
      photo: json['photo'],
      phone: json['phone'] ?? 0,
      userId: serviceId != 0 ? serviceId : shopId,
      service_id: serviceId,
      shop_id: shopId,
      isservice: serviceId != 0,
    );
  }
}

class CartPage extends StatefulWidget {
  final String userPhone;
  final Key? key;
  final dynamic data; // Add this parameter to accept the data

  CartPage({required this.userPhone, this.data, this.key});

  @override
  _CartPageState createState() => _CartPageState(userPhone: userPhone);
}

class _CartPageState extends State<CartPage> {
  final String userPhone;
  List<String> categories = [];
  List<String> filteredCategories = [];
  final TextEditingController searchController = TextEditingController();
  late SearchController searchBarController;

  final LocationService locationService = LocationService();

  final ScrollController _scrollCtrl = ScrollController();
  double _pillOpacity = 1.0;
  Timer? _opacityTimer;

  _CartPageState({required this.userPhone});
  late Future<Map<String, List<dynamic>>> data;

  @override
  void initState() {
    super.initState();
    data = fetchData();
    fetchCategories();
    _updateLocationOnLogin();
  }

  void _updateLocationOnLogin() async {
    await locationService.updateUserLocationFromStorage();
  }

  Future<void> fetchCategories() async {
    final response = await http.get(
      Uri.parse("$host/get_categories_name"),
    );

    if (response.statusCode == 200) {
      final category_data = json.decode(response.body);
      setState(() {
        categories = List<String>.from(category_data['categories']);
        filteredCategories = categories;
      });
    } else {
      print("Failed to fetch categories: ${response.statusCode}");
    }
  }

  void updateCategoryUsage(String catId) async {
    final response = await http.post(
      Uri.parse('$host/update_cat_used'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'cat_id': catId}),
    );

    if (response.statusCode == 200) {
      print("Category usage updated successfully");
    } else {
      print("Failed to update category usage: ${response.body}");
    }
  }

  Future<Map<String, List<dynamic>>> fetchData() async {
    final url = "$host/get_combined_data";
    int retries = 3;
    for (int i = 0; i < retries; i++) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 60)); // Increase timeout duration
        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body);
          final categoryCounts = jsonResponse['category_count'] != null
              ? (jsonResponse['category_count'] as List)
                  .map((data) => CategoryCount.fromJson(data))
                  .toList()
              : <CategoryCount>[];
          final userDetails = jsonResponse['combined_information'] != null
              ? (jsonResponse['combined_information'] as List)
                  .map((data) => UserDetail.fromJson(data))
                  .toList()
              : <UserDetail>[];

          return {
            'categoryCounts': categoryCounts,
            'userDetails': userDetails,
          };
        } else {
          throw Exception('Failed to load data from API');
        }
      } on SocketException catch (e) {
        if (i == retries - 1) {
          throw Exception("Failed to connect to API: ${e.message}");
        }
      } on http.ClientException catch (e) {
        if (i == retries - 1) {
          throw Exception("Failed to connect to API: ${e.message}");
        }
      } catch (e) {
        if (i == retries - 1) {
          throw Exception("An unexpected error occurred: ${e.toString()}");
        }
      }
      await Future.delayed(Duration(seconds: 2)); // Delay before retrying
    }
    throw Exception("Failed to connect to API after $retries attempts");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, List<dynamic>>>(
        future: data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              return Center(child: Text("Error: ${snapshot.error}"));
            } else if (snapshot.hasData) {
              final categories =
                  snapshot.data!['categoryCounts'] as List<CategoryCount>;
              final users = snapshot.data!['userDetails'] as List<UserDetail>;

              return Stack(
                children: [
                  Column(
                    children: [
                      Expanded(
                        flex: 2,
                        child: GridView.builder(
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 1,
                            crossAxisSpacing: 1,
                            childAspectRatio: 0.92,
                          ),
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                              elevation: 10.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(50),
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFF00C9FF),
                                      Color(0xFF92FE9D),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 6,
                                      offset: Offset(2, 4),
                                    ),
                                  ],
                                ),
                                child: InkWell(
                                  onTap: () {
                                    updateCategoryUsage(
                                        category.cat_id.toString());
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => FavoriteScreen(
                                          userPhone: userPhone,
                                          categoryName: category.categoryName,
                                          cat_id: category.cat_id.toString(),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(45),
                                          image: DecorationImage(
                                            image: NetworkImage(
                                              "https://aarambd.com/cat logo/${category.photo}",
                                            ),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 16,
                                        bottom: 24 +
                                            MediaQuery.of(context)
                                                .padding
                                                .bottom,
                                        child: AnimatedOpacity(
                                          duration:
                                              const Duration(milliseconds: 180),
                                          opacity: _pillOpacity,
                                          child: SearchPillButton(
                                            onTap: () =>
                                                openSearchCategorySheet(
                                              context,
                                              CategoryType.all,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueGrey.withValues(alpha: 0.5),
                              spreadRadius: -1,
                              blurRadius: 1,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }
          }
          return Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: CartPage(
      userPhone: "",
    ),
  ));
}
