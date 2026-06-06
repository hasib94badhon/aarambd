import 'dart:async';
import 'dart:convert';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/main.dart';
import 'package:aaram_bd/screens/advert_screen.dart';
import 'package:aaram_bd/widgets/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models — unchanged
// ─────────────────────────────────────────────────────────────────────────────

final String host = Config.host;

class UserDetail {
  final String address;
  final String business_name;
  final String category;
  final String? phone;
  final String photo;
  final bool isService;
  final int service_id;
  final int shop_id;
  final int view_id;
  final String user_called;
  final String user_viewed;
  final String days_since_creation;
  final String? distance;
  final String? call_status;
  final String? sub_type;
  String lastSeen = '';
  String lastCalled = '';

  UserDetail({
    required this.address,
    required this.business_name,
    required this.category,
    required this.view_id,
    required this.phone,
    required this.photo,
    required this.service_id,
    required this.isService,
    required this.shop_id,
    required this.user_called,
    required this.user_viewed,
    required this.days_since_creation,
    required this.distance,
    required this.call_status,
    required this.lastSeen,
    required this.lastCalled,
    this.sub_type,
  });

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    return UserDetail(
      address: json['location'] ?? 'No Address',
      category: json['cat_name'] ?? 'No Category',
      business_name: json['name'] ?? 'No Name',
      photo: json['photo'],
      phone: json['phone'] as String?,
      service_id: json['service_id'],
      shop_id: json['shop_id'] ?? 0,
      isService: true,
      view_id: json['user_id'],
      user_called: json['user_called'],
      user_viewed: json['user_viewed'],
      days_since_creation: json['days_since_creation'],
      distance: json['distance'],
      call_status: json['call_status'],
      lastSeen: json['last_seen'] ?? '',
      lastCalled: json['last_called'] ?? '',
      sub_type: json['sub_type'],
    );
  }
}

class UserFetchResult {
  final List<UserDetail> users;
  final String? message;
  final bool locationAvailable;
  final bool hasMore;

  UserFetchResult(this.users,
      {this.message,
      required this.locationAvailable,
      required this.hasMore});
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

class ServiceFavorite extends StatefulWidget {
  final String cat_id;
  final String category_name;
  final String userPhone;

  ServiceFavorite({
    required this.cat_id,
    required this.category_name,
    required this.userPhone,
  });

  @override
  _ServiceFavoriteState createState() => _ServiceFavoriteState();
}

class _ServiceFavoriteState extends State<ServiceFavorite> with RouteAware {
  final _searchController = TextEditingController();
  String _query = '';
  Timer? _debounce;

  // Pagination — unchanged
  int _servicePage = 1;
  final int _limit = 10;
  int _shopPage = 1;
  bool _serviceHasMore = true;
  bool _shopHasMore = true;
  bool _isLoadingMore = false;

  late final ScrollController _scrollController = ScrollController();

  List<UserDetail> combinedUsers = [];
  bool locationAvailable = true;
  String sortBy = 'most_called';
  bool isLoading = true;

  List<UserDetail> get _visibleUsers {
    if (_query.trim().isEmpty) return combinedUsers;
    final q = _query.toLowerCase();
    return combinedUsers
        .where((u) => u.business_name.toLowerCase().contains(q))
        .toList();
  }

  // ── Sort options metadata ────────────────────────────────────────────────

  static const _sortOptions = [
    {'value': 'most_called', 'label': 'সর্বাধিক কল',  'icon': Icons.phone_rounded},
    {'value': 'most_viewed', 'label': 'সর্বাধিক দেখা', 'icon': Icons.visibility_rounded},
    {'value': 'recent',      'label': 'সাম্প্রতিক',    'icon': Icons.schedule_rounded},
    {'value': 'nearby',      'label': 'কাছাকাছি',      'icon': Icons.near_me_rounded},
  ];

  // ── Lifecycle — unchanged ────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    fetchData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    fetchData();
  }

  // ── Data fetching — unchanged ────────────────────────────────────────────

  void _onScroll() {
    if (_isLoadingMore || !mounted) return;
    if (_scrollController.position.maxScrollExtent -
            _scrollController.position.pixels <=
        200) {
      _loadMoreIfNeeded();
    }
  }

