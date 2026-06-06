import 'dart:convert';
import 'dart:io' show Platform;
import 'package:aaram_bd/config.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

final String host = Config.host;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bangladesh Apps',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.white,
      ),
      home: AppHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppHomePage extends StatefulWidget {
  final List<AppCategory>? categories;
  AppHomePage({super.key, this.categories});

  @override
  State<AppHomePage> createState() => _AppHomePageState();
}

class _AppHomePageState extends State<AppHomePage> {
  List<AppCategory> categories = [];
  bool isLoading = true;
  String errorMessage = '';

  final ScrollController verticalController = ScrollController();
  final ScrollController horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.categories != null) {
      categories = widget.categories!;
      isLoading = false;
    } else {
      fetchAppData();
    }
  }

  @override
  void dispose() {
    verticalController.dispose();
    horizontalController.dispose();
    super.dispose();
  }

  Future<void> fetchAppData() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      final response = await http.get(Uri.parse('$host/get_app_by_category'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            categories = (data['app_cat'] as List)
                .map((item) => AppCategory.fromJson(item))
                .toList();
            isLoading = false;
          });
        } else {
          setState(() {
            errorMessage = data['message'] ?? 'Unknown error occurred';
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = 'Failed to load data: ${response.statusCode}';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Network error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Apps mostly used'),
        centerTitle: true,
        elevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: Scrollbar(
        controller: verticalController,
        thumbVisibility: true,
        thickness: 5,
        radius: const Radius.circular(8),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(errorMessage),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: fetchAppData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : AppCategoryScreen(
                    categories: categories,
                    verticalController: verticalController,
                    horizontalController: horizontalController,
                  ),
      ),
    );
  }
}

class AppCategory {
  final String category;
  final String appId;
  final String name;
  final String photo;
  final String address;
  final String androidLink;
  final String iosLink;
  final String web;
  final String deeplink;

  AppCategory({
    required this.category,
    required this.appId,
    required this.name,
    required this.photo,
    required this.address,
    required this.androidLink,
    required this.iosLink,
    required this.web,
    required this.deeplink,
  });

  /// Sanitize a URL coming from backend (spaces, accidental double slashes, etc.)
  static String _cleanUrl(String? raw) {
    if (raw == null) return '';
    var s = raw.trim();
    if (s.isEmpty) return '';

    // If it looks like a full URL, normalize it.
    // 1) Collapse "cat logo//" → "cat%20logo/"
    s = s.replaceAll(' ', '%20');
    // Avoid breaking schemes ("http://" must keep two slashes).
    // Only collapse triple slashes after "http(s)://"
    s = s.replaceAllMapped(RegExp(r'^(https?:\/\/)(\/)+'), (m) => m.group(1)!);
    // Collapse any '///' → '//', then any '//' → '/' except after scheme:
    s = s.replaceAll(RegExp(r'(?<!:)\/\/\/+'), '//');
    s = s.replaceAll(RegExp(r'(?<!:)\/\/'), '/');
    if (s.startsWith('http:/')) s = 'http://' + s.substring(6);
    if (s.startsWith('https:/')) s = 'https://' + s.substring(7);

    return s;
  }

  factory AppCategory.fromJson(Map<String, dynamic> json) {
    return AppCategory(
      category: json['category'] ?? 'Uncategorized',
      appId: json['app_id']?.toString() ?? '',
      name: json['name'] ?? 'Unknown App',
      photo: json['photo'] ?? '',
      address: json['address'] ?? '',
      androidLink: _cleanUrl(json['android_link']),
      iosLink: _cleanUrl(json['ios_link']),
      web: _cleanUrl(json['web']),
      deeplink: (json['deeplink'] ?? '').toString().trim(),
    );
  }
}

class AppCategoryScreen extends StatefulWidget {
  final List<AppCategory> categories;
  final ScrollController verticalController;
  final ScrollController horizontalController;

  const AppCategoryScreen({
    Key? key,
    required this.categories,
    required this.verticalController,
    required this.horizontalController,
  }) : super(key: key);

