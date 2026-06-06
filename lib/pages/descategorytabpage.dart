import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:aaram_bd/config.dart';

String host = Config.host;

class DesCategoryTabPage extends StatefulWidget {
  @override
  _DesCategoryTabPageState createState() => _DesCategoryTabPageState();
}

class _DesCategoryTabPageState extends State<DesCategoryTabPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List categories = [];
  Map<String, List> categoryDescriptions = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCategoriesAndDescriptions();
  }

  Future<void> _fetchCategoriesAndDescriptions() async {
    final response = await http.get(Uri.parse('$host/get_description_categories'));
    if (response.statusCode == 200) {
      final categoryData = jsonDecode(response.body)['categories'];
      categories = categoryData;

      for (var cat in categories) {
        final id = cat['des_cat_id'].toString();
        final res = await http.get(Uri.parse('$host/get_description_by_cat?des_cat_id=$id'));
        if (res.statusCode == 200) {
          categoryDescriptions[id] = jsonDecode(res.body)['descriptions'];
        } else {
          categoryDescriptions[id] = [];
        }
      }

      _tabController = TabController(length: categories.length, vsync: this);

      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget buildDescriptionCard(Map desc) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              desc['des'] ?? '',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (desc['des_photo'] != null && desc['des_photo'].toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    desc['des_photo'],
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 160,
                      color: Colors.grey[300],
                      child: Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                ),
              ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.visibility, size: 18, color: Colors.grey[700]),
                    SizedBox(width: 4),
                    Text(
                      "${desc['des_view']} views",
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 18, color: Colors.grey[700]),
                    SizedBox(width: 4),
                    Text(
                      desc['time'] ?? '',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(50),
        child: AppBar(
          backgroundColor: Colors.blueAccent,
          elevation: 1,
          automaticallyImplyLeading: false,
          bottom: isLoading
              ? null
              : PreferredSize(
                  preferredSize: Size.fromHeight(50),
                  child: Container(
                    color: Colors.white,
                    child: TabBar(
                      controller: _tabController,
                      isScrollable: true,
                      indicator: BoxDecoration(
                        color: Colors.blueAccent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.blueAccent,
                      labelStyle: TextStyle(fontWeight: FontWeight.bold),
                      tabs: categories.map((cat) {
                        return Tab(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blueAccent),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(cat['des_cat_name']),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
        ),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: categories.map((cat) {
                final id = cat['des_cat_id'].toString();
                final descriptions = categoryDescriptions[id] ?? [];

                if (descriptions.isEmpty) {
                  return Center(
                    child: Text(
                      'No descriptions available',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  itemCount: descriptions.length,
                  itemBuilder: (context, index) {
                    return buildDescriptionCard(descriptions[index]);
                  },
                );
              }).toList(),
            ),
    );
  }
}
