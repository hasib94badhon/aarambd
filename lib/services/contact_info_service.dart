import 'dart:convert';

import 'package:aaram_bd/config.dart';
import 'package:flutter/material.dart';

class ContactInfo {
  final String phone;
  final String email;
  final String address;
  final String website;
  final String facebook;

  const ContactInfo({
    required this.phone,
    required this.email,
    required this.address,
    required this.website,
    required this.facebook,
  });

  bool get isEmpty =>
      phone.isEmpty &&
      email.isEmpty &&
      address.isEmpty &&
      website.isEmpty &&
      facebook.isEmpty;

  factory ContactInfo.fromJson(Map<String, dynamic> json) {
    return ContactInfo(
      phone: (json['phone'] ?? '').toString().trim(),
      email: (json['email'] ?? '').toString().trim(),
      address: (json['address'] ?? '').toString().trim(),
      website: (json['website'] ?? '').toString().trim(),
      facebook: (json['facebook'] ?? '').toString().trim(),
    );
  }
}

class ContactInfoService {
  static Future<ContactInfo?> fetch(BuildContext context) async {
    final resp = await Config.apiGet('/get_contact_info', context);
    if (resp != null && resp.statusCode == 200) {
      final data = json.decode(resp.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        return ContactInfo.fromJson(data);
      }
    }
    return null;
  }
}