  @override
  State<AppCategoryScreen> createState() => _AppCategoryScreenState();
}

class _AppCategoryScreenState extends State<AppCategoryScreen> {
  final List<Color> cardColors = [
    Colors.blue[50]!,
    Colors.blue[50]!,
    Colors.blue[50]!, 
    Colors.blue[50]!,
    Colors.blue[50]!,
  ];

  Widget _horizontalScrollHint() {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 4),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.keyboard_arrow_left, size: 18, color: Colors.black38),
            SizedBox(width: 4),
            Text(
              'Swipe',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_right, size: 18, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<AppCategory>> groupedApps = {};
    for (var app in widget.categories) {
      groupedApps.putIfAbsent(app.category, () => []);
      groupedApps[app.category]!.add(app);
    }

    return ListView.builder(
      controller: widget.verticalController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: groupedApps.length,
      itemBuilder: (context, index) {
        final bgColor = cardColors[index % cardColors.length];
        final category = groupedApps.keys.elementAt(index);
        final apps = groupedApps[category]!;

        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
              border: Border.all(color: const Color(0x0F000000)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    category,
                    style: const TextStyle(
                      fontSize: 18.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                SizedBox(
                  height: 150,
                  child: Scrollbar(
                    controller: widget.horizontalController,
                    thumbVisibility: true,
                    thickness: 4.5,
                    radius: const Radius.circular(8),
                    child: ListView.builder(
                      controller: widget.horizontalController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      itemCount: apps.length,
                      itemBuilder: (context, appIndex) {
                        final app = apps[appIndex];
                        return AppCard(app: app);
                      },
                    ),
                  ),
                ),
                _horizontalScrollHint(),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AppCard extends StatefulWidget {
  final AppCategory app;

  const AppCard({super.key, required this.app});

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  Uri? _tryUri(String? url) {
    if (url == null) return null;
    final s = url.trim();
    if (s.isEmpty) return null;
    try {
      return Uri.parse(s);
    } catch (_) {
      return null;
    }
  }

  Future<void> _launchApp(BuildContext context) async {
    try {
      final deeplinkUri = _tryUri(widget.app.deeplink);
      final androidUri = _tryUri(widget.app.androidLink);
      final iosUri = _tryUri(widget.app.iosLink);
      final webUri = _tryUri(widget.app.web);

      Future<bool> _open(Uri? uri) async {
        if (uri == null) return false;
        if (await canLaunchUrl(uri)) {
          final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
          return ok;
        }
        return false;
      }

      // 1) Try deep link (opens the app directly if installed)
      if (await _open(deeplinkUri)) return;

      // 2) Platform specific store link
      if (Platform.isIOS) {
        if (await _open(iosUri)) return;
      } else if (Platform.isAndroid) {
        if (await _open(androidUri)) return;
      }

      // 3) Web fallback
      if (await _open(webUri)) return;

      throw Exception('No launchable URL found');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open app: ${e.toString()}')),
      );
    }
  }

  Future<int?> _incrementVisitCount(int appId) async {
    final url = Uri.parse('${Config.host}/app_page_visit');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'app_id': appId}),
    );
    if (res.statusCode == 200) {
      final jsonBody = jsonDecode(res.body);
      return jsonBody['visit_count'] as int?;
    }
    debugPrint('Failed to increment visit: ${res.statusCode} - ${res.body}');
    return null;
  }

  Future<void> _handleVisit(Map<String, dynamic> app) async {
    final appId = int.tryParse(app['app_id'].toString());
    if (appId == null) return;

    setState(() {
      app['visit_count'] = (app['visit_count'] ?? 0) + 1;
    });

    final newCount = await _incrementVisitCount(appId);
    if (newCount != null) {
      setState(() => app['visit_count'] = newCount);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _handleVisit({
        'app_id': widget.app.appId,
        'visit_count': 0,
      }).then((_) => _launchApp(context)),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 136,
        height: 140,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
          border: Border.all(color: const Color(0x0F000000)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.app.photo,
                  fit: BoxFit.cover,
                  width: 84,
                  height: 84,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                widget.app.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
