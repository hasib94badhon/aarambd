import 'dart:convert';

import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/pages/subscriptionofferpage.dart';
import 'package:aaram_bd/screens/FavoriteProfilesPage.dart';
import 'package:aaram_bd/widgets/SettingsPage.dart';
import 'package:aaram_bd/widgets/my_app.dart';
import 'package:flutter/material.dart';

import 'MostUsedCategoriesPage.dart';
import 'UpdatePost.dart';
import 'FbPage.dart';
import 'HotlineCategory.dart';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

final String host = Config.host;

class AppDrawer extends StatefulWidget {
  final String userPhone;

  const AppDrawer({
    Key? key,
    required this.userPhone,
  }) : super(key: key);

  @override
  _AppDrawerState createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  late String userName;
  late String userPhotoUrl;
  late String category;
  late int cat_id;
  late String userID;

  bool _isLoading = true;
  bool _isNavigating = false;

  Map<String, dynamic> drawerData = {};

  @override
  void initState() {
    super.initState();
    userName = "Loading...";
    userPhotoUrl = '';
    category = "Loading...";
    cat_id = 0;
    userID = "";
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    try {
      final userResponse = await Config.apiGet(
        '/get_user_by_phone?phone=${widget.userPhone}',
        context,
      );

      if (userResponse != null && userResponse.statusCode == 200) {
        final userData = json.decode(userResponse.body);
        if (!mounted) return;

        setState(() {
          userName = userData['name'] ?? "User Name";
          category = userData['cat_name'] ?? "Category";
          cat_id = userData['cat_id'] ?? 0;
          userID = userData['user_id'] ?? "";
          userPhotoUrl = userData['photo'] ?? '';
        });
      }

      final responses = await Future.wait([
        Config.apiGet("/get_most_used_category", context),
        Config.apiGet("/get_today_post?sort_by=recent", context),
        Config.apiGet("/get_fb_page", context),
        Config.apiGet("/get_app_by_category", context),
        Config.apiGet("/get_hotlines_by_category", context),
      ]);

      if (!mounted) return;

      setState(() {
        drawerData = {
          'most_used': responses[0] != null && responses[0]!.statusCode == 200
              ? json.decode(responses[0]!.body)
              : null,
          'today_posts': responses[1] != null && responses[1]!.statusCode == 200
              ? json.decode(responses[1]!.body)
              : null,
          'fb_pages': responses[2] != null && responses[2]!.statusCode == 200
              ? json.decode(responses[2]!.body)
              : null,
          'social_apps': responses[3] != null && responses[3]!.statusCode == 200
              ? json.decode(responses[3]!.body)
              : null,
          'hotlines': responses[4] != null && responses[4]!.statusCode == 200
              ? json.decode(responses[4]!.body)
              : null,
        };
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: ${e.toString()}')),
      );
    }
  }

  void _reopenDrawerOnReturn(Future<dynamic> navFuture) {
    navFuture.whenComplete(() {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 80), () {
        if (!mounted) return;
        final scaffold = Scaffold.maybeOf(context);
        scaffold?.openDrawer();
      });
    });
  }

  void _navigateToPage(String title) {
    if (_isNavigating || _isLoading) return;

    setState(() => _isNavigating = true);
    Navigator.pop(context);

    switch (title) {
      case 'Daily Used Categories':
        if (drawerData['most_used'] != null) {
          _reopenDrawerOnReturn(
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MostUsedCategoriesPage(
                  categories: drawerData['most_used']['most_used_cat'],
                ),
              ),
            ),
          );
        }
        break;

      case 'To-day Live':
        if (drawerData['today_posts'] != null) {
          _reopenDrawerOnReturn(
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UpdatePost(
                  posts: drawerData['today_posts']['most_update_post'],
                  selectedSort: 'recent',
                ),
              ),
            ),
          );
        }
        break;

      case 'FB Business':
        if (drawerData['fb_pages'] != null) {
          _reopenDrawerOnReturn(
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FbCategoryPage(
                  pages: drawerData['fb_pages']['fb_page'],
                ),
              ),
            ),
          );
        }
        break;

      case 'BD Social Apps':
        if (drawerData['social_apps'] != null &&
            drawerData['social_apps']['success'] == true) {
          _reopenDrawerOnReturn(
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AppHomePage(
                  categories: (drawerData['social_apps']['app_cat'] as List)
                      .map((item) => AppCategory.fromJson(item))
                      .toList(),
                ),
              ),
            ),
          );
        }
        break;

      case 'Hotline Numbers':
        if (drawerData['hotlines'] != null &&
            drawerData['hotlines']['success'] == true) {
          _reopenDrawerOnReturn(
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => Hotlinecategory(
                  categories: drawerData['hotlines']['hotline_cat'],
                ),
              ),
            ),
          );
        }
        break;

      case 'Settings':
        _reopenDrawerOnReturn(
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SettingsPage()),
          ),
        );
        break;

      case 'Subscription Offers':
        _reopenDrawerOnReturn(
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SubscriptionOfferPage()),
          ),
        );
        break;

      case 'Favorite Contacts':
        if (userID.isNotEmpty) {
          _reopenDrawerOnReturn(
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FavoriteProfilesPage(userId: userID),
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User ID not loaded yet')),
          );
        }
        break;
    }

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _isNavigating = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Drawer(
          width: MediaQuery.of(context).size.width * 0.90,
          child: Container(
            decoration: BoxDecoration(color: Colors.blue[50]),
            child: Stack(
              children: [
                // ✅ Background stickers (behind everything)
                Positioned(
                  top: 140,
                  left: -30,
                  child: _StickerDot(size: 110, color: Colors.blue),
                ),
                Positioned(
                  top: 260,
                  right: -40,
                  child: _StickerDot(size: 140, color: Colors.indigo),
                ),
                Positioned(
                  bottom: 90,
                  left: -25,
                  child: _StickerDot(size: 90, color: Colors.lightBlue),
                ),
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: _StickerDot(size: 34, color: Colors.blue, opacity: 0.22),
                ),

                Column(
                  children: [
                    // ✅ Header with stickers + gradient
                    Container(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 50,
                        bottom: 20,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF1A56DB),
                            Colors.indigo.shade900,
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(22),
                          bottomRight: Radius.circular(22),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Header stickers
                          Positioned(
                            top: -12,
                            right: -10,
                            child: _StickerDot(
                              size: 70,
                              color: Colors.white,
                              opacity: 0.10,
                            ),
                          ),
                          Positioned(
                            bottom: -18,
                            left: -12,
                            child: _StickerDot(
                              size: 90,
                              color: Colors.white,
                              opacity: 0.08,
                            ),
                          ),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Profile picture
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 8,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _isLoading
                                      ? Shimmer.fromColors(
                                          baseColor: Colors.grey.shade300,
                                          highlightColor: Colors.grey.shade100,
                                          child: Container(color: Colors.white),
                                        )
                                      : userPhotoUrl.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: userPhotoUrl,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) =>
                                                  Container(color: Colors.grey.shade200),
                                              errorWidget: (context, url, error) =>
                                                  Icon(Icons.person, size: 40, color: Colors.grey.shade400),
                                            )
                                          : Icon(Icons.person, size: 40, color: Colors.grey.shade400),
                                ),
                              ),
                              const SizedBox(width: 22),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 20,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      category,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Menu items
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: _isLoading
                            ? _buildShimmerLoader()
                            : ListView(
                                children: [
                                  _buildDrawerItem(
                                    icon: Icons.category,
                                    title: 'Daily Used Categories',
                                  ),
                                  _buildDrawerItem(
                                    icon: Icons.apps,
                                    title: 'BD Social Apps',
                                  ),
                                  _buildDrawerItem(
                                    icon: Icons.business,
                                    title: 'FB Business',
                                  ),
                                  _buildDrawerItem(
                                    icon: Icons.live_tv,
                                    title: 'To-day Live',
                                  ),
                                  _buildDrawerItem(
                                    icon: Icons.phone,
                                    title: 'Hotline Numbers',
                                  ),
                                  _buildDrawerItem(
                                    icon: Icons.contacts,
                                    title: 'Favorite Contacts',
                                  ),
                                  if (cat_id != 56)
                                    _buildDrawerItem(
                                      icon: Icons.group,
                                      title: 'Subscription Offers',
                                    ),
                                  _buildDrawerItem(
                                    icon: Icons.settings,
                                    title: 'Settings',
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Minimize icon outside the drawer (middle right)
        Positioned(
          right: 0,
          top: MediaQuery.of(context).size.height / 2 - 25,
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 30,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF1A56DB),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(-2, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_back_ios,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShimmerLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.only(top: 20),
        itemCount: 10,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
  }) {
    // Zigzag density depends on title length
    final int zigCount = (title.length ~/ 2).clamp(7, 14);
    final double zigDepth = (title.length / 2.8).clamp(10.0, 16.0);

    final String? tag = (title == 'To-day Live')
        ? 'LIVE'
        : (title == 'Subscription Offers')
            ? 'HOT'
            : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: ClipPath(
        clipper: RightZigZagClipper(zigs: zigCount, depth: zigDepth),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.blue.shade50],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.blue.shade100.withValues(alpha: 0.85)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 8),
              ),
            ],
            borderRadius: BorderRadius.circular(14),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue.shade100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.10),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Icon(icon, color: const Color(0xFF1A56DB)),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                if (tag != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tag == 'LIVE' ? Colors.red.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: tag == 'LIVE' ? Colors.red.shade200 : Colors.orange.shade200,
                      ),
                    ),
                    child: Text(
                      tag,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: tag == 'LIVE' ? Colors.red.shade700 : Colors.orange.shade700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey.shade600,
              ),
            ),
            onTap: () => _navigateToPage(title),
          ),
        ),
      ),
    );
  }
}

// ✅ Zig-zag right edge clipper
class RightZigZagClipper extends CustomClipper<Path> {
  final int zigs;
  final double depth;

  RightZigZagClipper({this.zigs = 10, this.depth = 12});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width - depth, 0);

    final step = size.height / zigs;
    for (int i = 0; i < zigs; i++) {
      final yMid = (i + 0.5) * step;
      final yNext = (i + 1) * step;

      path.lineTo(size.width, yMid);
      path.lineTo(size.width - depth, yNext);
    }

    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant RightZigZagClipper oldClipper) {
    return oldClipper.zigs != zigs || oldClipper.depth != depth;
    }
}

// ✅ Sticker dot widget
class _StickerDot extends StatelessWidget {
  final double size;
  final Color color;
  final double opacity;

  const _StickerDot({
    required this.size,
    required this.color,
    this.opacity = 0.18,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}
