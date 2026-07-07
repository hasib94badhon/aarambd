// lib/widgets/base_scaffold.dart
import 'package:aaram_bd/screens/navigation_screen.dart';
import 'package:aaram_bd/widgets/AppDrawer.dart';
import 'package:flutter/material.dart';
import 'custom_bottom_nav.dart';

class BaseScaffold extends StatelessWidget {
  final Widget body;
  final String userPhone;
  final int currentIndex;
  final PreferredSizeWidget? appBar;

  const BaseScaffold({
    Key? key,
    required this.body,
    required this.userPhone,
    required this.currentIndex,
    this.appBar,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      drawer: AppDrawer(
        userPhone: userPhone,
        onNavigate: (page) => Navigator.push(
            context, MaterialPageRoute(builder: (_) => page)),
      ),
      body: body,
      bottomNavigationBar: CustomBottomNavigation(
        currentIndex: currentIndex,
        onTap: (index) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => NavigationScreen(userPhone: userPhone,initialPage: index,),
            ),
          );
        },
      ),
    );
  }
}
