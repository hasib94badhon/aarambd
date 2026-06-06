import 'dart:async';
import 'dart:convert';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/navigation_screen.dart';
import 'package:aaram_bd/screens/user_profile.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';
import 'package:http/http.dart' as http;
import 'package:aaram_bd/pages/cartPage.dart';
import 'package:aaram_bd/screens/advert_screen.dart';


final String host = Config.host;
class Album {
  final int user_id;
  final int reg_id;
  final String phone;
  final String name;
  final String location;
  final String category;

  const Album({
    required this.user_id,
    required this.reg_id,
    required this.name,
    required this.phone,
    required this.category,
    required this.location,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      user_id: json['user_id'] ?? 0,
      reg_id: json['reg_id'] ?? 0,
      name: json['name'],
      phone: json['phone'],
      category: json['category'],
      location: json['location'],
    );
  }
}

Future<List<Album>> fetchAlbum() async {
  final response = await http.get(Uri.parse('$host/get_users_data'));

  if (response.statusCode == 200) {
    final Map<String, dynamic> data = jsonDecode(response.body);
    final List<dynamic> userData = data['users_data'];

    return userData.map((json) => Album.fromJson(json)).toList();
  } else {
    throw Exception('Failed to load album');
  }
}

class ServiceHomepage extends StatefulWidget {
  const ServiceHomepage({Key? key}) : super(key: key);

  @override
  State<ServiceHomepage> createState() => _ServiceHomepageState();
}

class _ServiceHomepageState extends State<ServiceHomepage> {
  late Future<List<Album>> futureAlbum;

  @override
  void initState() {
    super.initState();
    futureAlbum = fetchAlbum();
  }

  @override
  Widget build(BuildContext context) {
    var pageIndex = 0;
    return MaterialApp(
      // title: 'All Adverts',
      // theme: ThemeData(
      //   primarySwatch: Colors.deepPurple,
      // ),
      home: Scaffold(
        appBar: AppBar(
          title: Text(
            'AaramBD',
          ),
          centerTitle: true,
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.person_search_outlined),
              iconSize: 35,
              onPressed: () {},
            )
          ],
          backgroundColor: Colors.green[100],
          leading: IconButton(
            onPressed: () {},
            icon: IconButton(
              icon: Icon(Icons.menu),
              iconSize: 35,
              onPressed: () {},
            ),
          ),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(25),
                  bottomRight: Radius.circular(25))),
        ),

        body: Center(
          child: FutureBuilder<List<Album>>(
            future: futureAlbum,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              } else if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}');
              } else if (snapshot.hasData) {
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final album = snapshot.data![index];
                    return Center(
                      child: InkWell(
                        // onTap: () {
                        //   Navigator.push(
                        //     context,
                        //     MaterialPageRoute(
                        //         builder: (context) => AdvertScreen()),
                        //   );
                        // },
                        child: Container(
                          color: Colors.green[100],
                          child: Card(
                            elevation: 6,
                            margin: const EdgeInsets.only(
                                left: 10, top: 10, right: 10, bottom: 4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Container(
                              padding: EdgeInsets.all(8),
                              color: Colors.white,
                              child: Row(
                                children: [
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(15),
                                        border: Border.all(
                                            width: 2, color: Colors.green)),
                                    child: Center(
                                      child: Icon(
                                        Icons.person,
                                        size: 50,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceAround,
                                      children: [
                                        Text(
                                          album.name,
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black,
                                          ),
                                        ),
                                        Text(
                                          '${album.category}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 16,
                                          ),
                                        ),
                                        SizedBox(height: 10),
                                        Text(
                                          '${album.location}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          'Response: ${index + 1}',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Icon(Icons.phone,
                                              color: Colors.green),
                                          SizedBox(width: 5),
                                          Text(album.phone,
                                              style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 14)),
                                        ],
                                      ),
                                      SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: () {},
                                        style: ElevatedButton.styleFrom(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 16,
                                            horizontal: 46,
                                          ),
                                          backgroundColor: Colors.green[300],
                                        ),
                                        child: Text(
                                          'Call',
                                          style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              } else {
                return const Text('Something went wrong');
              }
            },
          ),
        ),

        // floatingActionButton: SpeedDial(
        //   animatedIcon: AnimatedIcons.menu_close,
        //   overlayColor: Colors.black,
        //   overlayOpacity: 0.5,
        //   elevation: 6.0,
        //   children: [
        //     SpeedDialChild(
        //       child: Icon(Icons.info, size: 24, color: Colors.white),
        //       backgroundColor: Colors.blue,
        //       label: 'Info',
        //       onTap: () {
        //         // Handle Info option tapped
        //       },
        //     ),
        //     SpeedDialChild(
        //       child: Icon(Icons.local_activity, size: 24, color: Colors.white),
        //       backgroundColor: Colors.green,
        //       label: 'Service',
        //       onTap: () {
        //         // Handle Service option tapped
        //       },
        //     ),
        //     SpeedDialChild(
        //       child: Icon(Icons.shopping_cart, size: 24, color: Colors.white),
        //       backgroundColor: Colors.orange,
        //       label: 'Shops',
        //       onTap: () {
        //         // Handle Shops option tapped
        //       },
        //     ),
        //     SpeedDialChild(
        //       child: Icon(Icons.person, size: 24, color: Colors.white),
        //       backgroundColor: Colors.red,
        //       label: 'My Profile',
        //       onTap: () {
        //         // Handle My Profile option tapped
        //       },
        //     ),
        //     SpeedDialChild(
        //       child: Icon(Icons.person, size: 24, color: Colors.white),
        //       backgroundColor: Colors.red,
        //       label: '',
        //       onTap: () {
        //         // Handle My Profile option tapped
        //       },
        //     ),
        //   ],
        // ),
      ),
    );
  }
}

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: ServiceHomepage(),
  ));
}
