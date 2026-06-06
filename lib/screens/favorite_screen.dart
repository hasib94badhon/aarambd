import 'dart:convert';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/main.dart';
import 'package:aaram_bd/pages/ServiceCart.dart';
import 'package:aaram_bd/pages/cartPage.dart';
import 'package:aaram_bd/screens/advert_screen.dart';
import 'package:aaram_bd/screens/service_homepage.dart';
import 'package:aaram_bd/screens/navigation_screen.dart';
import 'package:aaram_bd/widgets/base_scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:aaram_bd/widgets/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

final String host = Config.host;

class UserDetail {
  final int actual_user_id;
  final String address;
  final String business_name;
  final String category;
  final String photo;
  final String phone;
  final int shop_id;
  final int service_id;
  final int userId;
  final bool isservice;
  final String user_called;
  final String user_viewed;
  final String days_since_creation;
  final int view_id;
  final String? distance;
  final String? call_status; // Add user status if needed
  final String? sub_type;
  String lastSeen = '';
  String lastCalled = '';

  UserDetail(
      {required this.address,
      required this.actual_user_id,
      required this.business_name,
      required this.category,
      required this.photo,
      required this.phone,
      required this.userId,
      required this.shop_id,
      required this.service_id,
      required this.isservice,
      required this.user_called,
      required this.user_viewed,
      required this.days_since_creation,
      required this.view_id,
      this.distance,
      this.call_status,
      required this.lastSeen,
      required this.lastCalled,
      this.sub_type});

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    int serviceId = json['service_id'] ?? 0;
    int shopId = json['shop_id'] ?? 0;

    // Initialize the extra field with an empty string

    return UserDetail(
        address: json['location'] ?? '',
        actual_user_id: json['user_id'] ?? 0,
        category: json['cat_name'] ?? '',
        business_name: json['name'] ?? '',
        photo: json['photo'] ?? '',
        phone: json['phone'] ?? 0,
        userId: serviceId != 0 ? serviceId : shopId,
        service_id: serviceId,
        shop_id: shopId,
        isservice: serviceId != 0,
        user_called: json['user_called'],
        user_viewed: json['user_viewed'],
        days_since_creation: json['days_since_creation'],
        view_id: json['user_id'], //ensure there no trailing spaces
        distance: json['distance'],
        call_status: json['call_status'],
        lastSeen: json['last_seen'] ?? '',
        lastCalled: json['last_called'] ?? '',
        sub_type: json['sub_type']); // Add user status if needed
  }
}

class UserFetchResult {
  final List<UserDetail> users;
  final String? message;
  final bool locationAvailable;

  UserFetchResult(this.users, {this.message, required this.locationAvailable});
}

class FavoriteScreen extends StatefulWidget {
  final String cat_id;
  final String categoryName;

  final String userPhone;

  FavoriteScreen(
      {required this.categoryName,
      required this.cat_id,
      required this.userPhone});

  @override
  _FavoriteScreenState createState() => _FavoriteScreenState();
}

class _FavoriteScreenState extends State<FavoriteScreen> with RouteAware {
  List<UserDetail> combinedUsers = [];
  bool locationAvailable = true;
  bool isLoading = true;
  String sortBy = 'most_called';

