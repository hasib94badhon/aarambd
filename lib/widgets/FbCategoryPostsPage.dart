import 'dart:convert';
import 'package:aaram_bd/config.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;

class FbCategoryPostsPage extends StatefulWidget {
  final String category;
  final List<dynamic> pages;

  const FbCategoryPostsPage({
    required this.category,
    required this.pages,
    Key? key,
  }) : super(key: key);

  @override
  State<FbCategoryPostsPage> createState() => _FbCategoryPostsPageState();
}

class _FbCategoryPostsPageState extends State<FbCategoryPostsPage> {
  late List<Map<String, dynamic>> _pages; // local mutable copy

  // A simple, consistent palette
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _cardBorder = Color(0x1A000000); // faint border
  static const Color _cardShadow = Color(0x12000000); // faint drop shadow
  static const Color _accent = Color(0xFF2563EB); // blue-600

  @override
  void initState() {
    super.initState();
    // ensure we have a modifiable list of maps
    _pages = widget.pages
        .map((e) => Map<String, dynamic>.from(e as Map<String, dynamic>))
        .toList();
  }

  Future<int?> _incrementVisitCount(int pageId) async {
    final url = Uri.parse('${Config.host}/fb_page_visit');
    try {
      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'page_id': pageId}),
      );
      if (res.statusCode == 200) {
        final jsonBody = jsonDecode(res.body);
        return jsonBody['visit_count'] as int?;
      }
      debugPrint('Failed to increment visit: ${res.statusCode} - ${res.body}');
    } catch (e) {
      debugPrint('Error incrementing visit: $e');
    }
    return null;
  }

  Future<void> _handleVisit(Map<String, dynamic> post) async {
    final pid = int.tryParse(post['page_id'].toString());
    if (pid == null) return;

    // Optimistic UI
    setState(() {
      post['visit_count'] = (post['visit_count'] ?? 0) + 1;
    });

    final newCount = await _incrementVisitCount(pid);
    if (newCount != null) {
      setState(() => post['visit_count'] = newCount);
    }
  }

  /// Open FB app if available, otherwise browser.
  Future<void> _openFacebook(Map<String, dynamic> post) async {
    final webUrl = (post['link'] ?? '').toString().trim();
    if (webUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No Facebook link found.")),
      );
      return;
    }
    final encoded = Uri.encodeComponent(webUrl);
    final fbAppUri = Uri.parse('fb://facewebmodal/f?href=$encoded');
    final webUri = Uri.parse(webUrl);

    if (await canLaunchUrl(fbAppUri)) {
      await launchUrl(fbAppUri, mode: LaunchMode.externalApplication);
      return;
    }
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Could not open Facebook page.")),
    );
  }

  Future<void> _callNumber(Map<String, dynamic> post) async {
    final phone = post['phone']?.toString().trim() ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No phone number found.")),
      );
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not launch dialer.")),
      );
    }
  }

  List<String> _extractPhotos(Map<String, dynamic> post) {
    final raw = (post['photo'] as String?) ?? '';
    if (raw.trim().isEmpty) return const <String>[];
    return raw.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          widget.category,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
        itemCount: _pages.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final post = _pages[index];
          final name = (post['name'] ?? '').toString().trim();
          final visitCount = post['visit_count'] ?? 0;
          final photos = _extractPhotos(post);

          return Container(
            decoration: BoxDecoration(
              color: Colors.blue[100],
              border: Border.all(color: _cardBorder),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: _cardShadow,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Action buttons (FB + Call)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _RoundActionButton(
                      tooltip: 'Open Facebook',
                      icon: Icons.facebook_rounded,
                      bg: _accent.withValues(alpha: 0.12),
                      fg: _accent,
                      onTap: () async {
                        await _handleVisit(post); // increase only on button tap
                        await _openFacebook(post);
                      },
                    ),
                    const SizedBox(height: 10),
                    _RoundActionButton(
                      tooltip: 'Call',
                      icon: Icons.phone,
                      bg: Colors.green.withValues(alpha: 0.12),
                      fg: Colors.green.shade700,
                      onTap: () async {
                        await _handleVisit(post); // increase only on button tap
                        await _callNumber(post);
                      },
                    ),
                  ],
                ),
                const SizedBox(width: 12),

                // Right: Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + visits pill
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              name.isEmpty ? 'Facebook Page' : name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                                height: 1.15,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _VisitsPill(count: visitCount),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Photo strip
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F5FB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        height: 120,
                        child: photos.isEmpty
                            ? _noPhotoPlaceholder()
                            : ListView.separated(
                                scrollDirection: Axis.horizontal,
                                itemBuilder: (_, i) {
                                  final url = 'https://aarambd.com/upload/${photos[i]}';
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      url,
                                      width: 140,
                                      height: 120,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Container(
                                        width: 140,
                                        height: 120,
                                        color: Colors.grey[200],
                                        alignment: Alignment.center,
                                        child: const Icon(Icons.broken_image, color: Colors.grey),
                                      ),
                                    ),
                                  );
                                },
                                separatorBuilder: (_, __) => const SizedBox(width: 8),
                                itemCount: photos.length.clamp(0, 12), // keep it light
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  const _RoundActionButton({
    required this.icon,
    required this.tooltip,
    required this.bg,
    required this.fg,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: fg, size: 24),
          ),
        ),
      ),
    );
  }
}

class _VisitsPill extends StatelessWidget {
  final int count;
  const _VisitsPill({required this.count, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color accent = _FbCategoryPostsPageState._accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.visibility_rounded, size: 16, color: accent),
          const SizedBox(width: 5),
          Text(
            '${Config.formatLargeNumber(count)} visits',
            style: const TextStyle(
              color: Color(0xFF1F2937), // gray-800
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _noPhotoPlaceholder() {
  return Container(
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.image_not_supported_outlined, size: 28, color: Colors.grey),
        SizedBox(height: 6),
        Text(
          'No photos',
          style: TextStyle(color: Colors.grey, fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
