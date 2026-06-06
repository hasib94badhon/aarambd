import 'package:flutter/services.dart'; // For clipboard functionality
import 'package:flutter/material.dart';
import 'dart:convert'; // For JSON decoding
import 'package:http/http.dart' as http;

class UserProfile extends StatefulWidget {
  @override
  _UserProfileState createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  // Example variables for user data
  String user_id = "";
  String userName = "User Name";
  String userCategory = "Category";
  String userDescription = "User Description";
  String userAddress = "User Address";
  String profile_pic = "No image";
  String userPhone = "1234567890"; // Replace with actual phone data
  int userview = 0;
  int usercall = 0;
  int usershare = 0;
  List<Map<String, dynamic>> posts = [];
  final String host = "https://your-api-url.com";

  Future<void> fetchUserData() async {
    print("Fetching user data for phone: $userPhone");
    final response = await http.get(
      Uri.parse('$host/get_user_by_phone?phone=$userPhone'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print("Fetched data: $data");
      setState(() {
        user_id = data['user_id'];
        userName = data['name'] ?? "User Name";
        userCategory = data['cat_name'] ?? "Category";
        userDescription = data['description'] ?? "User Description";
        userAddress = data['location'] ?? "User Address";
        profile_pic = data['photo'] ?? "No image";
        userview = data['user_viewed'];
        usercall = data['user_called'];
        usershare = data['user_shared'];
        posts = List<Map<String, dynamic>>.from(
            data['posts'] ?? []); // Store posts data
      });
    } else {
      print("Failed to fetch user data: ${response.statusCode}");
    }
  }

  void saveProfileLink() async {
  try {
    final response = await http.get(
      Uri.parse('$host/get_user_by_phone?phone=$userPhone'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      // Extract the necessary fields
      final userName = data['name'] ?? "User Name";
      final userCategory = data['cat_name'] ?? "Category";
      final userDescription = data['description'] ?? "User Description";

      // Construct the profile data string
      final profileLink =
          "Name: $userName\nCategory: $userCategory\nDescription: $userDescription";

      // Copy to clipboard
      Clipboard.setData(ClipboardData(text: profileLink));

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profile link saved successfully!',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      print("Failed to fetch user data: ${response.statusCode}");

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save profile link.',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    print("Error: $e");

    // Show error message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'An error occurred while saving profile link.',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 2),
      ),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("User Profile")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundImage: profile_pic != "No image"
                  ? NetworkImage(profile_pic)
                  : null,
              radius: 50,
              child: profile_pic == "No image"
                  ? Icon(Icons.person, size: 50)
                  : null,
            ),
            SizedBox(height: 10),
            Text(
              userName,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            Text(
              userCategory,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: saveProfileLink,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.5),
                      blurRadius: 6,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(10),
                child: Icon(
                  Icons.share,
                  color: Colors.black,
                  size: 35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
