import 'package:flutter/material.dart';

class SecuritySettingsPage extends StatefulWidget {
  @override
  _SecuritySettingsPageState createState() => _SecuritySettingsPageState();
}

class _SecuritySettingsPageState extends State<SecuritySettingsPage> {
  bool _is2FAEnabled = true;

  // Dummy list of trusted devices
  List<String> _trustedDevices = [
    "Pixel 6 – Android 13",
    "iPhone 12 – iOS 16",
    "Web – Chrome on Windows"
  ];

  void _addCurrentDevice() {
    setState(() {
      _trustedDevices.add("Current Device – Flutter Debug");
    });
  }

  void _removeDevice(int index) {
    setState(() {
      _trustedDevices.removeAt(index);
    });
  }

  void _saveSecuritySettings() {
    // TODO: Save 2FA and device list to backend
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Security settings saved successfully."),
        backgroundColor: Colors.green,
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Widget _buildDeviceTile(String device, int index) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 6),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
        children: [
          Icon(Icons.devices, color: Colors.blueGrey),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              device,
              style: TextStyle(fontSize: 14.5, color: Colors.black87),
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete, color: Colors.redAccent),
            onPressed: () => _removeDevice(index),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Security Settings", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.lightBlue[200],
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Two-Factor Authentication"),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Enable Two-Factor Authentication",
                    style: TextStyle(fontSize: 15),
                  ),
                  Switch(
                    value: _is2FAEnabled,
                    onChanged: (value) {
                      setState(() {
                        _is2FAEnabled = value;
                      });
                    },
                    activeColor: Colors.green,
                  )
                ],
              ),
            ),

            SizedBox(height: 24),
            _buildSectionTitle("Trusted Devices"),
            ..._trustedDevices
                .asMap()
                .entries
                .map((entry) => _buildDeviceTile(entry.value, entry.key))
                .toList(),

            SizedBox(height: 14),
            Center(
              child: ElevatedButton.icon(
                icon: Icon(Icons.add),
                label: Text("Add Current Device"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  elevation: 4,
                  shadowColor: Colors.black38,
                ),
                onPressed: _addCurrentDevice,
              ),
            ),

            SizedBox(height: 30),
            Center(
              child: ElevatedButton.icon(
                icon: Icon(Icons.save_alt, color: Colors.white),
                label: Text("Save", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.lightBlue,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                ),
                onPressed: _saveSecuritySettings,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
