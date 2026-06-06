import 'dart:convert';
import 'package:aaram_bd/screens/advert_screen.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aaram_bd/config.dart';

Future<List<UserDetail>> fetchUserDetails(String id, bool isService) async {
   final String host = Config.host;
  final String idParam = isService ? 'service_id=$id' : 'shop_id=$id';
  final String url = '$host/get_service_or_shop_data?$idParam';

  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? loginUserId = prefs.getString('user_id');

  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'login_user_id': loginUserId}),
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final dataKey = isService ? 'service_data' : 'shop_data';
      final userDetails = jsonResponse[dataKey] != null
          ? (jsonResponse[dataKey] as List)
              .map((data) => UserDetail.fromJson(data))
              .toList()
          : <UserDetail>[];
      return userDetails;
    } else {
      throw Exception('Failed to load data from API');
    }
  } catch (e) {
    throw Exception("An unexpected error occurred: ${e.toString()}");
  }
}
