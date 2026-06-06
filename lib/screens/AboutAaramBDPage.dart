import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:aaram_bd/config.dart';

class AboutAaramBDPage extends StatefulWidget {
  @override
  _AboutAaramBDPageState createState() => _AboutAaramBDPageState();
}

class _AboutAaramBDPageState extends State<AboutAaramBDPage> {
  Map<String, dynamic>? aboutData;

  @override
  void initState() {
    super.initState();
    fetchAboutInfo();
  }

  Future<void> fetchAboutInfo() async {
    final response = await Config.apiGet('/get_about_info', context);
    if (response != null && response.statusCode == 200) {
      setState(() => aboutData = json.decode(response.body));
    } else {
      debugPrint("Failed to load about info: ${response?.statusCode}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text("AaramBD"),
        centerTitle: true,
      ),
      body: aboutData == null
          ? const _Loading()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                _Section(
                  title: "Know AaramBD",
                  icon: Icons.info_outline,
                  content: aboutData!['about'],
                ),
                _Section(
                  title: "Credits goes to",
                  icon: Icons.person_outline,
                  content: aboutData!['founders'],
                ),
                _Section(
                  title: "Our Sponsors",
                  icon: Icons.star_outline,
                  content: aboutData!['sponsors'],
                ),
                _Section(
                  title: "Platform",
                  icon: Icons.location_city,
                  content: aboutData!['office_address'],
                ),
                _Section(
                  title: "Contact AaramBD",
                  icon: Icons.contact_phone,
                  content: aboutData!['contact'],
                ),
                _Section(
                  title: "Aim & Goals",
                  icon: Icons.flag_outlined,
                  content: aboutData!['goals'],
                ),
                _Section(
                  title: "Quote We Follow",
                  icon: Icons.format_quote_outlined,
                  content: aboutData!['quote'],
                  asQuote: true,
                ),
                const SizedBox(height: 8),
                Divider(color: theme.dividerColor),
                const SizedBox(height: 10),
                Text(
                  "© 2025 AaramBD. All rights reserved.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        height: 40,
        width: 40,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
    );
  }
}

/// A simple, standard section:
/// - Title row with icon
/// - Subtle divider
/// - Body text or bullet list
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final String content;
  final bool asQuote;

  const _Section({
    required this.title,
    required this.icon,
    required this.content,
    this.asQuote = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final List<String> lines = (content ?? "")
        .toString()
        .split(RegExp(r'\r\n|\n'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final bool isMultiLine = lines.length > 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        // border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Icon(icon, size: 22, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            Divider(height: 1, color: theme.dividerColor),
            const SizedBox(height: 10),

            // Body
            if (asQuote)
              _Quote(text: content.trim())
            else if (isMultiLine)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: lines
                    .map((line) => _BulletLine(text: line))
                    .toList(),
              )
            else
              Text(
                content.trim(),
                textAlign: TextAlign.start,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
          ],
        ),
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  final String text;
  const _BulletLine({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Simple standard bullet
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text("•", style: TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.start,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _Quote extends StatelessWidget {
  final String text;
  const _Quote({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.format_quote, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
