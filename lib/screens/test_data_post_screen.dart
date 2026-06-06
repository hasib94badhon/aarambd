import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TestPost extends StatefulWidget {
  const TestPost({Key? key}) : super(key: key);

  @override
  State<TestPost> createState() => _TestPostState();
}

class _TestPostState extends State<TestPost> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Future<void> addDataToDB() async {
    final String apiUrl = 'http://127.0.0.1:5000/add';

    final Map<String, dynamic> requestData = {
      'phone': _phoneController.text,
      'password': _passwordController.text,
    };
     
     // Convert the data to raw JSON format
    String jsonData = jsonEncode(requestData);
    print('Raw JSON Data: $jsonData');

    final response = await http.post(
      Uri.parse(apiUrl),
      headers: <String, String>{
        'Content-Type': 'application/json;charset=UTF-8' ,// Set the Content-Type to 'application/json'
        
      },
      body: jsonData,
    );

    if (response.statusCode == 200) {
      print('Data added successfully');
    } else {
      print('Failed to add data: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: _phoneController, decoration: InputDecoration(labelText: 'Phone')),
            const SizedBox(height: 16),
            TextField(controller: _passwordController, obscureText: true, decoration: InputDecoration(labelText: 'Password')),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                addDataToDB();
                Navigator.push(context, MaterialPageRoute(builder: (context) => LoginScreen()));
              },
              child: const Text('Sign Up'),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: const Center(
        child: Text('Login Screen'),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    home: TestPost(),
  ));
}
