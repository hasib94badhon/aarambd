import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/advert_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final String host = Config.host;

class FavoriteProfilesPage extends StatefulWidget {
  final String userId;

  const FavoriteProfilesPage({required this.userId});

  @override
  _FavoriteProfilesPageState createState() => _FavoriteProfilesPageState();
}

class _FavoriteProfilesPageState extends State<FavoriteProfilesPage>
    with SingleTickerProviderStateMixin {
  List<dynamic> favoriteProfiles = [];
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    fetchFavorites();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  Future<void> fetchFavorites() async {
    final response = await http.get(
      Uri.parse('$host/get_favorite_user_profiles?user_id=${widget.userId}'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        favoriteProfiles = data['favorite_profiles'];
      });
    } else {
      print('Failed to load favorites');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget buildFavoriteItem(Map<String, dynamic> profile) {
    final bool isService =
        profile['is_service'] == true || profile['is_service'] == 'true';
    final int service = profile['service_id'] ?? 0;
    final int shop = profile['shop_id'] ?? 0;
    final int userId = profile['user_id'] ?? '';
    final String fetchId = isService ? service.toString() : shop.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(35),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple.shade200, Colors.blue[50]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(35),
            border: Border.all(color: Colors.white70, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.pink.shade200.withValues(alpha: 0.5),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white,
              child: ClipOval(
                child: profile['photo'] != null &&
                        profile['photo'].toString().trim().isNotEmpty
                    ? Image.network(
                        profile['photo'],
                        fit: BoxFit.cover,
                        width: 60,
                        height: 60,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.person_off, color: Colors.grey),
                      )
                    : const Icon(Icons.person_off,
                        color: Colors.grey, size: 30),
              ),
            ),
            title: Text(
              profile['name'] ?? '',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.black87),
            ),
            subtitle: Text(
              profile['cat_name'] ?? '',
              style: const TextStyle(color: Colors.black54, fontSize: 14),
            ),
            trailing: ScaleTransition(
              scale: _pulse,
              child:
                  const Icon(Icons.favorite, color: Colors.redAccent, size: 32),
            ),
            onTap: () {
              late final String targetId;
              late final bool isService;
              late final Map<String, String> additionalData;

              if (service != 0) {
                targetId = service.toString();
                isService = true;
                additionalData = {'service_id': targetId};
              } else if (shop != 0) {
                targetId = shop.toString();
                isService = false;
                additionalData = {'shop_id': targetId};
              } else {
                // neither service nor shop → user‑only
                targetId = userId.toString();
                isService = false;
                additionalData = {'user_only': targetId};
              }
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AdvertScreen(
                      userId: targetId,
                      isService: isService,
                      advertData: AdvertData(
                        userId: targetId,
                        isService: isService,
                        additionalData: additionalData,
                      ),
                    ),
                  ));
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Profiles'),
        centerTitle: true,
        backgroundColor: const Color.fromARGB(255, 230, 194, 232),
      ),
      body: favoriteProfiles.isEmpty
          // ✨ Animated “No saved profiles” placeholder
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _pulse,
                    child: Icon(
                      Icons.favorite_border,
                      size: 80,
                      color: Colors.grey.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No saved profiles',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: favoriteProfiles.length,
              itemBuilder: (context, i) =>
                  buildFavoriteItem(favoriteProfiles[i]),
            ),
    );
  }
}
