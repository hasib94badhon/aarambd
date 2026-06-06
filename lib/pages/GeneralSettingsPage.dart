import 'package:flutter/material.dart';

class GeneralSettingsPage extends StatefulWidget {
  @override
  _GeneralSettingsPageState createState() => _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends State<GeneralSettingsPage> {
  bool isLocationOn = true;
  bool isActiveStatusOn = true;
  bool isViewNotificationOn = true;
  bool isCallNotificationOn = true;
  bool isCommentNotificationOn = true;

  void _saveSettings() {
    // TODO: Save to API or local storage
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Settings saved successfully!"),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildDecoratedSwitch({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(2, 4),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.lightBlue[50],
          child: Icon(icon, color: Colors.lightBlue),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Switch(
          value: value,
          onChanged: onChanged,
          activeColor: Colors.lightBlue,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text("General Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.lightBlue[200],
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          _buildDecoratedSwitch(
            icon: Icons.location_on,
            title: "Location",
            subtitle: "Allow app to access your location",
            value: isLocationOn,
            onChanged: (val) => setState(() => isLocationOn = val),
          ),
          _buildDecoratedSwitch(
            icon: Icons.toggle_on,
            title: "Active Status",
            subtitle: "Show your online status",
            value: isActiveStatusOn,
            onChanged: (val) => setState(() => isActiveStatusOn = val),
          ),
          _buildDecoratedSwitch(
            icon: Icons.remove_red_eye,
            title: "View Notification",
            subtitle: "Notify when someone views your profile",
            value: isViewNotificationOn,
            onChanged: (val) => setState(() => isViewNotificationOn = val),
          ),
          _buildDecoratedSwitch(
            icon: Icons.call,
            title: "Call Notification",
            subtitle: "Notify when someone tries to call you",
            value: isCallNotificationOn,
            onChanged: (val) => setState(() => isCallNotificationOn = val),
          ),
          _buildDecoratedSwitch(
            icon: Icons.comment,
            title: "Comment Notification",
            subtitle: "Notify when someone comments on your post",
            value: isCommentNotificationOn,
            onChanged: (val) => setState(() => isCommentNotificationOn = val),
          ),
          SizedBox(height: 30),
          Center(
            child: ElevatedButton.icon(
              icon: Icon(Icons.save_alt, color: Colors.white),
              label: Text("Save Settings", style: TextStyle(fontSize: 16, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 30, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                backgroundColor: Colors.lightBlue,
                elevation: 6,
                shadowColor: Colors.black38,
              ),
              onPressed: _saveSettings,
            ),
          ),
        ],
      ),
    );
  }
}
