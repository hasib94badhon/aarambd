import 'dart:async';
import 'dart:convert';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/pages/hotlinedetailspage.dart';
import 'package:aaram_bd/screens/favorite_screen.dart';
import 'package:aaram_bd/screens/post_details.dart';
import 'package:aaram_bd/widgets/FbPage.dart';
import 'package:aaram_bd/widgets/HotlineCategory.dart';
import 'package:aaram_bd/widgets/MostUsedCategoriesPage.dart';
import 'package:aaram_bd/widgets/MostViewedUserSlider.dart';
import 'package:aaram_bd/widgets/UpdatePost.dart';
import 'package:aaram_bd/widgets/my_app.dart';
import 'package:aaram_bd/widgets/user_current_location.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aaram_bd/model/hotline_category_model.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

String host = Config.host;

/* ===================== Models (unchanged logic) ===================== */

class PostModel {
  final String catName;
  final int postId;
  final String description;
  final String time;
  final int views;
  final String media;
  final String userName;
  final String userPhoto;
  final int userId;
  final int commentCount;

  PostModel({
    required this.catName,
    required this.postId,
    required this.description,
    required this.time,
    required this.views,
    required this.media,
    required this.userName,
    required this.userPhoto,
    required this.userId,
    required this.commentCount,
  });

factory PostModel.fromJson(Map<String, dynamic> json) {
  String pickFirstImage(dynamic value) {
    if (value == null) return '';
    // if backend sends array
    if (value is List) {
      final list = value.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      return list.isNotEmpty ? list.first : '';
    }
    // if backend sends comma-separated string
    final s = value.toString().trim();
    if (s.isEmpty) return '';
    final list = s.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return list.isNotEmpty ? list.first : '';
  }

  // try multiple possible keys
  final mediaCandidate = pickFirstImage(json['post_media']);
  final photoCandidate = pickFirstImage(json['photo']);
  final alt1 = pickFirstImage(json['post_photo']);
  final alt2 = pickFirstImage(json['post_image']);
  final alt3 = pickFirstImage(json['post_thumbnail']);

  // keep your "media is a string" format
  final resolvedMedia = (mediaCandidate.isNotEmpty
          ? mediaCandidate
          : photoCandidate.isNotEmpty
              ? photoCandidate
              : alt1.isNotEmpty
                  ? alt1
                  : alt2.isNotEmpty
                      ? alt2
                      : alt3)
      .toString();

  return PostModel(
    catName: (json['cat_name'] ?? '').toString(),
    postId: json['post_id'],
    description: (json['post_main_description'] ?? '').toString(),
    time: (json['post_time'] ?? '').toString(),
    views: json['post_viewed'] ?? 0,
    media: resolvedMedia,
    userName: (json['user_name'] ?? '').toString(),
    userPhoto: (json['user_photo'] ?? '').toString(),
    userId: json['user_id'] ?? 0,
    commentCount: json['comment_count'] ?? 0,
  );
}


}

class FbPage {
  final int pageId;
  final String name;
  final String cat;
  final String photo;
  final String link;
  final String location;
  final String time;
  final String phone;
  final int totalViews;

  FbPage({
    required this.pageId,
    required this.name,
    required this.cat,
    required this.photo,
    required this.link,
    required this.location,
    required this.time,
    required this.phone,
    required this.totalViews,
  });

  factory FbPage.fromJson(Map<String, dynamic> json) {
    return FbPage(
      pageId: json['page_id'],
      name: json['name'],
      cat: json['cat'],
      photo: json['photo'] ?? '',
      link: json['link'] ?? '',
      location: json['location'] ?? '',
      time: json['time'] ?? '',
      phone: json['phone'].toString(),
      totalViews: json['visit_count'] ?? 0,
    );
  }
}

class AppModel {
  final String name;
  final String photo;
  final String deeplink;
  final String androidLink;
  final String iosLink;
  final String web;

  AppModel({
    required this.name,
    required this.photo,
    required this.deeplink,
    required this.androidLink,
    required this.iosLink,
    required this.web,
  });

  factory AppModel.fromJson(Map<String, dynamic> json) {
    return AppModel(
      name: json['name'] ?? '',
      photo: json['photo'] ?? '',
      deeplink: json['deeplink'] ?? '',
      androidLink: json['android_link'] ?? '',
      iosLink: json['ios_link'] ?? '',
      web: json['web'] ?? '',
    );
  }
}

