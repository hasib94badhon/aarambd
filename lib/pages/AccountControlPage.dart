// lib/screens/account_control_page.dart

import 'dart:convert';
import 'package:aaram_bd/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:aaram_bd/config.dart';

class AccountControlPage extends StatefulWidget {
  @override
  _AccountControlPageState createState() => _AccountControlPageState();
}

class _AccountControlPageState extends State<AccountControlPage> {
  final List<String> deactivateReasons = [
    "I'm taking a break",
    "I get too many notifications",
    "Concerned about privacy",
    "I found an alternative",
  ];
  final Set<String> selectedDeactivateReasons = {};

  bool _isSubmitting = false;

  Future<void> _confirmDeactivation() async {
    if (selectedDeactivateReasons.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select at least one reason.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    // Call your API via Config.apiPost
    final response = await Config.apiPost(
      '/user/deactivate',
      {'reasons': selectedDeactivateReasons.toList()},
      context,
    );

    setState(() => _isSubmitting = false);

    if (response == null) {
      // Config.apiPost returns null if refresh fails and force logout happens
      return;
    }

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final msg = body['message'] ?? 'Account deactivated.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );

      // Clear tokens & navigate back to login
      await Config.clearTokens();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => LoginScreen()), // Assuming you have a LoginPage
        (route) => false,
      );
    } else {
      final body = jsonDecode(response.body);
      final errorMsg =
          body['message'] ?? body['error'] ?? 'Deactivation failed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg)),
      );
    }
  }

  Widget _buildDeactivateCard() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ExpansionTile(
        leading: Icon(Icons.pause_circle, color: Colors.amber.shade700),
        title: Text(
          "Deactivate Account",
          style: TextStyle(
            color: Colors.amber.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
        children: [
          ...deactivateReasons.map((reason) {
            return CheckboxListTile(
              title: Text(reason),
              value: selectedDeactivateReasons.contains(reason),
              activeColor: Colors.amber.shade700,
              onChanged: (checked) {
                setState(() {
                  if (checked == true) {
                    selectedDeactivateReasons.add(reason);
                  } else {
                    selectedDeactivateReasons.remove(reason);
                  }
                });
              },
            );
          }).toList(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: _isSubmitting
                ? Center(child: CircularProgressIndicator())
                : ElevatedButton.icon(
                    icon: Icon(Icons.check_circle_outline),
                    label: Text("Confirm Deactivate"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      padding:
                          EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: StadiumBorder(),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: Text("Confirm Deactivation"),
                            content: Text(
                              "Are you sure you want to deactivate your account?\n\n"
                              "Once deactivated, you will not be able to reactivate your account for 24 hours.",
                              style: TextStyle(fontSize: 15),
                            ),
                            actions: [
                              TextButton(
                                child: Text("No",
                                    style: TextStyle(color: Colors.grey[700])),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.amber.shade700,
                                ),
                                child: Text("Yes"),
                                onPressed: () async {
                                  Navigator.of(context).pop(); // Close dialog
                                  await _confirmDeactivation(); // Proceed with deactivation
                                },
                              ),
                            ],
                          );
                        },
                      );
                    },
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
        title: Text("Account Control"),
        backgroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            SizedBox(height: 8),
            _buildDeactivateCard(),
            // If you have other account controls (like delete), put them here.
          ],
        ),
      ),
    );
  }
}
