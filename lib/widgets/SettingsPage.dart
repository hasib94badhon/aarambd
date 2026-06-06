import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/pages/AccountControlPage.dart';
import 'package:aaram_bd/pages/AccountSettingsPage.dart';
import 'package:aaram_bd/pages/GeneralSettingsPage.dart';
import 'package:aaram_bd/pages/PrivacyRulesPage.dart';
import 'package:aaram_bd/pages/SecuritySettingsPage.dart';
import 'package:aaram_bd/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Optional, for better icons
import 'package:aaram_bd/widgets/termsPolicies.dart';
import 'package:aaram_bd/screens/AboutAaramBDPage.dart';

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(10),
        children: [
          // _buildSettingsCard(
          //   context,
          //   icon: Icons.settings,
          //   title: "General Settings",
          //   subtitle: "Location, Active status, Notifications control",
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => GeneralSettingsPage()),
          //     );
          //   },
          // ),
          _buildSettingsCard(
            context,
            icon: Icons.person,
            title: "Account Settings",
            subtitle: "Number Change, E-mail Change, Password Change",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AccountSettingsPage()),
              );
            },
          ),
          // _buildSettingsCard(
          //   context,
          //   icon: Icons.lock,
          //   title: "Privacy Rules",
          //   subtitle: "About the Data privacy",
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => PrivacyRulesPage()),
          //     );
          //   },
          // ),
          SizedBox(height: 8),
          _buildSettingsCard(
            context,
            icon: Icons.gavel_outlined,
            title: "Terms & Policies",
            subtitle: "Read our terms of service and privacy policies",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TermsPolicies()),
              );
            },
          ),
          SizedBox(height: 8),
          _buildSettingsCard(
            context,
            icon: Icons.apartment_rounded,
            title: "About AaramBD",
            subtitle: "Learn more about the AaramBD app and our mission",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AboutAaramBDPage()),
              );
            },
          ),
          SizedBox(height: 8),
          // _buildSettingsCard(
          //   context,
          //   icon: Icons.security,
          //   title: "Security",
          //   subtitle: "Two-Factor Authentication, Devices",
          //   onTap: () {
          //     Navigator.push(
          //       context,
          //       MaterialPageRoute(builder: (_) => SecuritySettingsPage()),
          //     );
          //   },
          // ),
          _buildSettingsCard(
            context,
            icon: Icons.delete_forever,
            title: "Account Control",
            subtitle: "Deactivate  Account",
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AccountControlPage()),
              );
            },
          ),
          SizedBox(height: 20),
          Center(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.redAccent, Colors.deepOrange],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                icon: Icon(Icons.logout_rounded, color: Colors.white),
                label: Text(
                  "Log Out",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () async {
                  await Config.clearTokens();
                  SharedPreferences prefs =
                      await SharedPreferences.getInstance();
                  await prefs.remove('userPhone');
                  await prefs.setBool('isLoggedIn', false);

                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => LoginScreen()),
                    (Route<dynamic> route) => false,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap}) {
    return Card(
      elevation: 4,
      color: Colors.white,
      margin: EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.lightBlue),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text(subtitle,
                        style:
                            TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 18, color: Colors.blue),
            ],
          ),
        ),
      ),
    );
  }
}