class SliderPostItem {
  final String postId;
  final String imageUrl;
  final String userName; // optional nice label

  SliderPostItem({
    required this.postId,
    required this.imageUrl,
    required this.userName,
  });

  factory SliderPostItem.fromJson(Map<String, dynamic> json) {
    // ✅ image priority:
    // 1) post_media (comma list) => use first
    // 2) photo => use photo
    String image = '';

    final media = (json['post_media'] ?? '').toString();
    if (media.isNotEmpty) {
      final list = media
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (list.isNotEmpty) image = list.first;
    }

    if (image.isEmpty) {
      final photo = (json['photo'] ?? '').toString();
      if (photo.isNotEmpty) image = photo;
    }

    return SliderPostItem(
      postId: (json['post_id'] ?? '').toString(),
      imageUrl: image,
      userName: (json['user_name'] ?? 'Post').toString(),
    );
  }
}


// Future<List<Album>> fetchAlbum() async {
//   final response = await http.get(Uri.parse('$host/get_users_data'));
//   if (response.statusCode == 200) {
//     final Map<String, dynamic> data = jsonDecode(response.body);
//     final List<dynamic> userData = data['users_data'];
//     return userData.map((json) => Album.fromJson(json)).toList();
//   } else {
//     throw Exception('Failed to load album');
//   }
// }

/* ===================== Page (unchanged data flow, refined UI) ===================== */

class Homepage extends StatefulWidget {
  const Homepage({Key? key}) : super(key: key);

  @override
  State<Homepage> createState() => _HomepageState();
}

enum PostSortType { mostCommented, mostViewed, mostRecent }

PostSortType _selectedSortType = PostSortType.mostCommented;

class _HomepageState extends State<Homepage> with TickerProviderStateMixin {
  String? loginUserId;

  late Future<List<Album>> futureAlbum;
  final PageController _adPageController = PageController();
  int _currentPage = 0;
 List<SliderPostItem> _sliderPosts = [];
  Timer? _sliderTimer;
  List<dynamic> _mostUsedCategories = [];
  List<Album> _mostViewedUsers = [];
  List<AppModel> _apps = [];
  List<HotlineCategoryModel> _hotlineCategories = [];
  List<PostModel> _topCommentedPosts = [];

  // List<dynamic> _descriptionCategories = [];
  // Map<String, List<dynamic>> _categoryDescriptions = {};
  TabController? _descTabController;

  // bool _descLoading = true;
  String? lastOpenedCatId;
  bool _isLoading = false;
  late Future<List<FbPage>> _futurePages;
  final LocationService locationService = LocationService();

  @override
  void initState() {
    super.initState();
    // futureAlbum = fetchAlbum();
    fetchTopViewedSliderPosts().then((items) {
  if (!mounted) return;
  setState(() => _sliderPosts = items);
  _startSlider();
});

    _loadLoginUser();
    loadMostUsedCategory();
    fetchMostViewedUsers();
    fetchAppData();
    fetchHotlineCategories();
    fetchTopPosts();
    // fetchDescriptionData();
    fetchAppData();
    _futurePages = fetchFbPages();
    _updateLocationOnLogin();
  }

  Future<void> _loadLoginUser() async {
    loginUserId = await Config.getLoggedInUser();
    setState(() {});
  }

  void _updateLocationOnLogin() async {
    await locationService.updateUserLocationFromStorage();
  }

  bool _isButtonClicked = false;

  void _avoidMultipleClick(VoidCallback onTap) {
    if (_isButtonClicked) return;

    _isButtonClicked = true;
    onTap();

    // Delays next action by 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      _isButtonClicked = false;
    });
  }

 void _startSlider() {
  _sliderTimer?.cancel();
  if (_sliderPosts.isEmpty) return;

  _sliderTimer = Timer.periodic(const Duration(seconds: 2), (_) {
    if (!mounted) return;
    if (!_adPageController.hasClients) return;
    if (_sliderPosts.isEmpty) return;

    final next = (_currentPage + 1) % _sliderPosts.length;

    // ✅ Schedule after frame to avoid "setState during build"
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_adPageController.hasClients) return;

      _currentPage = next;
      _adPageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );

      // ✅ setState only if you need indicator update
      setState(() {});
    });
  });
}



  void _onPostSortChanged(PostSortType type) {
    setState(() => _selectedSortType = type);

    String sortParam;
    switch (type) {
      case PostSortType.mostViewed:
        sortParam = 'most_viewed';
        break;
      case PostSortType.mostRecent:
        sortParam = 'most_recent';
        break;
      default:
        sortParam = 'most_commented';
    }

    fetchTopPosts(sort: sortParam);
  }

