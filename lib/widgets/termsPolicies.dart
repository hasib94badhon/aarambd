import 'dart:convert';
import 'package:aaram_bd/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

      // Normalize all CR/LF to LF
      raw = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

      // Split on each newline into its own "paragraph" and trim empties
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
    final titleStyle = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.bold,
      color: Colors.black87,
    );
    final dateStyle = TextStyle(
      fontSize: 16,
      fontStyle: FontStyle.italic,
      color: Colors.black54,
    );
    final headingStyle = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: Colors.teal[700],
    );
    final bodyStyle = TextStyle(
      fontSize: 15,
      height: 1.6,
      color: Colors.grey[900],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Terms & Policies'),
        centerTitle: true,
        elevation: 2,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.white, Colors.white],
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<String>>(
        future: _paragraphsFuture,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return Center(child: CircularProgressIndicator());
          }
          final paras = snap.data!;

          return Container(
            color: Colors.white,
            child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                separatorBuilder: (_, __) => SizedBox(height: 12),
                itemCount: paras.length,
                itemBuilder: (ctx, i) {
                  final line = paras[i];

                  // Title = first line
                  if (i == 0) {
                    return Text(line, style: titleStyle);
                  }

                  // Effective Date = second line
                  if (i == 1) {
                    return Text(line, style: dateStyle);
                  }

                  // Numbered headings like "1. Introduction"
                  if (RegExp(r'^\d+\.\s').hasMatch(line)) {
                    return Text(line, style: headingStyle);
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '•',
                        style: bodyStyle.copyWith(fontSize: 19),
                        textAlign: TextAlign.start,
                      ),

                      const SizedBox(width: 8),
                      // Expanded so long lines wrap neatly
                      Expanded(
                        child: Text(
                          line,
                          style: bodyStyle,
                          textAlign: TextAlign.justify,
                        ),
                      ),
                    ],
                  );
                }),
          );
        },
      ),
    );
  }
}
