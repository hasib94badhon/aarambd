import 'package:flutter/material.dart';

class IconFromPng extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PNG as Icon Example'),
      ),
      body: Center(
        child: ImageIcon(
          AssetImage('images/download.png'),
          size: 50, // You can adjust the size here
          color: Colors.greenAccent, // Apply color if needed
        ),
      ),
    );
  }
}
