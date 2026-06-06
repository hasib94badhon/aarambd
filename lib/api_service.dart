import 'dart:async';
import 'dart:convert';
import 'package:aaram_bd/config.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class ApiService {
  final String host = Config.host;

  // Fetch data with pagination and filtering
//   Future<List<dynamic>> fetchPosts({
//     required int page,
//     required int pageSize,
//     required String sortBy,
//     int? catId,
//   }) async {
//     try {
//       final query = Uri.parse(
//         '$host/get_today_post?sort_by=$sortBy&page=$page&page_size=$pageSize${catId != null ? '&cat_id=$catId' : ''}',
//       );

//       final response = await http.get(query);

//       if (response.statusCode == 200) {
//         final data = json.decode(response.body);
//         return data['most_update_post'];  // Adjust according to your API response
//       } else {
//         throw Exception('Failed to load posts');
//       }
//     } catch (error) {
//       print("Error fetching posts: $error");
//       return [];
//     }
//   }
// }

// Future<List<dynamic>> fetchPosts({
//   required int page,
//   required int pageSize,
//   required String sortBy,
//   String? catId,
// }) async {
//   final params = {
//     'sort_by': sortBy,
//     'page': '$page',
//     'page_size': '$pageSize',
//     if (catId != null) 'cat_id': '$catId',
//   };

//   final uri = Uri.parse(host).replace(
//     path: '/get_today_post',
//     queryParameters: params,
//   );

//   try {
//     final response = await http
//         .get(uri)
//         .timeout(const Duration(seconds: 12)); // ⏱ add timeout

//     if (response.statusCode == 200) {
//       final data = json.decode(response.body);
//       return data['most_update_post'] as List<dynamic>;
//     } else {
//       print('API error: ${response.statusCode}');
//       return [];
//     }
//   } on TimeoutException catch (_) {
//     print('Timeout while fetching posts.');
//     return [];
//   } on http.ClientException catch (e) {
//     print('ClientException while fetching posts: $e');
//     return [];
//   } catch (e) {
//     print('Unexpected error: $e');
//     return [];
//   }
// }

  Future<List<dynamic>> fetchPosts({
    required int page,
    required int pageSize,
    required String sortBy,
    String? catId,
    required BuildContext
        context, // add context so Config can handle refresh/logout
  }) async {
    final params = {
      'sort_by': sortBy,
      'page': '$page',
      'page_size': '$pageSize',
      if (catId != null) 'cat_id': '$catId',
    };

    final endpoint = Uri(
      path: '/get_today_post',
      queryParameters: params,
    ).toString();

    try {
      final resp = await Config.apiGet(endpoint, context);

      if (resp != null && resp.statusCode == 200) {
        final data = json.decode(resp.body);
        return data['most_update_post'] as List<dynamic>;
      } else {
        print('API error: ${resp?.statusCode}');
        return [];
      }
    } on TimeoutException catch (_) {
      print('Timeout while fetching posts.');
      return [];
    } catch (e) {
      print('Unexpected error: $e');
      return [];
    }
  }
}
