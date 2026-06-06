import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:aaram_bd/config.dart';


final String host = Config.host;
class AppCategoryDetails extends StatelessWidget {
  final String category;

  AppCategoryDetails({required this.category});

  Future<List<dynamic>> fetchCategoryData() async {
    final response = await http.get(
      Uri.parse('$host/get_apps_by_cat?category=$category'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        return data['apps'];
      } else {
        throw Exception(data['message']);
      }
    } else {
      throw Exception('Failed to fetch data: ${response.statusCode}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category),
        backgroundColor: Colors.blueAccent,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: fetchCategoryData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(color: Colors.red),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text('No data found for this category'),
            );
          } else {
            final apps = snapshot.data!;
            return ListView.builder(
              itemCount: apps.length,
              itemBuilder: (context, index) {
                final app = apps[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: NetworkImage(
                      app['photo'], // Replace with the image URL if available
                    ),
                    backgroundColor: Colors.grey[300], // Fallback color
                    child: app['web'] == null
                        ? Icon(Icons.image_not_supported)
                        : null,
                  ),
                  title: Text(app['name'] ?? 'Unknown'),
                  subtitle: Text(app['web'] ?? 'No address provided'),
                  onTap: () {
                    // Handle tap, e.g., navigate to a detailed view of the app
                  },
                );
              },
            );
          }
        },
      ),
    );
  }
}
