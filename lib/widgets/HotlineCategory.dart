import 'package:aaram_bd/widgets/app_category_details.dart';
import 'package:flutter/material.dart';
import 'package:aaram_bd/screens/favorite_screen.dart';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/widgets/app_toast.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:flutter/services.dart'; // for Clipboard
import 'hotline_category_details.dart';

class Hotlinecategory extends StatefulWidget {
  final List<dynamic> categories;

  const Hotlinecategory({Key? key, required this.categories}) : super(key: key);

  @override
  State<Hotlinecategory> createState() => _HotlinecategoryState();
}

class _HotlinecategoryState extends State<Hotlinecategory> {
  final ScrollController verticalController = ScrollController();
  final ScrollController horizontalController = ScrollController();

  @override
  void dispose() {
    verticalController.dispose();
    horizontalController.dispose();
    super.dispose();
  }

  // --- Call helper: works on Android & iOS, with simulator-safe behavior ---
  Future<void> _callNumber(BuildContext context, String phoneRaw) async {
    final phone = phoneRaw.replaceAll(RegExp(r'[^\d\+]'), ''); // keep digits and '+'
    if (phone.isEmpty) {
      showAppToast(context, 'No valid phone number.',
          icon: Icons.error_outline_rounded);
      return;
    }

    final telUri = Uri(scheme: 'tel', path: phone);
    try {
      // Try 'tel:' first
      if (await canLaunchUrl(telUri)) {
        final ok = await launchUrl(telUri, mode: LaunchMode.externalApplication);
        if (ok) return;
      }

      // iOS fallback: 'telprompt:' sometimes works better on some versions
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        final telPromptUri = Uri(scheme: 'telprompt', path: phone);
        if (await canLaunchUrl(telPromptUri)) {
          final ok = await launchUrl(telPromptUri, mode: LaunchMode.externalApplication);
          if (ok) return;
        }

        // Likely the iOS Simulator (it can't open the Phone app)
        await Clipboard.setData(ClipboardData(text: phone));
        showAppToast(
            context,
            'Cannot open dialer in iOS Simulator. Phone number copied to clipboard.',
            icon: Icons.error_outline_rounded);
        return;
      }

      // Android fallback failed
      showAppToast(context, 'Cannot open dialer on this device.',
          icon: Icons.error_outline_rounded);
    } catch (e) {
      showAppToast(context, 'Dialer error: $e',
          icon: Icons.error_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final validCategories = widget.categories.where((category) {
      final photos = (category['photos'] as String?)
              ?.split(',')
              .where((url) => url.trim().isNotEmpty)
              .toList() ??
          [];
      final phones = (category['phones'] as String?)
              ?.split(',')
              .where((p) => p.trim().isNotEmpty)
              .toList() ??
          [];
      final names = (category['names'] as String?)
              ?.split(',')
              .where((p) => p.trim().isNotEmpty)
              .toList() ??
          [];
      return photos.isNotEmpty && phones.isNotEmpty && names.isNotEmpty;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text('Best Customer Service'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: RawScrollbar(
        controller: verticalController,
        thumbVisibility: true,
        thickness: 4,
        radius: const Radius.circular(8),
        thumbColor: Colors.black12,
        trackVisibility: false,
        child: ListView.builder(
          controller: verticalController,
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
          itemCount: validCategories.length,
          itemBuilder: (context, index) {
            final category = validCategories[index];

            final List<String> photos = (category['photos'] as String)
                .split(',')
                .where((url) => url.trim().isNotEmpty)
                .toList();
            final List<String> phones = (category['phones'] as String)
                .split(',')
                .where((p) => p.trim().isNotEmpty)
                .toList();
            final List<String> names = (category['names'] as String)
                .split(',')
                .where((p) => p.trim().isNotEmpty)
                .toList();

            final String categoryName =
                (category['category'] ?? 'Unknown').toString();

            return Container(
              margin: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(18),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
                border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF86A8E7), Color(0xFF91EAE4)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: const Icon(Icons.support_agent,
                              color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            categoryName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Horizontal scroller
                  SizedBox(
                    height: 230,
                    child: Stack(
                      children: [
                        // scrollable list
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: ListView.builder(
                            controller: horizontalController,
                            physics: const BouncingScrollPhysics(),
                            scrollDirection: Axis.horizontal,
                            itemCount: photos.length,
                            itemBuilder: (context, i) {
                              final photoUrl = photos[i];
                              final phone = i < phones.length ? phones[i] : '';
                              final name = i < names.length ? names[i] : '';

                              return _HotlineCard(
                                photoUrl: photoUrl,
                                name: name,
                                phone: phone,
                                categoryName: categoryName,
                                onTapCall: () => _callNumber(context, phone),
                              );
                            },
                          ),
                        ),

                        // subtle scroll hints (left/right)
                        const _ScrollHint(isLeft: true),
                        const _ScrollHint(isLeft: false),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// One hotline item (photo + name + phone + call)
class _HotlineCard extends StatelessWidget {
  final String photoUrl;
  final String name;
  final String phone;
  final String categoryName;
  final VoidCallback onTapCall;

  const _HotlineCard({
    Key? key,
    required this.photoUrl,
    required this.name,
    required this.phone,
    required this.categoryName,
    required this.onTapCall,
  }) : super(key: key);

  void _showDetailsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.95,
      ),
      builder: (context) {
        final mq = MediaQuery.of(context);
        final keyboard = mq.viewInsets.bottom; // when keyboard shows
        final safe = mq.padding.bottom; // gesture/nav area
        final bottomSpace = (keyboard > 0 ? keyboard : safe) + 12;

        return SafeArea(
          top: false,
          left: false,
          right: false,
          bottom: true,
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomSpace),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // drag handle
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Big avatar
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF7F7FD5),
                          Color(0xFF86A8E7),
                          Color(0xFF91EAE4)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 56,
                      backgroundColor: Colors.white,
                      child: ClipOval(
                        child: Image.network(
                          photoUrl,
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stack) => Container(
                            width: 110,
                            height: 110,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image_not_supported,
                                color: Colors.grey, size: 36),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Name
                  Text(
                    name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Category chip
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                      border:
                          Border.all(color: Colors.black12.withValues(alpha: 0.08)),
                    ),
                    child: Text(
                      categoryName,
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Phone row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.black12.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone, color: Colors.blueAccent),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            phone,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Call',
                          onPressed: onTapCall,
                          icon: const Icon(Icons.call, color: Colors.green),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onTapCall,
                          icon: const Icon(Icons.call),
                          label: const Text('Call Now'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                                color: Colors.black12.withValues(alpha: 0.2)),
                          ),
                          child: const Text('Close'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          // TAP ON CARD → SHOW DETAILS SHEET
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetailsSheet(context),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Avatar with gradient ring
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF7F7FD5),
                        Color(0xFF86A8E7),
                        Color(0xFF91EAE4)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: Colors.white,
                    child: ClipOval(
                      child: Image.network(
                        photoUrl,
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stack) => Container(
                          width: 84,
                          height: 84,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.image_not_supported,
                              color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ),

                // Name
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                ),

                // Phone (centered)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.phone,
                        size: 16, color: Colors.blueAccent),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),

                // Call button (ONLY THIS opens dialer)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Container(
                    width: double.infinity,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF86A8E7), Color(0xFF91EAE4)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: onTapCall,
                      child: const Center(
                        child: Text(
                          'Call',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Faint gradient edge + chevron to indicate horizontal scroll
class _ScrollHint extends StatelessWidget {
  final bool isLeft;
  const _ScrollHint({Key? key, required this.isLeft}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: Align(
        alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
        child: Container(
          width: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
              end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
              colors: [
                Colors.white.withValues(alpha: 0.85),
                Colors.white.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: Icon(
            isLeft ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            size: 26,
            color: Colors.black26,
          ),
        ),
      ),
    );
  }
}