  void _loadMoreIfNeeded() async {
    if (_isLoadingMore) return;
    if (!(_serviceHasMore || _shopHasMore)) return;

    setState(() => _isLoadingMore = true);

    if (_serviceHasMore) {
      final res = await fetchUserDetails(
          widget.cat_id, 'service', sortBy,
          page: _servicePage + 1);
      if (res.users.isNotEmpty) {
        setState(() {
          combinedUsers.addAll(res.users);
          _servicePage += 1;
          _serviceHasMore = res.hasMore;
        });
      } else {
        setState(() => _serviceHasMore = false);
      }
    }

    if (_shopHasMore) {
      final res = await fetchUserDetails(widget.cat_id, 'shop', sortBy,
          page: _shopPage + 1);
      if (res.users.isNotEmpty) {
        setState(() {
          combinedUsers.addAll(res.users);
          _shopPage += 1;
          _shopHasMore = res.hasMore;
        });
      } else {
        setState(() => _shopHasMore = false);
      }
    }

    setState(() => _isLoadingMore = false);
  }

  void fetchData() async {
    setState(() => isLoading = true);

    final serviceRes =
        await fetchUserDetails(widget.cat_id, 'service', sortBy, page: 1);
    final shopRes =
        await fetchUserDetails(widget.cat_id, 'shop', sortBy, page: 1);

    setState(() {
      combinedUsers = [...serviceRes.users, ...shopRes.users];
      locationAvailable =
          serviceRes.locationAvailable || shopRes.locationAvailable;
      _serviceHasMore = serviceRes.hasMore;
      _shopHasMore = shopRes.hasMore;
      _servicePage = serviceRes.users.isNotEmpty ? 1 : 0;
      _shopPage = shopRes.users.isNotEmpty ? 1 : 0;
      isLoading = false;
    });
  }

  void fetchInitialData() {
    _servicePage = 1;
    _shopPage = 1;
    _serviceHasMore = true;
    _shopHasMore = true;
    combinedUsers = [];
    fetchData();
  }

  Future<UserFetchResult> fetchUserDetails(
      String cat_id, String dataType, String sortBy,
      {int page = 1}) async {
    String userLocation = '';
    bool locAvailable = true;
    final userId = await Config.getLoggedInUser();

    if (sortBy == 'nearby') {
      final locResp =
          await Config.apiGet('/get_user_location?user_id=$userId', context);
      if (locResp != null && locResp.statusCode == 200) {
        final locData = jsonDecode(locResp.body);
        if (locData.containsKey('location_string')) {
          userLocation = locData['location_string'];
        } else {
          locAvailable = false;
        }
      } else {
        locAvailable = false;
      }
      if (!locAvailable) {
        return UserFetchResult([],
            locationAvailable: false, hasMore: false);
      }
    }

    final url =
        '/get_data_by_category?cat_id=$cat_id&data_type=$dataType&sort_by=$sortBy'
        '${sortBy == 'nearby' && userLocation.isNotEmpty ? '&user_location=$userLocation' : ''}'
        '&user_id=$userId&page=$page';

    try {
      final response = await Config.apiGet(url, context);
      if (response != null && response.statusCode == 200) {
        final jsonResp = json.decode(response.body);
        final users = jsonResp['${dataType}_information'] != null
            ? (jsonResp['${dataType}_information'] as List)
                .map((d) => UserDetail.fromJson(d))
                .toList()
            : <UserDetail>[];
        return UserFetchResult(users,
            locationAvailable: locAvailable, hasMore: users.length == _limit);
      }
      return UserFetchResult([],
          locationAvailable: locAvailable, hasMore: false);
    } catch (e) {
      return UserFetchResult([],
          locationAvailable: locAvailable, hasMore: false);
    }
  }

  void updateSorting(String newSortBy) {
    if (sortBy != newSortBy) {
      setState(() => sortBy = newSortBy);
      fetchInitialData();
    }
  }

