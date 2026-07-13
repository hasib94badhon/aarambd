import 'dart:convert';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/widgets/contact_info_card.dart';
import 'package:flutter/material.dart';

const Color _brand = Color(0xFF1A56DB);

class TermsPolicies extends StatefulWidget {
  @override
  _TermsPoliciesState createState() => _TermsPoliciesState();
}

class _TermsPoliciesState extends State<TermsPolicies> {
  final String _url = '/get_terms_policy';
  late Future<List<String>> _paragraphsFuture;

  @override
  void initState() {
    super.initState();
    _paragraphsFuture = _fetchAndParseTerms();
  }

  Future<List<String>> _fetchAndParseTerms() async {
    try {
      final resp = await Config.apiGet(_url, context);
      String raw = 'Failed to load terms and policies.';
      if (resp != null && resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        raw = (data['success'] == true && data['terms_policy'] != null)
            ? data['terms_policy'] as String
            : raw;
      }

      raw = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

      return raw
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
    } catch (_) {
      return ['Something went wrong. Please try again.'];
    }
  }

  @override
  Widget build(BuildContext context) {
    const titleStyle = TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: Color(0xFF111827),
    );
    const dateStyle = TextStyle(
      fontSize: 13,
      fontStyle: FontStyle.italic,
      fontWeight: FontWeight.w600,
      color: Color(0xFF9CA3AF),
    );
    const headingStyle = TextStyle(
      fontSize: 15.5,
      fontWeight: FontWeight.w800,
      color: _brand,
    );
    const bodyStyle = TextStyle(
      fontSize: 13.5,
      height: 1.65,
      fontWeight: FontWeight.w500,
      color: Color(0xFF374151),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FF),
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          _buildHeader(context),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, 16 + MediaQuery.of(context).padding.bottom),
            sliver: SliverToBoxAdapter(
              child: FutureBuilder<List<String>>(
                future: _paragraphsFuture,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                          child: CircularProgressIndicator(color: _brand)),
                    );
                  }
                  final paras = snap.data ?? const [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ContactInfoCard(compact: true),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border:
                              Border.all(color: Colors.black.withValues(alpha: 0.06)),
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
                            for (int i = 0; i < paras.length; i++) ...[
                              if (i == 0)
                                Text(paras[i], style: titleStyle)
                              else if (i == 1)
                                Text(paras[i], style: dateStyle)
                              else if (RegExp(r'^\d+\.\s').hasMatch(paras[i]))
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(paras[i], style: headingStyle),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.only(top: 7),
                                        child: Container(
                                          width: 4,
                                          height: 4,
                                          decoration: const BoxDecoration(
                                            color: _brand,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          paras[i],
                                          style: bodyStyle,
                                          textAlign: TextAlign.justify,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (i < paras.length - 1) const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
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
            16, MediaQuery.of(context).padding.top + 14, 16, 22),
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
        child: Row(
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
            const SizedBox(width: 10),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.gavel_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Terms & Policies',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Terms of service and privacy',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
