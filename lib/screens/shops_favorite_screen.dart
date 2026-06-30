import 'dart:async';
import 'dart:convert';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/main.dart';
import 'package:aaram_bd/screens/advert_screen.dart';
import 'package:aaram_bd/services/app_location.dart';
import 'package:aaram_bd/widgets/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
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
  final int shop_id;
  final int service_id;
  final bool is_service;
  final int view_id;
  final String user_called;
  final String user_viewed;
  final String days_since_creation;
  final String? distance;
  final double? distanceKm;
  final double? lat;
  final double? lon;
  final String? call_status;
  final String? sub_type;
  String lastSeen = '';
  String lastCalled = '';

  UserDetail({
    required this.address,
    required this.business_name,
    required this.category,
    required this.phone,
    required this.photo,
    required this.shop_id,
    required this.is_service,
    required this.service_id,
    required this.user_called,
    required this.user_viewed,
    required this.days_since_creation,
    required this.view_id,
    required this.distance,
    required this.call_status,
    required this.lastSeen,
    required this.lastCalled,
    required this.sub_type,
    this.distanceKm,
    this.lat,
    this.lon,
  });

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    return UserDetail(
      address: json['location'] ?? 'No Address',
      category: json['cat_name'] ?? 'No Category',
      business_name: json['name'] ?? 'No Name',
      phone: json['phone'] as String?,
      photo: json['photo'],
      shop_id: json['shop_id'],
      service_id: json['service_id'] ?? 0,
      view_id: json['user_id'],
      is_service: false,
      user_called: json['user_called'],
      user_viewed: json['user_viewed'],
      days_since_creation: json['days_since_creation'],
      distance: json['distance'],
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
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

class ShopsFavorite extends StatefulWidget {
  final String cat_id;
  final String categoryName;
  final String userPhone;

  ShopsFavorite({
    required this.cat_id,
    required this.categoryName,
    required this.userPhone,
  });

  @override
  _ShopsFavoriteState createState() => _ShopsFavoriteState();
}

class _ShopsFavoriteState extends State<ShopsFavorite> with RouteAware {
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  String _query = '';
  Timer? _debounce;
  bool _searchFocused = false;

  // Pagination
  int _page = 1;
  final int _limit = 10;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  late final ScrollController _scrollController = ScrollController();

  List<UserDetail> combinedUsers = [];
  bool locationAvailable = true;
  String sortBy = 'nearby';
  bool isLoading = false;
  bool _locationReady = false;
  bool _locationLoading = false;

  static const Color _brand = Color(0xFF1A56DB);
  static const Color _bg = Color(0xFFF3F7FF);

  static const _sortOptions = [
    {'value': 'nearby',      'label': 'Nearby',      'icon': Icons.near_me_rounded},
    {'value': 'most_called', 'label': 'Most Called', 'icon': Icons.phone_rounded},
    {'value': 'most_viewed', 'label': 'Most Viewed', 'icon': Icons.visibility_rounded},
    {'value': 'recent',      'label': 'Recent',      'icon': Icons.schedule_rounded},
  ];

  List<UserDetail> get _visibleUsers {
    if (_query.trim().isEmpty) return combinedUsers;
    final q = _query.toLowerCase();
    return combinedUsers
        .where((u) => u.business_name.toLowerCase().contains(q))
        .toList();
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchFocus.addListener(() {
      if (mounted) setState(() => _searchFocused = _searchFocus.hasFocus);
    });
    _bootstrap();
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
    _searchFocus.dispose();
    _debounce?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    fetchData();
  }

  // ── Data fetching ────────────────────────────────────────────────────────

  Future<void> _bootstrap() async {
    setState(() => _locationLoading = true);
    final ok = await AppLocation().init();
    if (mounted) {
      setState(() { _locationReady = ok; _locationLoading = false; });
      fetchData();
    }
  }

  void _onScroll() {
    if (_isLoadingMore || !mounted) return;
    if (_scrollController.position.maxScrollExtent -
            _scrollController.position.pixels <=
        200) {
      _loadMoreIfNeeded();
    }
  }

  void _loadMoreIfNeeded() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    final res = await fetchUserDetails(widget.cat_id, 'shop', sortBy,
        page: _page + 1);
    if (res.users.isNotEmpty) {
      setState(() {
        combinedUsers.addAll(res.users);
        _page += 1;
        _hasMore = res.hasMore;
      });
    } else {
      setState(() => _hasMore = false);
    }

    setState(() => _isLoadingMore = false);
  }

  void fetchData() async {
    setState(() => isLoading = true);

    final res =
        await fetchUserDetails(widget.cat_id, 'shop', sortBy, page: 1);

    setState(() {
      combinedUsers = res.users;
      locationAvailable = res.locationAvailable;
      _hasMore = res.hasMore;
      _page = res.users.isNotEmpty ? 1 : 0;
      isLoading = false;
    });
  }

  void fetchInitialData() {
    _page = 1;
    _hasMore = true;
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
      final lat = AppLocation().lat;
      final lon = AppLocation().lon;
      if (lat == null || lon == null) {
        return UserFetchResult([], locationAvailable: false, hasMore: false);
      }
      userLocation = '$lat,$lon';
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
      child: Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            if (sortBy != 'nearby') _buildSearchField(),
            _buildSortBar(),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    final count = _visibleUsers.length;
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
            widget.categoryName,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          if (!isLoading)
            Text(
              '$count shop${count != 1 ? 's' : ''} found',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
      actions: [
        if (_locationReady && sortBy == 'nearby')
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _PulseDot(color: const Color(0xFF22C55E)),
              const SizedBox(width: 5),
              const Text('Live', style: TextStyle(
                  fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
            ]),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFF0F3FA)),
      ),
    );
  }

  // ── Search field ──────────────────────────────────────────────────────────

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _searchFocused ? Colors.white : const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _searchFocused ? _brand : const Color(0xFFDDE3F5),
            width: _searchFocused ? 1.8 : 1.0,
          ),
          boxShadow: _searchFocused
              ? [
                  BoxShadow(
                    color: _brand.withValues(alpha: 0.18),
                    blurRadius: 18,
                    offset: const Offset(0, 5),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          onChanged: (val) {
            _debounce?.cancel();
            _debounce = Timer(
              const Duration(milliseconds: 200),
              () => setState(() => _query = val),
            );
          },
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF111827),
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Search shops by name...',
            hintStyle: TextStyle(
              color: _searchFocused
                  ? const Color(0xFFADB5C7)
                  : const Color(0xFFB4BBC9),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.search_rounded,
                key: ValueKey(_searchFocused),
                color: _searchFocused ? _brand : const Color(0xFFADB5C7),
                size: 22,
              ),
            ),
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
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  // ── Sort bar ──────────────────────────────────────────────────────────────

  Widget _buildSortBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
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
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [Color(0xFF1A56DB), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selected ? null : const Color(0xFFF5F7FF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF1A56DB)
                        : const Color(0xFFE0E7F3),
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1A56DB)
                                .withValues(alpha: 0.32),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => updateSorting(val),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            size: 14,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF6B7280),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF6B7280),
                              letterSpacing: 0.2,
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

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody() {
    if (sortBy == 'nearby') {
      if (_locationLoading) {
        return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: Color(0xFF1A56DB), strokeWidth: 2),
          const SizedBox(height: 14),
          const Text('Getting your location…',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        ]));
      }
      if (!_locationReady) return _buildLocationError();
      if (isLoading) return const Center(
          child: CircularProgressIndicator(color: Color(0xFF1A56DB), strokeWidth: 2));
      return _MapView(
        services: _visibleUsers,
        userLat: AppLocation().lat!,
        userLon: AppLocation().lon!,
        accent: _brand,
        onConnect: _navigateToProfile,
        onRefresh: () async {
          final ok = await AppLocation().init();
          if (mounted) setState(() => _locationReady = ok);
          fetchInitialData();
        },
      );
    }

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
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
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
          return _buildShopCard(_visibleUsers[index]);
        },
      ),
    );
  }

  // ── Shop visiting card ────────────────────────────────────────────────────

  bool _wasInteracted(UserDetail user) {
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
    return seenRecently || calledRecently;
  }

  Widget _buildShopCard(UserDetail user) {
    final bool isActive = (user.call_status ?? '').toLowerCase() == 'active';
    final bool contacted = _wasInteracted(user);
    const Color accent = Color(0xFF1A56DB);

    void navigate() {
      handleAction(user.view_id, 'view', 0);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AdvertScreen(
            userId: user.service_id.toString(),
            isService: user.is_service,
            advertData: AdvertData(
              userId: user.service_id.toString(),
              isService: user.is_service,
              additionalData: user.service_id != 0
                  ? {'service_id': user.service_id}
                  : user.shop_id != 0
                      ? {'shop_id': user.shop_id}
                      : {'user_only': user.view_id.toString()},
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: accent, width: 5)),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.10),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: navigate,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top row: photo + info ──────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPhoto(user, accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name + status pill
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    user.business_name,
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF0F172A),
                                      height: 1.2,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                _buildStatusPill(isActive),
                              ],
                            ),
                            const SizedBox(height: 5),
                            // Category
                            Row(
                              children: [
                                Icon(Icons.storefront_rounded,
                                    size: 12,
                                    color: accent.withValues(alpha: 0.75)),
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
                            // Address / location
                            if (user.address.isNotEmpty &&
                                user.address != 'No Address') ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.location_on_rounded,
                                      size: 12,
                                      color: Colors.grey.shade400),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      user.address,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade500,
                                        fontWeight: FontWeight.w400,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),
                  Container(height: 1, color: const Color(0xFFF0F3FA)),
                  const SizedBox(height: 10),

                  // ── Bottom row: stat chip + visited chip + Visit button ─
                  Row(
                    children: [
                      _buildStatChip(user, accent),
                      if (contacted) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A56DB),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_circle_outline_rounded, size: 11, color: Colors.white),
                            SizedBox(width: 3),
                            Text('Visited', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
                          ]),
                        ),
                      ],
                      const Spacer(),
                      GestureDetector(
                        onTap: navigate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accent,
                                accent.withValues(alpha: 0.82),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.32),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Visit',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded,
                                  size: 13, color: Colors.white),
                            ],
                          ),
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
  }

  // ── Photo + verified badge ────────────────────────────────────────────────

  Widget _buildPhoto(UserDetail user, Color accent) {
    return Stack(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: accent.withValues(alpha: 0.28), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.14),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: user.photo.isNotEmpty
                ? Image.network(
                    user.photo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildNoImage(),
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
                          color: Colors.blueAccent.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              padding: const EdgeInsets.all(2.5),
              child: Icon(
                Icons.verified_rounded,
                size: 15,
                color: user.sub_type == 'paid'
                    ? Colors.blueAccent
                    : Colors.grey.shade400,
              ),
            ),
          ),
      ],
    );
  }

  // ── Status pill ───────────────────────────────────────────────────────────

  Widget _buildStatusPill(bool isActive) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade50 : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.greenAccent.withValues(alpha: 0.35),
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
              color: isActive ? Colors.green : Colors.grey.shade400,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: Colors.greenAccent.withValues(alpha: 0.8),
                        blurRadius: 4,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
          ),
          const SizedBox(width: 4),
          Text(
            isActive ? 'Open' : 'Closed',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isActive ? Colors.green.shade700 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Stat chip ─────────────────────────────────────────────────────────────

  Widget _buildStatChip(UserDetail user, Color color) {
    Widget txt(String t) => Text(
          t,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color),
        );
    Widget ico(IconData i) => Icon(i, size: 11, color: color);

    Widget content;
    switch (sortBy) {
      case 'most_called':
        content = Row(mainAxisSize: MainAxisSize.min, children: [
          ico(Icons.phone_rounded),
          const SizedBox(width: 4),
          txt(user.user_called == '0'
              ? 'No calls'
              : '${Config.formatLargeNumber(int.parse(user.user_called))} calls'),
        ]);
        break;
      case 'most_viewed':
        content = Row(mainAxisSize: MainAxisSize.min, children: [
          ico(Icons.visibility_rounded),
          const SizedBox(width: 4),
          txt(user.user_viewed == '0'
              ? 'No views'
              : '${Config.formatLargeNumber(int.parse(user.user_viewed))} views'),
        ]);
        break;
      case 'recent':
        content = Row(mainAxisSize: MainAxisSize.min, children: [
          ico(Icons.schedule_rounded),
          const SizedBox(width: 4),
          txt(Config.getTimeDifference(user.days_since_creation)),
        ]);
        break;
      case 'nearby':
        content = Row(mainAxisSize: MainAxisSize.min, children: [
          ico(Icons.near_me_rounded),
          const SizedBox(width: 4),
          txt(user.distance != null && user.distance!.isNotEmpty
              ? user.distance!
              : 'Unknown dist.'),
        ]);
        break;
      default:
        content = const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: content,
    );
  }

  // ── Timestamps ────────────────────────────────────────────────────────────

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
                    : Icons.storefront_outlined,
                size: 38,
                color: const Color(0xFF1A56DB),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isNearbyNoLoc ? 'Location Access Denied' : 'No shops found',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isNearbyNoLoc
                  ? 'Allow location access to see nearby results.'
                  : 'No shops have been added in this category yet.\nTry a different filter.',
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
          Icons.storefront_rounded,
          color: Color(0xFF1A56DB),
          size: 28,
        ),
      ),
    );
  }

  // ── Location error ────────────────────────────────────────────────────────

  Widget _buildLocationError() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.location_off_rounded, size: 52,
            color: _brand.withValues(alpha: 0.4)),
        const SizedBox(height: 16),
        const Text('Location Access Needed',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: Color(0xFF111827))),
        const SizedBox(height: 8),
        const Text('Allow location access to use the map view.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: _bootstrap,
          icon: const Icon(Icons.my_location_rounded, size: 16),
          label: const Text('Try Again'),
          style: ElevatedButton.styleFrom(
              backgroundColor: _brand, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
        ),
      ]),
    ));
  }

  // ── Navigate to shop profile ──────────────────────────────────────────────

  void _navigateToProfile(UserDetail user) {
    handleAction(user.view_id, 'view', 0);
    Navigator.push(context, MaterialPageRoute(builder: (_) => AdvertScreen(
      userId: user.service_id.toString(),
      isService: user.is_service,
      advertData: AdvertData(
        userId: user.service_id.toString(),
        isService: user.is_service,
        additionalData: user.service_id != 0
            ? {'service_id': user.service_id}
            : user.shop_id != 0
                ? {'shop_id': user.shop_id}
                : {'user_only': user.view_id.toString()},
      ),
    )));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Real map view  (flutter_map + OpenStreetMap)
// ─────────────────────────────────────────────────────────────────────────────

class _MapView extends StatefulWidget {
  final List<UserDetail> services;
  final double userLat;
  final double userLon;
  final Color accent;
  final void Function(UserDetail) onConnect;
  final Future<void> Function() onRefresh;

  const _MapView({
    required this.services,
    required this.userLat,
    required this.userLon,
    required this.accent,
    required this.onConnect,
    required this.onRefresh,
  });

  @override
  State<_MapView> createState() => _MapViewState();
}

class _MapViewState extends State<_MapView> with SingleTickerProviderStateMixin {
  UserDetail? _selected;
  final MapController _mapController = MapController();
  late AnimationController _pulseCtrl;

  bool _searchOpen = false;
  String _mapQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _mapController.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _closeSearch() {
    _searchCtrl.clear();
    _searchFocus.unfocus();
    setState(() { _searchOpen = false; _mapQuery = ''; });
  }

  static Color _rimColor(double? distKm) {
    if (distKm == null) return const Color(0xFF3B82F6);
    if (distKm < 2)    return const Color(0xFFEF4444);
    if (distKm < 5)    return const Color(0xFFF97316);
    if (distKm < 15)   return const Color(0xFF3B82F6);
    return const Color(0xFF8B5CF6);
  }

  @override
  Widget build(BuildContext context) {
    final mappable = widget.services
        .where((s) => s.lat != null && s.lon != null)
        .toList();
    final noGps  = widget.services.length - mappable.length;
    final userLL = LatLng(widget.userLat, widget.userLon);

    final searchResults = _mapQuery.trim().isEmpty
        ? <UserDetail>[]
        : mappable
            .where((s) => s.business_name
                .toLowerCase()
                .contains(_mapQuery.toLowerCase()))
            .toList();
    final visibleMappable = _mapQuery.trim().isEmpty ? mappable : searchResults;

    return Column(children: [
      // ── Map with floating search ────────────────────────────────────────
      Expanded(
        child: Stack(children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userLL,
              initialZoom: 13.0,
              minZoom: 4.0,
              maxZoom: 19.0,
              onTap: (_, __) {
                if (_searchOpen) _closeSearch();
                setState(() => _selected = null);
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.aarambd.android',
              ),
              MarkerLayer(
                markers: [
                  // Shop pins (filtered by search query)
                  ...visibleMappable.map((s) {
                    final rim = _rimColor(s.distanceKm);
                    final sel = _selected == s;
                    return Marker(
                      point: LatLng(s.lat!, s.lon!),
                      width: 56,
                      height: 72,
                      alignment: Alignment.bottomCenter,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _selected = sel ? null : s);
                          if (!sel) {
                            _mapController.move(LatLng(s.lat!, s.lon!), 15.0);
                          }
                          if (_searchOpen) _closeSearch();
                        },
                        child: _ShopPinWidget(
                            service: s, rimColor: rim, selected: sel),
                      ),
                    );
                  }),

                  // User location pulsing dot
                  Marker(
                    point: userLL,
                    width: 52,
                    height: 52,
                    child: AnimatedBuilder(
                      animation: _pulseCtrl,
                      builder: (_, __) =>
                          _UserDot(accent: widget.accent, pulse: _pulseCtrl.value),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Floating search bar ─────────────────────────────────────────
          Positioned(
            top: 14, left: 14, right: 14,
            child: Material(
              color: Colors.transparent,
              elevation: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: !_searchOpen
                    ? () {
                        setState(() => _searchOpen = true);
                        Future.delayed(const Duration(milliseconds: 80),
                            () => _searchFocus.requestFocus());
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: _searchOpen ? 0.18 : 0.13),
                        blurRadius: _searchOpen ? 28 : 18,
                        spreadRadius: _searchOpen ? 2 : 0,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border: Border.all(
                      color: _searchOpen
                          ? widget.accent.withValues(alpha: 0.50)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(children: [
                    const SizedBox(width: 16),
                    Icon(Icons.search_rounded, size: 22,
                        color: _searchOpen ? widget.accent : const Color(0xFF9CA3AF)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _searchOpen
                          ? TextField(
                              controller: _searchCtrl,
                              focusNode: _searchFocus,
                              onChanged: (v) => setState(() => _mapQuery = v),
                              style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF111827),
                                  fontWeight: FontWeight.w500),
                              decoration: const InputDecoration(
                                hintText: 'Search shops on map…',
                                hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.w400),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            )
                          : const Text('Search shops on map…',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFB0B8C9),
                                  fontWeight: FontWeight.w400)),
                    ),
                    if (_searchOpen && _mapQuery.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: Color(0xFF9CA3AF)),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _mapQuery = '');
                        },
                      )
                    else if (_searchOpen)
                      TextButton(
                        onPressed: _closeSearch,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text('Cancel',
                            style: TextStyle(
                                fontSize: 13,
                                color: widget.accent,
                                fontWeight: FontWeight.w700)),
                      )
                    else
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: widget.accent.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.place_rounded, size: 13, color: widget.accent),
                          const SizedBox(width: 4),
                          Text('${mappable.length}',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: widget.accent,
                                  fontWeight: FontWeight.w800)),
                        ]),
                      ),
                  ]),
                ),
              ),
            ),
          ),

          // ── GPS / Refresh pill ──────────────────────────────────────────
          if (!_searchOpen)
            Positioned(
              top: 80, left: 14,
              child: GestureDetector(
                onTap: widget.onRefresh,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8, offset: const Offset(0, 2))],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 7, height: 7,
                        decoration: const BoxDecoration(
                            color: Color(0xFF22C55E), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(
                      noGps > 0
                          ? 'GPS active  •  $noGps no-GPS'
                          : 'GPS active',
                      style: const TextStyle(fontSize: 11,
                          color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.refresh_rounded, size: 13, color: widget.accent),
                    const SizedBox(width: 3),
                    Text('Refresh', style: TextStyle(
                        fontSize: 11, color: widget.accent,
                        fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ),

          // ── Search results dropdown ────────────────────────────────────
          if (_searchOpen && _mapQuery.trim().isNotEmpty)
            Positioned(
              top: 78, left: 14, right: 14,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 18, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: searchResults.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 18),
                          child: Center(
                            child: Text('No shops found',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.w500)),
                          ))
                      : ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: searchResults.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 42),
                          itemBuilder: (_, i) {
                            final s   = searchResults[i];
                            final rim = _rimColor(s.distanceKm);
                            final dist = s.distanceKm;
                            final distStr = dist == null
                                ? null
                                : dist < 1
                                    ? '${(dist * 1000).round()}m'
                                    : '${dist.toStringAsFixed(1)}km';
                            return InkWell(
                              borderRadius: i == 0
                                  ? const BorderRadius.vertical(
                                      top: Radius.circular(14))
                                  : i == searchResults.length - 1
                                      ? const BorderRadius.vertical(
                                          bottom: Radius.circular(14))
                                      : BorderRadius.zero,
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => _selected = s);
                                _mapController.move(
                                    LatLng(s.lat!, s.lon!), 15.0);
                                _closeSearch();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                child: Row(children: [
                                  Container(
                                    width: 10, height: 10,
                                    decoration: BoxDecoration(
                                        color: rim, shape: BoxShape.circle),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(s.business_name,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF111827)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        if (s.address.isNotEmpty &&
                                            s.address != 'No Address')
                                          Text(s.address,
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF9CA3AF)),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                  if (distStr != null) ...[
                                    const SizedBox(width: 8),
                                    Text(distStr,
                                        style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: rim)),
                                  ],
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_forward_ios_rounded,
                                      size: 11,
                                      color: Colors.grey.shade300),
                                ]),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),

          // Center-on-me FAB
          Positioned(
            bottom: 16, right: 16,
            child: FloatingActionButton.small(
              heroTag: 'shopMapLocateMe',
              onPressed: () => _mapController.move(userLL, 14.0),
              backgroundColor: widget.accent,
              elevation: 6,
              child: const Icon(Icons.my_location_rounded,
                  color: Colors.white, size: 18),
            ),
          ),

          // OSM attribution
          Positioned(
            bottom: 4, left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('© OpenStreetMap contributors',
                  style: TextStyle(fontSize: 7.5, color: Color(0xFF374151))),
            ),
          ),
        ]),
      ),

      // ── Bottom profile panel ───────────────────────────────────────────
      _ProfilePanel(
        service:   _selected,
        accent:    widget.accent,
        onConnect: () => widget.onConnect(_selected!),
        onDismiss: () => setState(() => _selected = null),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shop map pin widget
// ─────────────────────────────────────────────────────────────────────────────

class _ShopPinWidget extends StatelessWidget {
  final UserDetail service;
  final Color      rimColor;
  final bool       selected;

  const _ShopPinWidget({
    required this.service,
    required this.rimColor,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = (service.call_status ?? '').toLowerCase() == 'active';
    final dist     = service.distanceKm;
    final distStr  = dist == null
        ? null
        : dist < 1
            ? '${(dist * 1000).round()}m'
            : '${dist.toStringAsFixed(1)}km';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Distance chip
        if (distStr != null)
          Container(
            margin: const EdgeInsets.only(bottom: 3),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: selected ? rimColor : rimColor.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(6),
              boxShadow: selected
                  ? [BoxShadow(color: rimColor.withValues(alpha: 0.45),
                        blurRadius: 6, offset: const Offset(0, 2))]
                  : [],
            ),
            child: Text(distStr, style: const TextStyle(
                fontSize: 8, fontWeight: FontWeight.w800,
                color: Colors.white, letterSpacing: 0.2)),
          ),

        // Circle photo + active dot
        Stack(clipBehavior: Clip.none, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 40, height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: selected ? rimColor : rimColor.withValues(alpha: 0.70),
                  width: selected ? 3.0 : 2.0),
              boxShadow: [
                BoxShadow(
                  color: rimColor.withValues(alpha: selected ? 0.55 : 0.20),
                  blurRadius: selected ? 14 : 6,
                  spreadRadius: selected ? 3 : 0,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: Stack(fit: StackFit.expand, children: [
                service.photo.isNotEmpty
                    ? Image.network(service.photo, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _fallback())
                    : _fallback(),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.5, -0.6),
                      radius: 0.75,
                      colors: [
                        Colors.white.withValues(alpha: 0.32),
                        Colors.transparent
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
          if (isActive)
            Positioned(
              top: 0, right: 0,
              child: Container(
                width: 11, height: 11,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [BoxShadow(
                      color: Colors.green.withValues(alpha: 0.45),
                      blurRadius: 4)],
                ),
              ),
            ),
        ]),

        // Pin tail
        CustomPaint(size: const Size(10, 8), painter: _PinTailPainter(rimColor)),
      ],
    );
  }

  Widget _fallback() => Container(
    color: rimColor.withValues(alpha: 0.15),
    child: Center(child: Icon(Icons.storefront_rounded,
        color: rimColor, size: 18)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
//  Triangular pin tail
// ─────────────────────────────────────────────────────────────────────────────

class _PinTailPainter extends CustomPainter {
  final Color color;
  const _PinTailPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PinTailPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pulsing user-location dot
// ─────────────────────────────────────────────────────────────────────────────

class _UserDot extends StatelessWidget {
  final Color  accent;
  final double pulse;
  const _UserDot({required this.accent, required this.pulse});

  @override
  Widget build(BuildContext context) {
    final ringSize = 26.0 + pulse * 20.0;
    return Stack(alignment: Alignment.center, children: [
      Opacity(
        opacity: (1 - pulse).clamp(0.0, 1.0),
        child: Container(
          width: ringSize, height: ringSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: accent.withValues(alpha: 0.45), width: 1.5),
          ),
        ),
      ),
      Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [BoxShadow(
              color: accent.withValues(alpha: 0.45),
              blurRadius: 10, spreadRadius: 1)],
        ),
        child: Center(
          child: Container(
            width: 7, height: 7,
            decoration: const BoxDecoration(
                color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bottom profile panel
// ─────────────────────────────────────────────────────────────────────────────

class _ProfilePanel extends StatelessWidget {
  final UserDetail?  service;
  final Color        accent;
  final VoidCallback onConnect;
  final VoidCallback onDismiss;

  const _ProfilePanel({
    required this.service,
    required this.accent,
    required this.onConnect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      height: service == null ? 60 : 170,
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: service == null
                ? const Color(0xFFE5E7EB)
                : accent.withValues(alpha: 0.30),
            width: service == null ? 1 : 1.5),
        boxShadow: [
          BoxShadow(
              color: (service != null ? accent : Colors.black)
                  .withValues(alpha: service != null ? 0.10 : 0.04),
              blurRadius: service != null ? 20 : 6,
              offset: const Offset(0, -4)),
        ],
      ),
      child: service == null ? _hint() : _card(service!),
    );
  }

  Widget _hint() {
    return Center(
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.touch_app_rounded, size: 17, color: Colors.grey.shade400),
        const SizedBox(width: 8),
        Text('Tap a pin to view shop details',
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _card(UserDetail s) {
    final isActive = (s.call_status ?? '').toLowerCase() == 'active';
    final views    = int.tryParse(s.user_viewed) ?? 0;
    final calls    = int.tryParse(s.user_called) ?? 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Expanded(
          child: GestureDetector(
            onTap: onConnect,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(children: [
                // Avatar
                Stack(children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: accent.withValues(alpha: 0.35), width: 2),
                      boxShadow: [BoxShadow(
                          color: accent.withValues(alpha: 0.18), blurRadius: 8)],
                    ),
                    child: ClipOval(
                      child: s.photo.isNotEmpty
                          ? Image.network(s.photo, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _avatarFallback(s))
                          : _avatarFallback(s),
                    ),
                  ),
                  if (isActive)
                    Positioned(bottom: 1, right: 1,
                      child: Container(width: 13, height: 13,
                          decoration: BoxDecoration(
                              color: const Color(0xFF22C55E),
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 1.5)))),
                ]),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(children: [
                      Expanded(child: Text(s.business_name,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A)))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: isActive
                                ? Colors.green.shade50
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(isActive ? 'Active' : 'Offline',
                            style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w700,
                                color: isActive
                                    ? Colors.green.shade700
                                    : Colors.grey.shade500)),
                      ),
                    ]),
                    const SizedBox(height: 3),
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(5)),
                        child: Text(s.category,
                            style: TextStyle(
                                fontSize: 10,
                                color: accent,
                                fontWeight: FontWeight.w700)),
                      ),
                      if (s.distance != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.near_me_rounded,
                            size: 10, color: Colors.grey.shade400),
                        const SizedBox(width: 2),
                        Text(s.distance!,
                            style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600)),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    if (s.address.isNotEmpty && s.address != 'No Address')
                      Row(children: [
                        Icon(Icons.location_on_rounded,
                            size: 10, color: Colors.grey.shade400),
                        const SizedBox(width: 2),
                        Expanded(child: Text(s.address,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade500))),
                      ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.visibility_outlined,
                          size: 10, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text(Config.formatLargeNumber(views),
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 10),
                      Icon(Icons.phone_outlined,
                          size: 10, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text(Config.formatLargeNumber(calls),
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('Tap to visit shop →',
                          style: TextStyle(
                              fontSize: 9.5,
                              color: accent.withValues(alpha: 0.60),
                              fontWeight: FontWeight.w700)),
                    ]),
                  ],
                )),
              ]),
            ),
          ),
        ),
        // Dismiss strip
        GestureDetector(
          onTap: onDismiss,
          child: Container(
            width: 40,
            color: const Color(0xFFF9FAFB),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade400),
              const SizedBox(height: 4),
              Text('close',
                  style: TextStyle(
                      fontSize: 8,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _avatarFallback(UserDetail s) {
    return Container(
      color: accent.withValues(alpha: 0.10),
      child: Center(child: Icon(Icons.storefront_rounded,
          color: accent, size: 22)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pulsing GPS dot in AppBar
// ─────────────────────────────────────────────────────────────────────────────

class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
                color: widget.color.withValues(alpha: 0.5 * _ctrl.value),
                blurRadius: 6, spreadRadius: 2)
          ],
        ),
      ),
    );
  }
}