Future<void> _refreshAll() async {
  if (!mounted) return;

  // Optional: show refresh spinner a bit even if calls are super fast
  // await Future.delayed(const Duration(milliseconds: 300));

  try {
    // stop slider first
    _sliderTimer?.cancel();

    // refetch everything
    await Future.wait([
      _loadLoginUser(),
      loadMostUsedCategory(),
      fetchMostViewedUsers(),
      fetchAppData(),
      fetchHotlineCategories(),
      fetchTopPosts(
        sort: {
              PostSortType.mostViewed: 'most_viewed',
              PostSortType.mostRecent: 'most_recent',
              PostSortType.mostCommented: 'most_commented',
            }[_selectedSortType] ??
            'most_commented',
      ),
    ]);

    // refresh FB pages FutureBuilder
    setState(() {
      _futurePages = fetchFbPages();
    });

    // refresh slider posts
    final items = await fetchTopViewedSliderPosts();
    if (!mounted) return;

    setState(() {
      _sliderPosts = items;
      _currentPage = 0;
    });

    // restart slider
    _startSlider();
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Refresh failed. Please try again.")),
    );
  }
}


 Future<List<SliderPostItem>> fetchTopViewedSliderPosts() async {
  final response =
      await Config.apiGet('/get_today_post?sort=most_viewed', context);

  if (response != null && response.statusCode == 200) {
    final List data = jsonDecode(response.body)['most_update_post'];

    final items = data.take(10).map((e) {
      return SliderPostItem.fromJson(e as Map<String, dynamic>);
    }).where((item) {
      // must have both postId + image
      return item.postId.isNotEmpty && item.imageUrl.isNotEmpty;
    }).toList();

    return items;
  } else {
    throw Exception('Failed to load top viewed posts');
  }
}


  Future<void> loadMostUsedCategory() async {
    try {
      final response = await Config.apiGet('/get_most_used_category', context);
      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        final mostUsedCategories = data['most_used_cat'];
        setState(() {
          _mostUsedCategories = mostUsedCategories;
        });
      } else {
        // ignore: avoid_print
        print("❌ API failed: ${response?.statusCode}");
      }
    } catch (e) {
      // ignore: avoid_print
      print("❌ Exception during fetch: $e");
    }
  }

  void navigateToMostUsedCategoryPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            MostUsedCategoriesPage(categories: _mostUsedCategories),
      ),
    );
  }

  Future<void> fetchMostViewedUsers() async {
    final response = await Config.apiGet('/get_most_viewed_users', context);
    if (response != null && response.statusCode == 200) {
      final List data = jsonDecode(response.body)['user_viewed_users'];
      setState(() {
        _mostViewedUsers = data.map((json) => Album.fromJson(json)).toList();
      });
    } else {
      // ignore: avoid_print
      print('Error loading viewed users');
    }
  }

  Future<void> fetchAppData() async {
    final response = await Config.apiGet('/get_app_by_category', context);
    if (response != null && response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        final List apps = data['app_cat'];
        setState(() {
          _apps = apps.map((item) => AppModel.fromJson(item)).toList();
        });
      } else {
        // ignore: avoid_print
        print("Error from API: ${data['message']}");
      }
    } else {
      // ignore: avoid_print
      print("Failed to fetch app data: ${response?.statusCode}");
    }
  }

  Future<void> fetchAppDataa() async {
    final response = await Config.apiGet('/get_app_by_category', context);
    if (response != null && response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => AppHomePage(
              categories: (data['app_cat'] as List)
                  .map((item) => AppCategory.fromJson(item))
                  .toList(),
            ),
          ),
        );
      } else {
        // ignore: avoid_print
        print("Error from API: ${data['message']}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("API Error: ${data['message']}")),
        );
      }
    } else {
      // ignore: avoid_print
      print("Failed to fetch app data: ${response?.statusCode}");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Network Error: ${response?.statusCode}")),
      );
    }
  }

  Future<void> fetchHotlineCategories() async {
    final response = await Config.apiGet('/get_hotlines_by_category', context);
    if (response != null && response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        final List raw = data['hotline_cat'];
        setState(() {
          _hotlineCategories =
              raw.map((e) => HotlineCategoryModel.fromJson(e)).toList();
        });
      } else {
        // ignore: avoid_print
        print("Error from API: ${data['message']}");
      }
    } else {
      // ignore: avoid_print
      print("Failed to fetch hotline data: ${response?.statusCode}");
    }
  }

  Future<void> fetchHotlineCategoriess() async {
    final response = await Config.apiGet('/get_hotlines_by_category', context);
    if (response != null && response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                Hotlinecategory(categories: data['hotline_cat']),
          ),
        );
      } else {
        // ignore: avoid_print
        print("Error from API: ${data['message']}");
      }
    } else {
      // ignore: avoid_print
      print("Failed to fetch app data: ${response?.statusCode}");
    }
  }

  Future<void> fetchTopPosts({String sort = 'most_commented'}) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? loginUserId = prefs.getString('user_id');
    final response =
        await Config.apiGet('/get_sorted_posts?sort=$sort', context);
    if (response != null && response.statusCode == 200) {
      final List data = jsonDecode(response.body)['posts'];
      setState(() {
        _topCommentedPosts = data.map((e) => PostModel.fromJson(e)).toList();
      });
    } else {
      // ignore: avoid_print
      print("Failed to fetch top posts: ${response?.statusCode}");
    }
  }

  Future<void> mostUpdatePost() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    final sortParam = {
          PostSortType.mostViewed: 'most_viewed',
          PostSortType.mostRecent: 'recent',
          PostSortType.mostCommented: 'most_commented',
        }[_selectedSortType] ??
        'most_commented';

    try {
      final resp =
          await Config.apiGet('/get_today_post?sort_by=$sortParam', context)
              .timeout(const Duration(seconds: 15));
      if (!mounted) return;

      if (resp != null && resp.statusCode == 200) {
        final data = json.decode(resp.body);
        setState(() => _isLoading = false);
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => UpdatePost(
            posts: data['most_update_post'],
            selectedSort: sortParam,
            selectedCategoryId: null,
          ),
        ));
      } else {
        setState(() => _isLoading = false);
        _showErrorDialog("Failed to load posts.");
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showErrorDialog("Network error. Try again.");
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
      ),
    );
  }

  Future<void> fb_page() async {
    final response = await Config.apiGet('/get_fb_page', context);
    if (response != null && response.statusCode == 200) {
      final data = json.decode(response.body);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => FbCategoryPage(pages: data['fb_page']),
        ),
      );
    } else {
      // ignore: avoid_print
      print("Failed to fetch most used category data: ${response?.statusCode}");
    }
  }

  Future<List<FbPage>> fetchFbPages() async {
    final response = await Config.apiGet('/get_fb_page', context);
    if (response != null && response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List pages = data['fb_page'];
      return pages.map((json) => FbPage.fromJson(json)).toList();
    } else {
      throw Exception('Failed to load Facebook pages');
    }
  }

  Future<void> _launchApp(BuildContext context, AppModel app) async {
    Uri? tryParse(String? s) {
      if (s == null || s.isEmpty) return null;
      try {
        return Uri.parse(s);
      } catch (_) {
        return null;
      }
    }

    final deeplinkUri = tryParse(app.deeplink);
    final playStoreUri = tryParse(app.androidLink);
    final appStoreUri = tryParse(app.iosLink);
    final webUri = tryParse(app.web);

    if (deeplinkUri != null && await canLaunchUrl(deeplinkUri)) {
      await launchUrl(deeplinkUri, mode: LaunchMode.externalApplication);
      return;
    }
    if (Theme.of(context).platform == TargetPlatform.android) {
      if (playStoreUri != null && await canLaunchUrl(playStoreUri)) {
        await launchUrl(playStoreUri, mode: LaunchMode.externalApplication);
        return;
      }
    } else {
      if (appStoreUri != null && await canLaunchUrl(appStoreUri)) {
        await launchUrl(appStoreUri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (webUri != null && await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open or install this app.')),
    );
  }

  @override
  void dispose() {
    _sliderTimer?.cancel();
    _adPageController.dispose();
    _descTabController?.dispose();
    super.dispose();
  }

  /* ===================== UI ===================== */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FF),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: SingleChildScrollView(
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAdSlider(),
                const SizedBox(height: 10),
                _sectionShell(
                  child: Column(
                    children: [
                      _buildBanner('Facebook Business', onTap: fb_page),
                      _buildFbPageSection(),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _sectionShell(
                  child: Column(
                    children: [
                      _buildBanner('Trending post', onTap: mostUpdatePost),
                      _buildPostSection(),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _sectionShell(
                  child: Column(
                    children: [
                      _buildBanner('Top Peoples',
                          onTap: navigateToMostUsedCategoryPage, showSeeAll: false),
                      MostViewedUserSlider(users: _mostViewedUsers),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _sectionShell(
                  child: Column(
                    children: [
                      _buildBanner('Top Apps', onTap: fetchAppDataa),
                      _buildAppSection(),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _sectionShell(
                  child: Column(
                    children: [
                      _buildBanner('Hotline numbers',
                          onTap: fetchHotlineCategoriess),
                      _buildHotlineSection(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionShell({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.only(bottom: 10),
      child: child,
    );
  }

Widget _buildAdSlider() {
  if (_sliderPosts.isEmpty) {
    return const SizedBox(
      height: 220,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  return Column(
    children: [
      SizedBox(
        height: 230,
        child: PageView.builder(
          controller: _adPageController,
          itemCount: _sliderPosts.length,
          onPageChanged: (index) => setState(() => _currentPage = index),
          itemBuilder: (context, index) {
            final slide = _sliderPosts[index];

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostDetails(
                      postId: slide.postId,
                      userId: loginUserId ?? '',
                    ),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        slide.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: const Center(
                            child: Icon(Icons.broken_image, size: 42),
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.10),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.35),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: _chip(
                          icon: Icons.trending_up_rounded,
                          text: "Top Post",
                          bg: Colors.black.withValues(alpha: 0.35),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: _chip(
                          icon: Icons.photo_library_outlined,
                          text: "${index + 1}/${_sliderPosts.length}",
                          bg: Colors.black.withValues(alpha: 0.35),
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
      const SizedBox(height: 10),
      AnimatedSmoothIndicator(
        activeIndex: _currentPage,
        count: _sliderPosts.length,
        effect: ExpandingDotsEffect(
          dotHeight: 6,
          dotWidth: 6,
          spacing: 6,
          activeDotColor: const Color(0xFF1A56DB),
          dotColor: Color(0xFFCBD5E1),
          expansionFactor: 3,
        ),
      ),
      const SizedBox(height: 10),
    ],
  );
}



Widget _chip({
  required IconData icon,
  required String text,
  required Color bg,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(30),
      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.white),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}


  /* ---------- Facebook pages (with horizontal indicators) ---------- */
  Widget _buildFbPageSection() {
    return FutureBuilder<List<FbPage>>(
      future: _futurePages,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
              height: 140, child: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.isEmpty) {
          return const SizedBox(
              height: 140,
              child: Center(child: Text("No Facebook pages found.")));
        }

        final pages = snapshot.data!;
        return SizedBox(
          height: 170,
          child: EdgeFadeList(
            overlayWidth: 34,
            chevronColor: Colors.black26,
            builder: (ctrl) => ListView.builder(
              controller: ctrl,
              scrollDirection: Axis.horizontal,
              itemCount: pages.length,
              itemBuilder: (context, index) {
                final page = pages[index];
                return Container(
                  width: 136,
                  margin: const EdgeInsets.only(left: 4, right: 10, bottom: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () async {
                      final webUrl = page.link;
                      final webUri = Uri.parse(webUrl);
                      final fbAppUri = Uri.parse(
                          'fb://facewebmodal/f?href=${Uri.encodeFull(webUrl)}');

                      if (await canLaunchUrl(fbAppUri)) {
                        await launchUrl(fbAppUri,
                            mode: LaunchMode.externalApplication);
                        return;
                      }
                      if (await canLaunchUrl(webUri)) {
                        await launchUrl(webUri,
                            mode: LaunchMode.externalApplication);
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("Could not open Facebook page.")),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          page.photo.isNotEmpty
                              ? CircleAvatar(
                                  backgroundImage: NetworkImage(page.photo),
                                  radius: 28,
                                )
                              : CircleAvatar(
                                  radius: 28,
                                  backgroundColor: const Color(0xFF1877F2),
                                  child: const FaIcon(FontAwesomeIcons.facebookF, color: Colors.white, size: 26),
                                ),
                          const SizedBox(height: 8),
                          Text(
                            page.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A56DB).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              page.cat,
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A56DB),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.remove_red_eye_outlined, size: 11, color: Colors.black38),
                              const SizedBox(width: 3),
                              Text(
                                Config.formatLargeNumber(page.totalViews),
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.black45,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /* ---------- Most Used Category (if you re-enable) ---------- */
  Widget _buildCategorySection() {
    if (_mostUsedCategories.isEmpty) {
      return const SizedBox(
          height: 130, child: Center(child: CircularProgressIndicator()));
    }

    return SizedBox(
      height: 130,
      child: EdgeFadeList(
        overlayWidth: 32,
        builder: (ctrl) => ListView.builder(
          controller: ctrl,
          scrollDirection: Axis.horizontal,
          itemCount:
              _mostUsedCategories.length > 10 ? 10 : _mostUsedCategories.length,
          itemBuilder: (context, index) {
            final category = _mostUsedCategories[index];
            return GestureDetector(
              onTap: () {
                final catId = category['cat_id'].toString();
                final catName = category['cat_name'];
                lastOpenedCatId = catId;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FavoriteScreen(
                      userPhone: '',
                      categoryName: catName,
                      cat_id: catId,
                    ),
                  ),
                );
              },
              child: Container(
                width: 120,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: Colors.white,
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 4))
                  ],
                  border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
                ),
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.category, color: Colors.teal),
                    const SizedBox(height: 6),
                    Text(
                      category['cat_name'] ?? 'Unknown',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${Config.formatLargeNumber(category['cat_used'])} used',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /* ---------- Apps (with horizontal indicators) ---------- */
  Widget _buildAppSection() {
    if (_apps.isEmpty) {
      return const SizedBox(
          height: 100, child: Center(child: CircularProgressIndicator()));
    }

    return SizedBox(
      height: 118,
      child: EdgeFadeList(
        overlayWidth: 34,
        builder: (ctrl) => ListView.builder(
          controller: ctrl,
          scrollDirection: Axis.horizontal,
          itemCount: _apps.length,
          itemBuilder: (context, index) {
            final app = _apps[index];
            return GestureDetector(
              onTap: () => _launchApp(context, app),
              child: Container(
                width: 100,
                margin: const EdgeInsets.only(left: 4, right: 10, bottom: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    app.photo.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              app.photo,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A56DB).withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.apps_rounded,
                                    color: Color(0xFF1A56DB), size: 24),
                              ),
                            ),
                          )
                        : Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A56DB).withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.apps_rounded,
                                color: Color(0xFF1A56DB), size: 24),
                          ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        app.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /* ---------- Hotline (with horizontal indicators) ---------- */
  Widget _buildHotlineSection() {
    if (_hotlineCategories.isEmpty) {
      return const SizedBox(
          height: 100, child: Center(child: CircularProgressIndicator()));
    }

    return SizedBox(
      height: 170,
      child: EdgeFadeList(
        overlayWidth: 34,
        builder: (ctrl) => ListView.builder(
          controller: ctrl,
          scrollDirection: Axis.horizontal,
          itemCount: _hotlineCategories.length,
          itemBuilder: (context, index) {
            final cat = _hotlineCategories[index];
            final displayPhotos =
                cat.photos.length > 3 ? cat.photos.sublist(0, 3) : cat.photos;
            final remainingCount = cat.photos.length - displayPhotos.length;

            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => HotlineDetailsPage(category: cat)),
                );
              },
              child: Container(
                width: 160,
                margin: const EdgeInsets.only(left: 4, right: 10, bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 68,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (int i = 0; i < displayPhotos.length; i++)
                            Positioned(
                              left: i * 30,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2))
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundImage:
                                      NetworkImage(displayPhotos[i]),
                                ),
                              ),
                            ),
                          if (remainingCount > 0)
                            Positioned(
                              left: displayPhotos.length * 30,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                  color: Colors.grey.shade300,
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black12,
                                        blurRadius: 4,
                                        offset: Offset(0, 2))
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.grey.shade300,
                                  child: Text(
                                    '+$remainingCount',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      cat.category,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A56DB).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${cat.count} numbers',
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: Color(0xFF1A56DB),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /* ---------- Posts (unchanged logic, minor polish) ---------- */
Widget _buildPostSection() {
  // Show only posts that have at least one image URL
  final visiblePosts = _topCommentedPosts.where((p) {
    if (p.media.isEmpty) return false;
    final mediaList = p.media
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    return mediaList.isNotEmpty;
  }).toList();

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSortButton(Icons.chat_bubble_outline_rounded, "Comments", PostSortType.mostCommented),
            const SizedBox(width: 8),
            _buildSortButton(Icons.remove_red_eye_outlined, "Views", PostSortType.mostViewed),
            const SizedBox(width: 8),
            _buildSortButton(Icons.access_time_rounded, "Recent", PostSortType.mostRecent),
          ],
        ),
      ),
      const SizedBox(height: 12),

      if (_topCommentedPosts.isEmpty)
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: CircularProgressIndicator(),
          ),
        )
      else if (visiblePosts.isEmpty)
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text("No photo posts to show."),
          ),
        )
      else
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 520;
            final crossAxisCount = isWide ? 2 : 1;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visiblePosts.length,
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                // Professional card needs a bit more height
                childAspectRatio: isWide ? 0.95 : 1.08,
              ),
              itemBuilder: (context, index) {
                final post = visiblePosts[index];
                final mediaList = post.media
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();

                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PostDetails(
                          postId: post.postId.toString(),
                          userId: loginUserId ?? '',
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.black12.withValues(alpha: 0.06),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 16,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ================= Header =================
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                            child: Row(
                              children: [
                                _avatar(post.userPhoto),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        post.userName,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          height: 1.05,
                                          color: Colors.black87,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: _pill(
                                              text: post.catName,
                                              bg: const Color(0xFFEDF4FF),
                                              fg: const Color(0xFF1A56DB),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.black54,
                                    size: 20,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ================ Image ==================
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(
                                      mediaList.first,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        color: Colors.grey[200],
                                        alignment: Alignment.center,
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.grey,
                                          size: 28,
                                        ),
                                      ),
                                    ),

                                    // subtle bottom gradient for depth (professional touch)
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 0,
                                      height: 70,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.transparent,
                                              Colors.black.withValues(alpha: 0.22),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          // ================= Footer =================
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            child: Row(
                              children: [
                                _metricChip(
                                  icon: Icons.remove_red_eye,
                                  value: Config.formatLargeNumber(post.views),
                                ),
                                const SizedBox(width: 8),
                                _metricChip(
                                  icon: Icons.comment,
                                  value: Config.formatLargeNumber(
                                      post.commentCount),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 13, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A56DB),
                                    borderRadius: BorderRadius.circular(9),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF1A56DB).withValues(alpha: 0.30),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'Open',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(Icons.arrow_forward_rounded, size: 12, color: Colors.white),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
    ],
  );
}

// ---------- UI helpers (design-only) ----------

Widget _avatar(String url) {
  return Container(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: Colors.black12.withValues(alpha: 0.08),
        width: 1.2,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 8,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: url.isNotEmpty
        ? CircleAvatar(
            backgroundImage: NetworkImage(url),
            radius: 18,
            backgroundColor: Colors.grey[200],
          )
        : const CircleAvatar(
            backgroundColor: Colors.blue,
            radius: 18,
            child: Icon(Icons.person, color: Colors.white, size: 18),
          ),
  );
}

Widget _pill({
  required String text,
  required Color bg,
  required Color fg,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.black12.withValues(alpha: 0.05)),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: fg.withValues(alpha: 0.80),
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
  );
}

Widget _metricChip({required IconData icon, required String value}) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: Colors.black12.withValues(alpha: 0.05)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.black54),
        const SizedBox(width: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
      ],
    ),
  );
}



  /* ---------- (Optional) Description section kept as-is if you use it ---------- */
  // You can wrap any horizontal list inside EdgeFadeList in that section too.

  Widget _buildBanner(String title,
      {required VoidCallback onTap, bool showSeeAll = true}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF1A56DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A2340),
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (showSeeAll)
            GestureDetector(
              onTap: () => _avoidMultipleClick(onTap),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A56DB).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF1A56DB).withValues(alpha: 0.18),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'See all',
                      style: TextStyle(
                        color: Color(0xFF1A56DB),
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_ios_rounded,
                        size: 10, color: Color(0xFF1A56DB)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF1A56DB)),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1A56DB)),
        ),
      ],
    );
  }
}

/* ===================== Helper: Sort Button (unchanged logic) ===================== */

extension on _HomepageState {
  Widget _buildSortButton(IconData icon, String label, PostSortType type) {
    final isSelected = _selectedSortType == type;

    return GestureDetector(
      onTap: () => _onPostSortChanged(type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1A56DB) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1A56DB)
                : Colors.black.withValues(alpha: 0.10),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1A56DB).withValues(alpha: 0.30),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: isSelected ? Colors.white : Colors.black54),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                color: isSelected ? Colors.white : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* ===================== Reusable EdgeFadeList (scroll indicator) ===================== */

class EdgeFadeList extends StatefulWidget {
  final Widget Function(ScrollController controller) builder;
  final Axis axis;
  final double overlayWidth;
  final bool showChevrons;
  final Color? backgroundColor;
  final Color chevronColor;

  const EdgeFadeList({
    Key? key,
    required this.builder,
    this.axis = Axis.horizontal,
    this.overlayWidth = 30,
    this.showChevrons = true,
    this.backgroundColor,
    this.chevronColor = Colors.black26,
  }) : super(key: key);

  @override
  State<EdgeFadeList> createState() => _EdgeFadeListState();
}

class _EdgeFadeListState extends State<EdgeFadeList> {
  final ScrollController _controller = ScrollController();
  bool _atStart = true;
  bool _atEnd = false;
  bool _hasScroll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _recomputeEdges());
    _controller.addListener(_recomputeEdges);
  }

  void _recomputeEdges() {
    if (!mounted || !_controller.hasClients) return;
    final pos = _controller.position;
    final atStart = pos.pixels <= 0.5;
    final atEnd = pos.pixels >= (pos.maxScrollExtent - 0.5);
    final hasScroll = pos.maxScrollExtent > 0;

    if (atStart != _atStart || atEnd != _atEnd || hasScroll != _hasScroll) {
      setState(() {
        _atStart = atStart;
        _atEnd = atEnd;
        _hasScroll = hasScroll;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_recomputeEdges);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg =
        widget.backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;

    Widget fadeEdge(bool leftOrTop) {
      return IgnorePointer(
        ignoring: true,
        child: Align(
          alignment: widget.axis == Axis.horizontal
              ? (leftOrTop ? Alignment.centerLeft : Alignment.centerRight)
              : (leftOrTop ? Alignment.topCenter : Alignment.bottomCenter),
          child: Container(
            width: widget.axis == Axis.horizontal ? widget.overlayWidth : null,
            height: widget.axis == Axis.vertical ? widget.overlayWidth : null,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: leftOrTop
                    ? (widget.axis == Axis.horizontal
                        ? Alignment.centerLeft
                        : Alignment.topCenter)
                    : (widget.axis == Axis.horizontal
                        ? Alignment.centerRight
                        : Alignment.bottomCenter),
                end: leftOrTop
                    ? (widget.axis == Axis.horizontal
                        ? Alignment.centerRight
                        : Alignment.bottomCenter)
                    : (widget.axis == Axis.horizontal
                        ? Alignment.centerLeft
                        : Alignment.topCenter),
                colors: [bg.withValues(alpha: 0.92), bg.withValues(alpha: 0.0)],
              ),
            ),
            child: widget.showChevrons
                ? Icon(
                    widget.axis == Axis.horizontal
                        ? (leftOrTop
                            ? Icons.chevron_left_rounded
                            : Icons.chevron_right_rounded)
                        : (leftOrTop
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded),
                    size: 22,
                    color: widget.chevronColor,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      );
    }

    return Stack(
      children: [
        widget.builder(_controller),
        if (_hasScroll && !_atStart) fadeEdge(true),
        if (_hasScroll && !_atEnd) fadeEdge(false),
      ],
    );
  }
}