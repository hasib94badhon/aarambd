import 'package:flutter/material.dart';
import 'package:aaram_bd/widgets/app_toast.dart';

class PrivacyRulesPage extends StatefulWidget {
  @override
  _PrivacyRulesPageState createState() => _PrivacyRulesPageState();
}

class _PrivacyRulesPageState extends State<PrivacyRulesPage> {
  // Default all true (allowed)
  List<bool> _privacyChecks = List.generate(5, (index) => true);

  final List<String> _privacyTerms = [
    "Your basic information (name, category, contact number) will be visible in the marketplace.",
    "AaramBD uses your data to improve services and user experience.",
    "AaramBD is not responsible for any damages or casualties caused by third-party users using your public data.",
    "Your profile details may appear in search engines and public listings.",
    "You may receive notifications and promotional offers based on your activity.",
  ];

  void _savePrivacySettings() {
    // TODO: Send updated settings to backend
    showAppToast(context, "Privacy settings saved successfully.",
        icon: Icons.check_circle_outline_rounded);
  }

  Widget _buildPrivacyCard(int index, String text) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(2, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _privacyChecks[index],
            onChanged: (value) {
              setState(() {
                _privacyChecks[index] = value ?? false;
              });
            },
            activeColor: Colors.lightBlue,
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14.5, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Privacy Rules", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.lightBlue[200],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            ..._privacyTerms
                .asMap()
                .entries
                .map((entry) => _buildPrivacyCard(entry.key, entry.value))
                .toList(),
            SizedBox(height: 30),
            ElevatedButton.icon(
              icon: Icon(Icons.save_alt, color: Colors.white),
              label: Text("Save", style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
                shadowColor: Colors.black38,
              ),
              onPressed: _savePrivacySettings,
            ),
          ],
        ),
      ),
    );
  }
}