  @override
  void initState() {
    super.initState();
    fetchData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(this.context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    fetchData();
  }

  void fetchData() async {
    setState(() {
      isLoading = true;
    });

    final serviceResult =
        await fetchUserDetails(widget.cat_id, 'service', sortBy);
    final shopResult = await fetchUserDetails(widget.cat_id, 'shop', sortBy);

    setState(() {
      combinedUsers = [...serviceResult.users, ...shopResult.users];
      locationAvailable =
          serviceResult.locationAvailable || shopResult.locationAvailable;
      isLoading = false;
    });
  }

  Future<UserFetchResult> fetchUserDetails(
      String cat_id, String dataType, String sortBy) async {
    String userLocation = '';
    bool locationAvailable = true;
    final userId = await Config.getLoggedInUser();
    if (sortBy == 'nearby') {
      final locResponse = await http
          .get(Uri.parse('${Config.host}/get_user_location?user_id=$userId'));

      if (locResponse.statusCode == 200) {
        final locData = jsonDecode(locResponse.body);
        if (locData.containsKey('location_string')) {
          userLocation = locData['location_string'];
        } else {
          locationAvailable = false;
        }
      } else {
        locationAvailable = false;
      }

      if (!locationAvailable) {
        return UserFetchResult([], locationAvailable: false);
      }
    }

    final url =
        '${Config.host}/get_data_by_category?cat_id=$cat_id&data_type=$dataType&sort_by=$sortBy'
        '${sortBy == 'nearby' && userLocation.isNotEmpty ? '&user_location=$userLocation' : ''}'
        '&user_id=$userId';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final userDetails = jsonResponse['${dataType}_information'] != null
            ? (jsonResponse['${dataType}_information'] as List)
                .map((data) => UserDetail.fromJson(data))
                .toList()
            : <UserDetail>[];

        return UserFetchResult(userDetails,
            locationAvailable: locationAvailable);
      } else {
        return UserFetchResult([], locationAvailable: locationAvailable);
      }
    } catch (e) {
      return UserFetchResult([], locationAvailable: locationAvailable);
    }
  }

  void updateSorting(String newSortBy) {
    if (sortBy != newSortBy) {
      setState(() {
        sortBy = newSortBy;
        fetchData();
      });
    }
  }

  void handleAction(int user_id, String actionType, int detail_post_id) async {
    NotificationService notificationService = NotificationService();
    await notificationService.sendNotificationWithLoggedInUser(
        user_id, actionType, detail_post_id, context);
  }

  Widget getSortSpecificInfo(UserDetail user) {
    TextStyle infoStyle = const TextStyle(
        fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black);

    switch (sortBy) {
      case 'most_called':
        return Text(
            user.user_called == '0'
                ? 'No call yet'
                : '${Config.formatLargeNumber(int.parse(user.user_called))} Calls',
            style: infoStyle);
      case 'most_viewed':
        return Text(
            user.user_viewed == '0'
                ? 'No views yet'
                : '${Config.formatLargeNumber(int.parse(user.user_viewed))} Views',
            style: infoStyle);
      case 'recent':
        // return Text(
        //     user.days_since_creation == '0'
        //         ? 'Active Today'
        //         : user.days_since_creation == '1'
        //             ? '1 day ago'
        //             : '${user.days_since_creation} days ago',
        //     style: infoStyle);
        return Text(Config.getTimeDifference(user.days_since_creation),
            style: infoStyle);
      case 'nearby':
        return Text(
            user.distance != null && user.distance!.isNotEmpty
                ? "Distance: ${user.distance}"
                : 'Distance not available',
            style: infoStyle);
      default:
        return const SizedBox();
    }
  }

  Widget _buildNoImage() {
    return Container(
      color: Colors.grey[300],
      child:
          Center(child: Icon(Icons.person_off, color: Colors.grey, size: 40)),
    );
  }

  Widget buildUserStatusIndicator(String callStatus) {
    final bool isActive = callStatus == 'active';

    return Row(
      children: [
        Icon(
          Icons.circle,
          color: isActive ? Colors.greenAccent : Colors.grey,
          size: 12,
        ),
        const SizedBox(width: 4),
        Text(
          isActive ? "Online" : "Offline",
          style: TextStyle(
            color: isActive ? Colors.green[700] : Colors.grey,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  // Compact inline status pill
  Widget _statusPill(String callStatus) {
    final bool isActive = callStatus.toLowerCase() == 'active';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFECFDF5)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: isActive
              ? const Color(0xFF34D399)
              : const Color(0xFFCBD5E1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? const Color(0xFF10B981)
                  : const Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Active' : 'Offline',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isActive
                  ? const Color(0xFF065F46)
                  : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF1A56DB);
    const bg = Color(0xFFF0F3F8);

    final sortOptions = [
      {'label': 'Nearby',  'value': 'nearby',      'icon': Icons.location_on_outlined},
      {'label': 'Recent',  'value': 'recent',       'icon': Icons.access_time_rounded},
      {'label': 'Viewed',  'value': 'most_viewed',  'icon': Icons.visibility_outlined},
      {'label': 'Called',  'value': 'most_called',  'icon': Icons.phone_outlined},
    ];

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(widget.categoryName),
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFFEAEDF2)),
        ),
      ),
      body: Column(
        children: [
          // ── Sort chip row ──────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: sortOptions.map((opt) {
                  final active = sortBy == opt['value'];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => updateSorting(opt['value'] as String),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: active ? brand : Colors.white,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: active ? brand : const Color(0xFFDDE4F0),
                            width: 1.4,
                          ),
                          boxShadow: active
                              ? [
                                  BoxShadow(
                                    color: brand.withValues(alpha: 0.20),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              opt['icon'] as IconData,
                              size: 14,
                              color: active
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              opt['label'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: active
                                    ? Colors.white
                                    : const Color(0xFF4A5568),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          Container(height: 1, color: const Color(0xFFEEF2F8)),

          // ── Content ────────────────────────────────────────────────────
          Expanded(
            child: isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          height: 34,
                          width: 34,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: brand,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Loading…',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                : combinedUsers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: brand.withValues(alpha: 0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.search_off_rounded,
                                    color: brand, size: 32),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                sortBy == 'nearby'
                                    ? (!locationAvailable
                                        ? 'Location access needed'
                                        : 'No nearby users found')
                                    : 'No users in this category',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1A2340),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                sortBy == 'nearby' && !locationAvailable
                                    ? 'Please allow location access to see nearby results.'
                                    : 'Try a different sort option.',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
                        itemCount: combinedUsers.length,
                        itemBuilder: (context, index) {
                          final user = combinedUsers[index];

                          // Interaction recency check (logic unchanged)
                          DateTime? lastSeen;
                          DateTime? lastCalled;
                          try {
                            if (user.lastSeen.isNotEmpty) {
                              lastSeen = DateFormat("EEE dd MMM yyyy HH:mm:ss")
                                  .parse(user.lastSeen);
                            }
                            if (user.lastCalled.isNotEmpty) {
                              lastCalled =
                                  DateFormat("EEE dd MMM yyyy HH:mm:ss")
                                      .parse(user.lastCalled);
                            }
                          } catch (_) {}

                          final now = DateTime.now();
                          final interactedRecently =
                              (lastSeen != null &&
                                      now.difference(lastSeen).inDays <= 7) ||
                                  (lastCalled != null &&
                                      now.difference(lastCalled).inDays <= 7);

                          final isActive =
                              user.call_status?.toLowerCase() == 'active';
                          final lastSeenStr = Config.getTimeDifference(
                              user.lastSeen,
                              fallback: 'Never viewed');
                          final lastCalledStr = Config.getTimeDifference(
                              user.lastCalled,
                              fallback: 'Never called');

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () {
                                  handleAction(user.view_id, 'view', 0);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AdvertScreen(
                                        userId:
                                            user.actual_user_id.toString(),
                                        isService: user.isservice,
                                        advertData: AdvertData(
                                          userId:
                                              user.actual_user_id.toString(),
                                          isService: user.isservice,
                                          additionalData: user.service_id != 0
                                              ? {'service_id': user.service_id}
                                              : user.shop_id != 0
                                                  ? {'shop_id': user.shop_id}
                                                  : {
                                                      'user_only': user
                                                          .actual_user_id
                                                          .toString()
                                                    },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: Ink(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: interactedRecently
                                          ? const Color(0xFFFFE082)
                                          : const Color(0xFFEDF1F8),
                                      width: interactedRecently ? 1.5 : 1,
                                    ),
                                    boxShadow: const [
                                      BoxShadow(
                                        color: Color(0x0F000000),
                                        blurRadius: 10,
                                        offset: Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        // ── Avatar ────────────────────
                                        Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            ClipOval(
                                              child: user.photo.isNotEmpty
                                                  ? Image.network(
                                                      user.photo,
                                                      width: 60,
                                                      height: 60,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) =>
                                                          _buildNoImage(),
                                                    )
                                                  : SizedBox(
                                                      width: 60,
                                                      height: 60,
                                                      child: _buildNoImage(),
                                                    ),
                                            ),
                                            // Verified badge
                                            if (user.sub_type != null)
                                              Positioned(
                                                bottom: 0,
                                                right: -2,
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(3),
                                                  decoration:
                                                      const BoxDecoration(
                                                    color: Colors.white,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    Icons.verified_rounded,
                                                    size: 16,
                                                    color: user.sub_type ==
                                                            'paid'
                                                        ? const Color(
                                                            0xFF1A56DB)
                                                        : Colors.grey.shade400,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),

                                        const SizedBox(width: 12),

                                        // ── Details ───────────────────
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // Name + status pill
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      user.business_name,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 15,
                                                        color:
                                                            Color(0xFF1A2340),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  _statusPill(user.call_status
                                                      .toString()),
                                                ],
                                              ),

                                              const SizedBox(height: 5),

                                              // Category
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.category_outlined,
                                                    size: 13,
                                                    color: Color(0xFF94A3B8),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      user.category,
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: const TextStyle(
                                                        fontSize: 12.5,
                                                        color:
                                                            Color(0xFF64748B),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),

                                              const SizedBox(height: 6),

                                              // Sort-specific stat
                                              getSortSpecificInfo(user),

                                              // Interaction timestamps
                                              if (isActive ||
                                                  lastSeenStr.isNotEmpty ||
                                                  lastCalledStr.isNotEmpty) ...[
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    if (lastSeenStr.isNotEmpty)
                                                      _microStat(
                                                        icon: Icons
                                                            .visibility_outlined,
                                                        label: lastSeenStr,
                                                      ),
                                                    if (lastSeenStr.isNotEmpty &&
                                                        lastCalledStr
                                                            .isNotEmpty)
                                                      const SizedBox(width: 10),
                                                    if (lastCalledStr
                                                        .isNotEmpty)
                                                      _microStat(
                                                        icon: Icons
                                                            .phone_outlined,
                                                        label: lastCalledStr,
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),

                                        const SizedBox(width: 6),
                                        const Icon(
                                          Icons.chevron_right_rounded,
                                          color: Color(0xFFCBD5E1),
                                          size: 22,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _microStat({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: const Color(0xFFAAB2C0)),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFFAAB2C0),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