  void handleAction(int userId, String actionType, int detailPostId) async {
    final svc = NotificationService();
    await svc.sendNotificationWithLoggedInUser(
        userId, actionType, detailPostId, context);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      // Fix: plain Scaffold instead of BaseScaffold.
      // BaseScaffold injected its own CustomBottomNavigation — when pushed
      // on top of NavigationScreen (which already has a bottom nav), this
      // produced two stacked navigation bars.
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFF),
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildSortBar(),
            _buildSearchField(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF111827),
      elevation: 0,
      surfaceTintColor: Colors.white,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 20, color: Color(0xFF111827)),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.category_name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          if (!isLoading)
            Text(
              '${_visibleUsers.length}জন বিশেষজ্ঞ পাওয়া গেছে',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFF0F3FA)),
      ),
    );
  }

  // ── Sort bar ──────────────────────────────────────────────────────────────

  Widget _buildSortBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _sortOptions.map((opt) {
            final val = opt['value'] as String;
            final label = opt['label'] as String;
            final icon = opt['icon'] as IconData;
            final selected = sortBy == val;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF1A56DB)
                      : const Color(0xFFF5F7FF),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF1A56DB)
                        : const Color(0xFFE5EAF5),
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1A56DB)
                                .withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          )
                        ]
                      : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(22),
                    onTap: () => updateSorting(val),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 15,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Search field ──────────────────────────────────────────────────────────

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F7FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5EAF5)),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) {
            _debounce?.cancel();
            _debounce = Timer(
              const Duration(milliseconds: 200),
              () => setState(() => _query = val),
            );
          },
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF111827),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'নাম দিয়ে খুঁজুন...',
            hintStyle: const TextStyle(
              color: Color(0xFFADB5C7),
              fontSize: 14,
            ),
            prefixIcon: const Icon(Icons.search_rounded,
                color: Color(0xFF1A56DB), size: 20),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded,
                        color: Color(0xFFADB5C7), size: 18),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 13),
          ),
        ),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1A56DB)),
      );
    }

    if (_visibleUsers.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: const Color(0xFF1A56DB),
      onRefresh: () async => fetchInitialData(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
        itemCount: _visibleUsers.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (ctx, index) {
          if (index >= _visibleUsers.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF1A56DB), strokeWidth: 2.5),
              ),
            );
          }
          return _buildUserCard(_visibleUsers[index]);
        },
      ),
    );
  }

  // ── User card ─────────────────────────────────────────────────────────────

  Widget _buildUserCard(UserDetail user) {
    // Parse timestamps — unchanged logic
    DateTime? lastSeenDt;
    DateTime? lastCalledDt;
    try {
      if (user.lastSeen.isNotEmpty) {
        lastSeenDt =
            DateFormat("EEE dd MMM yyyy HH:mm:ss").parse(user.lastSeen);
      }
      if (user.lastCalled.isNotEmpty) {
        lastCalledDt =
            DateFormat("EEE dd MMM yyyy HH:mm:ss").parse(user.lastCalled);
      }
    } catch (_) {}

    final now = DateTime.now();
    final seenRecently =
        lastSeenDt != null && now.difference(lastSeenDt).inDays <= 7;
    final calledRecently =
        lastCalledDt != null && now.difference(lastCalledDt).inDays <= 7;
    final wasInteracted = seenRecently || calledRecently;

    final accentColor = wasInteracted
        ? const Color(0xFFF97316)
        : const Color(0xFF1A56DB);

    final bool isActive =
        (user.call_status ?? '').toLowerCase() == 'active';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            handleAction(user.view_id, 'view', 0);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdvertScreen(
                  userId: user.service_id.toString(),
                  isService: user.isService,
                  advertData: AdvertData(
                    userId: user.service_id.toString(),
                    isService: user.isService,
                    additionalData: user.service_id != 0
                        ? {'service_id': user.service_id}
                        : user.shop_id != 0
                            ? {'shop_id': user.shop_id}
                            : {'user_only': user.view_id.toString()},
                  ),
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border(
                left: BorderSide(color: accentColor, width: 4),
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Photo + verified badge ──────────────────────────────
                Stack(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: accentColor.withValues(alpha: 0.25),
                            width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: user.photo.isNotEmpty
                            ? Image.network(
                                user.photo,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _buildNoImage(),
                              )
                            : _buildNoImage(),
                      ),
                    ),
                    if (user.sub_type != null)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: user.sub_type == 'paid'
                                ? [
                                    BoxShadow(
                                      color: Colors.blueAccent
                                          .withValues(alpha: 0.5),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    )
                                  ]
                                : [],
                          ),
                          padding: const EdgeInsets.all(3),
                          child: Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: user.sub_type == 'paid'
                                ? Colors.blueAccent
                                : Colors.grey.shade400,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 12),

                // ── Details ─────────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name row + status badge
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              user.business_name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF111827),
                                height: 1.2,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Status pill
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.green.shade50
                                  : const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: isActive
                                  ? [
                                      BoxShadow(
                                        color: Colors.greenAccent
                                            .withValues(alpha: 0.4),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : [],
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
                                        ? Colors.green
                                        : Colors.grey.shade400,
                                    boxShadow: isActive
                                        ? [
                                            BoxShadow(
                                              color: Colors.greenAccent
                                                  .withValues(alpha: 0.8),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            )
                                          ]
                                        : [],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isActive ? 'সক্রিয়' : 'অফলাইন',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: isActive
                                        ? Colors.green.shade700
                                        : Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Category
                      Row(
                        children: [
                          Icon(Icons.category_rounded,
                              size: 12,
                              color: accentColor.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              user.category,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Sort-specific stat + timestamps row
                      Row(
                        children: [
                          // Sort stat chip
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  accentColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: _getSortChipContent(user, accentColor),
                          ),
                          const Spacer(),
                          // Last interaction timestamps
                          if (user.lastSeen.isNotEmpty ||
                              user.lastCalled.isNotEmpty)
                            _buildTimestamps(user),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Sort stat chip content ────────────────────────────────────────────────

  Widget _getSortChipContent(UserDetail user, Color color) {
    Widget text(String t) => Text(
          t,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        );
    Widget icon(IconData i) =>
        Icon(i, size: 11, color: color);

    switch (sortBy) {
      case 'most_called':
        return Row(mainAxisSize: MainAxisSize.min, children: [
          icon(Icons.phone_rounded),
          const SizedBox(width: 4),
          text(user.user_called == '0'
              ? 'কোনো কল নেই'
              : '${Config.formatLargeNumber(int.parse(user.user_called))} কল'),
        ]);
      case 'most_viewed':
        return Row(mainAxisSize: MainAxisSize.min, children: [
          icon(Icons.visibility_rounded),
          const SizedBox(width: 4),
          text(user.user_viewed == '0'
              ? 'কোনো ভিউ নেই'
              : '${Config.formatLargeNumber(int.parse(user.user_viewed))} ভিউ'),
        ]);
      case 'recent':
        return Row(mainAxisSize: MainAxisSize.min, children: [
          icon(Icons.schedule_rounded),
          const SizedBox(width: 4),
          text(Config.getTimeDifference(user.days_since_creation)),
        ]);
      case 'nearby':
        return Row(mainAxisSize: MainAxisSize.min, children: [
          icon(Icons.near_me_rounded),
          const SizedBox(width: 4),
          text(user.distance != null && user.distance!.isNotEmpty
              ? user.distance!
              : 'দূরত্ব অজানা'),
        ]);
      default:
        return const SizedBox.shrink();
    }
  }

  // ── Timestamps ────────────────────────────────────────────────────────────

  Widget _buildTimestamps(UserDetail user) {
    final seenStr = Config.getTimeDifference(user.lastSeen,
        fallback: '');
    final calledStr = Config.getTimeDifference(user.lastCalled,
        fallback: '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (seenStr.isNotEmpty)
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.visibility_outlined,
                size: 10, color: Color(0xFFADB5C7)),
            const SizedBox(width: 3),
            Text(seenStr,
                style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFADB5C7),
                    fontWeight: FontWeight.w500)),
          ]),
        if (calledStr.isNotEmpty) ...[
          const SizedBox(height: 2),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.phone_outlined,
                size: 10, color: Color(0xFFADB5C7)),
            const SizedBox(width: 3),
            Text(calledStr,
                style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFADB5C7),
                    fontWeight: FontWeight.w500)),
          ]),
        ],
      ],
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    final isNearbyNoLoc = sortBy == 'nearby' && !locationAvailable;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFEEF2FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNearbyNoLoc
                    ? Icons.location_off_rounded
                    : Icons.search_off_rounded,
                size: 38,
                color: const Color(0xFF1A56DB),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isNearbyNoLoc
                  ? 'লোকেশন অ্যাক্সেস নেই'
                  : 'কোনো তথ্য পাওয়া যায়নি',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isNearbyNoLoc
                  ? 'কাছাকাছি ফলাফল দেখতে লোকেশন অনুমতি দিন।'
                  : 'এই বিভাগে এখনো কোনো তথ্য যোগ হয়নি।\nঅন্য ফিল্টার দিয়ে চেষ্টা করুন।',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Photo fallback ────────────────────────────────────────────────────────

  Widget _buildNoImage() {
    return Container(
      color: const Color(0xFFEEF2FF),
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          color: Color(0xFF1A56DB),
          size: 30,
        ),
      ),
    );
  }
}
