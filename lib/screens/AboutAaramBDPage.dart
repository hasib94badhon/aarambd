import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/widgets/contact_info_card.dart';

const Color _brand = Color(0xFF1A56DB);

class AboutAaramBDPage extends StatefulWidget {
  @override
  _AboutAaramBDPageState createState() => _AboutAaramBDPageState();
}

class _AboutAaramBDPageState extends State<AboutAaramBDPage> {
  Map<String, dynamic>? aboutData;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    fetchAboutInfo();
  }

  Future<void> fetchAboutInfo() async {
    setState(() => _failed = false);
    final response = await Config.apiGet('/get_about_info', context);
    if (response != null && response.statusCode == 200) {
      setState(() => aboutData = json.decode(response.body));
    } else {
      debugPrint("Failed to load about info: ${response?.statusCode}");
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FF),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildHeader(context),
          if (_failed)
            SliverFillRemaining(child: _buildError())
          else if (aboutData == null)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _brand)),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                  16, 16, 16, 20 + MediaQuery.of(context).padding.bottom),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const ContactInfoCard(),
                  _Section(
                    title: "Know AaramBD",
                    icon: Icons.info_outline_rounded,
                    color: _brand,
                    content: aboutData!['about'],
                  ),
                  _Section(
                    title: "Aim & Goals",
                    icon: Icons.flag_rounded,
                    color: const Color(0xFF16A34A),
                    content: aboutData!['goals'],
                  ),
                  _Section(
                    title: "Credits Go To",
                    icon: Icons.groups_rounded,
                    color: const Color(0xFF7C3AED),
                    content: aboutData!['founders'],
                  ),
                  _Section(
                    title: "Our Sponsors",
                    icon: Icons.star_rounded,
                    color: const Color(0xFFD97706),
                    content: aboutData!['sponsors'],
                  ),
                  _Section(
                    title: "Our Office",
                    icon: Icons.location_city_rounded,
                    color: const Color(0xFF0891B2),
                    content: aboutData!['office_address'],
                  ),
                  _Section(
                    title: "Quote We Follow",
                    icon: Icons.format_quote_rounded,
                    color: const Color(0xFFDB2777),
                    content: aboutData!['quote'],
                    asQuote: true,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "© ${DateTime.now().year} AaramBD. All rights reserved.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withValues(alpha: 0.38),
                    ),
                  ),
                ]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.fromLTRB(
            16, MediaQuery.of(context).padding.top + 14, 16, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1040B0), _brand],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => Navigator.pop(context),
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white, size: 18),
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'About AaramBD',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35), width: 1.4),
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'In search for everything you need',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                color: Color(0xFFEDF4FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded, size: 40, color: _brand),
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load this page',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 16,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Check your internet connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: fetchAboutInfo,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A section card: colored icon bubble + title, then body text or a bullet
/// list (multi-line content is split into bullets), or an italic quote block.
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String content;
  final bool asQuote;

  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.content,
    this.asQuote = false,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> lines = (content).toString()
        .split(RegExp(r'\r\n|\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (lines.isEmpty) return const SizedBox.shrink();
    final bool isMultiLine = lines.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (asQuote)
            _Quote(text: content.trim(), color: color)
          else if (isMultiLine)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: lines.map((line) => _BulletLine(text: line, color: color)).toList(),
            )
          else
            Text(
              content.trim(),
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.55,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;
  final Color color;
  const _BulletLine({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.55,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Quote extends StatelessWidget {
  final String text;
  final Color color;
  const _Quote({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13.5,
                fontStyle: FontStyle.italic,
                height: 1.6,
                color: color.withValues(alpha: 0.95),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
