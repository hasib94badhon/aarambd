import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/main.dart';
import 'package:aaram_bd/screens/advert_screen.dart';
import 'package:aaram_bd/services/app_location.dart';
import 'package:aaram_bd/widgets/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

import 'package:intl/intl.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Model
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
  final double? distanceKm;
  final double? lat;
  final double? lon;
  final String? call_status;
  final String? sub_type;
  String lastSeen;
  String lastCalled;

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
    this.distanceKm,
    this.lat,
    this.lon,
    this.sub_type,
  });

  factory UserDetail.fromJson(Map<String, dynamic> json) {
    return UserDetail(
      address: json['location'] ?? 'No Address',
      category: json['cat_name'] ?? 'No Category',
      business_name: json['name'] ?? 'No Name',
      photo: json['photo'] ?? '',
      phone: json['phone'] as String?,
      service_id: json['service_id'] ?? 0,
      shop_id: json['shop_id'] ?? 0,
      isService: true,
      view_id: json['user_id'] ?? 0,
      user_called: json['user_called']?.toString() ?? '0',
      user_viewed: json['user_viewed']?.toString() ?? '0',
      days_since_creation: json['days_since_creation'] ?? '',
      distance: json['distance'] as String?,
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      call_status: json['call_status'] as String?,
      lastSeen: json['last_seen'] ?? '',
      lastCalled: json['last_called'] ?? '',
      sub_type: json['sub_type'] as String?,
    );
  }
}

class UserFetchResult {
  final List<UserDetail> users;
  final bool locationAvailable;
  final bool hasMore;
  UserFetchResult(this.users, {required this.locationAvailable, required this.hasMore});
}

// ─────────────────────────────────────────────────────────────────────────────
//  Page
// ─────────────────────────────────────────────────────────────────────────────

class ServiceFavorite extends StatefulWidget {
  final String cat_id;
  final String category_name;
  final String userPhone;

  const ServiceFavorite({
    super.key,
    required this.cat_id,
    required this.category_name,
    required this.userPhone,
  });

  @override
  _ServiceFavoriteState createState() => _ServiceFavoriteState();
}

class _ServiceFavoriteState extends State<ServiceFavorite> with RouteAware {
  final _searchController = TextEditingController();
  final _searchFocus      = FocusNode();
  String _query     = '';
  Timer? _debounce;
  bool _searchFocused = false;

  int  _servicePage    = 1;
  final int _limit     = 10;
  int  _shopPage       = 1;
  bool _serviceHasMore = true;
  bool _shopHasMore    = true;
  bool _isLoadingMore  = false;
  late final ScrollController _scrollController = ScrollController();

  List<UserDetail> combinedUsers   = [];
  bool locationAvailable           = true;
  String sortBy                    = 'nearby';
  bool isLoading                   = true;
  bool _locationReady              = false;
  bool _locationLoading            = false;

  static const Color _accent      = Color(0xFF1D4ED8);
  static const Color _accentLight = Color(0xFF3B82F6);
  static const Color _bg          = Color(0xFFF4F8FF);

  static const _sortOptions = [
    {'value': 'nearby',      'label': 'Nearby',      'icon': Icons.near_me_rounded},
    {'value': 'most_viewed', 'label': 'Most Viewed', 'icon': Icons.visibility_rounded},
    {'value': 'most_called', 'label': 'Most Booked', 'icon': Icons.phone_rounded},
    {'value': 'recent',      'label': 'Recent',       'icon': Icons.schedule_rounded},
  ];

  bool get _isNearby => sortBy == 'nearby';

  List<UserDetail> get _visibleUsers {
    if (_query.trim().isEmpty) return combinedUsers;
    final q = _query.toLowerCase();
    return combinedUsers.where((u) => u.business_name.toLowerCase().contains(q)).toList();
  }

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
    _scrollController..removeListener(_onScroll)..dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => fetchData();

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
    if (_scrollController.position.maxScrollExtent - _scrollController.position.pixels <= 200) {
      _loadMoreIfNeeded();
    }
  }

  void _loadMoreIfNeeded() async {
    if (_isLoadingMore) return;
    if (!(_serviceHasMore || _shopHasMore)) return;
    setState(() => _isLoadingMore = true);
    if (_serviceHasMore) {
      final res = await fetchUserDetails(widget.cat_id, 'service', sortBy, page: _servicePage + 1);
      if (res.users.isNotEmpty) {
        setState(() { combinedUsers.addAll(res.users); _servicePage++; _serviceHasMore = res.hasMore; });
      } else { setState(() => _serviceHasMore = false); }
    }
    if (_shopHasMore) {
      final res = await fetchUserDetails(widget.cat_id, 'shop', sortBy, page: _shopPage + 1);
      if (res.users.isNotEmpty) {
        setState(() { combinedUsers.addAll(res.users); _shopPage++; _shopHasMore = res.hasMore; });
      } else { setState(() => _shopHasMore = false); }
    }
    setState(() => _isLoadingMore = false);
  }

  void fetchData() async {
    setState(() => isLoading = true);
    final sRes  = await fetchUserDetails(widget.cat_id, 'service', sortBy, page: 1);
    final shRes = await fetchUserDetails(widget.cat_id, 'shop',    sortBy, page: 1);
    if (!mounted) return;
    setState(() {
      combinedUsers     = [...sRes.users, ...shRes.users];
      locationAvailable = sRes.locationAvailable || shRes.locationAvailable;
      _serviceHasMore   = sRes.hasMore;
      _shopHasMore      = shRes.hasMore;
      _servicePage      = sRes.users.isNotEmpty  ? 1 : 0;
      _shopPage         = shRes.users.isNotEmpty ? 1 : 0;
      isLoading         = false;
    });
  }

  void fetchInitialData() {
    _servicePage = 1; _shopPage = 1;
    _serviceHasMore = true; _shopHasMore = true;
    combinedUsers = [];
    fetchData();
  }

  Future<UserFetchResult> fetchUserDetails(
      String cat_id, String dataType, String sortBy, {int page = 1}) async {
    final ctx    = context;
    final userId = await Config.getLoggedInUser();

    if (sortBy == 'nearby') {
      final lat = AppLocation().lat;
      final lon = AppLocation().lon;
      if (lat == null || lon == null) return UserFetchResult([], locationAvailable: false, hasMore: false);
      final url = '/get_data_by_category?cat_id=$cat_id&data_type=$dataType&sort_by=nearby'
          '&user_location=$lat,$lon&user_id=$userId&page=$page';
      try {
        final res = await Config.apiGet(url, ctx);
        if (res != null && res.statusCode == 200) {
          final body  = jsonDecode(res.body);
          final users = (body['${dataType}_information'] as List? ?? [])
              .map((d) => UserDetail.fromJson(d as Map<String, dynamic>)).toList();
          return UserFetchResult(users, locationAvailable: true, hasMore: users.length == _limit);
        }
      } catch (_) {}
      return UserFetchResult([], locationAvailable: true, hasMore: false);
    }

    final url = '/get_data_by_category?cat_id=$cat_id&data_type=$dataType&sort_by=$sortBy'
        '&user_id=$userId&page=$page';
    try {
      final res = await Config.apiGet(url, ctx);
      if (res != null && res.statusCode == 200) {
        final body  = jsonDecode(res.body);
        final users = (body['${dataType}_information'] as List? ?? [])
            .map((d) => UserDetail.fromJson(d as Map<String, dynamic>)).toList();
        return UserFetchResult(users, locationAvailable: true, hasMore: users.length == _limit);
      }
    } catch (_) {}
    return UserFetchResult([], locationAvailable: true, hasMore: false);
  }

  void updateSorting(String newSort) {
    if (sortBy == newSort) return;
    setState(() => sortBy = newSort);
    fetchInitialData();
  }

  void handleAction(int userId, String actionType, int detailPostId) async {
    await NotificationService().sendNotificationWithLoggedInUser(userId, actionType, detailPostId, context);
  }

  void _navigateToProfile(UserDetail user) {
    handleAction(user.view_id, 'view', 0);
    Navigator.push(context, MaterialPageRoute(builder: (_) => AdvertScreen(
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
    )));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(),
        body: Column(children: [
          if (!_isNearby) _buildSearchField(),
          _buildSortBar(),
          Expanded(child: _buildBody()),
        ]),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF111827),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF374151)),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.category_name,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
        if (!isLoading)
          Text('${_visibleUsers.length} specialist${_visibleUsers.length != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
      ]),
      actions: [
        if (_locationReady && _isNearby)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _PulseDot(color: const Color(0xFF22C55E)),
              const SizedBox(width: 5),
              const Text('Live', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
            ]),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE5E7EB)),
      ),
    );
  }

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        decoration: BoxDecoration(
          color: _searchFocused ? Colors.white : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _searchFocused ? _accent : const Color(0xFFBFDBFE),
              width: _searchFocused ? 1.8 : 1.0),
          boxShadow: [
            BoxShadow(
                color: _searchFocused ? _accent.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.04),
                blurRadius: _searchFocused ? 16 : 6, offset: const Offset(0, 3)),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          onChanged: (val) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 200), () => setState(() => _query = val));
          },
          style: const TextStyle(fontSize: 15, color: Color(0xFF111827), fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Search specialists by name…',
            hintStyle: TextStyle(color: _searchFocused ? const Color(0xFFADB5C7) : _accent.withValues(alpha: 0.55), fontSize: 14),
            prefixIcon: Icon(Icons.person_search_rounded, color: _searchFocused ? _accent : _accentLight, size: 22),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFFADB5C7), size: 18),
                    onPressed: () { _searchController.clear(); setState(() => _query = ''); })
                : null,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildSortBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _sortOptions.map((opt) {
            final val      = opt['value'] as String;
            final label    = opt['label'] as String;
            final icon     = opt['icon'] as IconData;
            final selected = sortBy == val;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(colors: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
                          begin: Alignment.topLeft, end: Alignment.bottomRight)
                      : null,
                  color: selected ? null : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: selected ? _accent : const Color(0xFFBFDBFE)),
                  boxShadow: selected
                      ? [BoxShadow(color: _accent.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4))]
                      : [],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => updateSorting(val),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(icon, size: 14, color: selected ? Colors.white : _accent),
                        const SizedBox(width: 6),
                        Text(label, style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700,
                            color: selected ? Colors.white : _accent, letterSpacing: 0.2)),
                      ]),
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

  Widget _buildBody() {
    if (_isNearby) {
      if (_locationLoading) {
        return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: _accent, strokeWidth: 2),
          const SizedBox(height: 14),
          const Text('Getting your location…',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        ]));
      }
      if (!_locationReady) return _buildLocationError();
      if (isLoading) return Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2));
      return _MapView(
        services: _visibleUsers,
        userLat: AppLocation().lat!,
        userLon: AppLocation().lon!,
        accent: _accent,
        onConnect: _navigateToProfile,
        onRefresh: () async {
          final ok = await AppLocation().init();
          if (mounted) setState(() => _locationReady = ok);
          fetchInitialData();
        },
      );
    }

    if (isLoading) return Center(child: CircularProgressIndicator(color: _accent));
    if (_visibleUsers.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      color: _accent,
      onRefresh: () async => fetchInitialData(),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
        itemCount: _visibleUsers.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _visibleUsers.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2.5)),
            );
          }
          return _buildProviderCard(_visibleUsers[i]);
        },
      ),
    );
  }

  Widget _buildLocationError() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.location_off_rounded, size: 52, color: _accent.withValues(alpha: 0.4)),
        const SizedBox(height: 16),
        const Text('Location Access Needed',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
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
              backgroundColor: _accent, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ]),
    ));
  }

  // ── List-view card ────────────────────────────────────────────────────────

  bool _wasInteracted(UserDetail user) {
    DateTime? lastSeenDt;
    DateTime? lastCalledDt;
    try {
      if (user.lastSeen.isNotEmpty)   lastSeenDt   = DateFormat("EEE dd MMM yyyy HH:mm:ss").parse(user.lastSeen);
      if (user.lastCalled.isNotEmpty) lastCalledDt = DateFormat("EEE dd MMM yyyy HH:mm:ss").parse(user.lastCalled);
    } catch (_) {}
    final now = DateTime.now();
    return (lastSeenDt  != null && now.difference(lastSeenDt).inDays  <= 7) ||
           (lastCalledDt != null && now.difference(lastCalledDt).inDays <= 7);
  }

  Widget _buildProviderCard(UserDetail user) {
    final bool isAvailable = (user.call_status ?? '').toLowerCase() == 'active';
    final Color accent = _wasInteracted(user) ? const Color(0xFFD97706) : _accent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border(left: BorderSide(color: accent, width: 5)),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: 0.10), blurRadius: 16, offset: const Offset(0, 5)),
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _navigateToProfile(user),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _buildAvatar(user, accent),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(user.business_name,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), height: 1.2),
                          maxLines: 2, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      _availPill(isAvailable),
                    ]),
                    const SizedBox(height: 6),
                    _specialtyTag(user.category, accent),
                    if (user.address.isNotEmpty && user.address != 'No Address') ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.location_on_rounded, size: 12, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Expanded(child: Text(user.address,
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ]),
                    ],
                  ])),
                ]),
                const SizedBox(height: 10),
                Container(height: 1, color: const Color(0xFFF0F3FA)),
                const SizedBox(height: 10),
                Row(children: [
                  _statChip(user, accent),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _navigateToProfile(user),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.82)],
                            begin: Alignment.topLeft, end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.32), blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Connect', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward_rounded, size: 13, color: Colors.white),
                      ]),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(UserDetail user, Color accent) {
    return Stack(children: [
      Container(
        width: 68, height: 68,
        decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: accent.withValues(alpha: 0.28), width: 2.5),
            boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.14), blurRadius: 8, offset: const Offset(0, 2))]),
        child: ClipOval(
          child: user.photo.isNotEmpty
              ? Image.network(user.photo, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _noImage(accent))
              : _noImage(accent),
        ),
      ),
      if (user.sub_type != null)
        Positioned(bottom: 0, right: 0,
          child: Container(
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                boxShadow: user.sub_type == 'paid' ? [BoxShadow(color: _accentLight.withValues(alpha: 0.5), blurRadius: 6, spreadRadius: 1)] : []),
            padding: const EdgeInsets.all(2.5),
            child: Icon(Icons.verified_rounded, size: 15,
                color: user.sub_type == 'paid' ? _accentLight : Colors.grey.shade400),
          )),
    ]);
  }

  Widget _specialtyTag(String category, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.work_rounded, size: 11, color: accent.withValues(alpha: 0.85)),
        const SizedBox(width: 4),
        Flexible(child: Text(category,
            style: TextStyle(fontSize: 11, color: accent, fontWeight: FontWeight.w700),
            maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _availPill(bool isAvailable) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAvailable ? Colors.green.shade50 : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isAvailable ? [BoxShadow(color: Colors.greenAccent.withValues(alpha: 0.35), blurRadius: 6, spreadRadius: 1)] : [],
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(shape: BoxShape.circle,
            color: isAvailable ? Colors.green : Colors.grey.shade400)),
        const SizedBox(width: 4),
        Text(isAvailable ? 'Available' : 'Offline',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: isAvailable ? Colors.green.shade700 : Colors.grey.shade500)),
      ]),
    );
  }

  Widget _statChip(UserDetail user, Color color) {
    Widget txt(String t) => Text(t, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color));
    Widget ico(IconData i) => Icon(i, size: 11, color: color);
    late Widget content;
    switch (sortBy) {
      case 'most_called':
        content = Row(mainAxisSize: MainAxisSize.min, children: [ico(Icons.phone_rounded), const SizedBox(width: 4),
          txt(user.user_called == '0' ? 'No bookings' : '${Config.formatLargeNumber(int.parse(user.user_called))} bookings')]);
        break;
      case 'most_viewed':
        content = Row(mainAxisSize: MainAxisSize.min, children: [ico(Icons.visibility_rounded), const SizedBox(width: 4),
          txt(user.user_viewed == '0' ? 'No views' : '${Config.formatLargeNumber(int.parse(user.user_viewed))} views')]);
        break;
      case 'recent':
        content = Row(mainAxisSize: MainAxisSize.min, children: [ico(Icons.schedule_rounded), const SizedBox(width: 4),
          txt(Config.getTimeDifference(user.days_since_creation))]);
        break;
      default: content = const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
      child: content,
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 80, height: 80,
            decoration: BoxDecoration(color: _accent.withValues(alpha: 0.08), shape: BoxShape.circle),
            child: Icon(Icons.person_search_rounded, size: 38, color: _accent)),
        const SizedBox(height: 20),
        const Text('No specialists found',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        const SizedBox(height: 8),
        const Text('No service providers found.\nTry a different filter.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), height: 1.5)),
      ]),
    ));
  }

  Widget _noImage(Color accent) => Container(
      color: accent.withValues(alpha: 0.08),
      child: Center(child: Icon(Icons.person_rounded, color: accent, size: 30)));
}

// ─────────────────────────────────────────────────────────────────────────────
//  Cartesian map view
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
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();
  }

  @override
  void dispose() { _pulseCtrl.dispose(); super.dispose(); }

  // ── Geo ───────────────────────────────────────────────────────────────────

  static double _bearing(double lat1, double lon1, double lat2, double lon2) {
    const rad   = math.pi / 180;
    final dLon  = (lon2 - lon1) * rad;
    final lat1R = lat1 * rad;
    final lat2R = lat2 * rad;
    final y = math.sin(dLon) * math.cos(lat2R);
    final x = math.cos(lat1R) * math.sin(lat2R) - math.sin(lat1R) * math.cos(lat2R) * math.cos(dLon);
    return math.atan2(y, x); // 0=N, π/2=E
  }

  static double _logR(double distM, double maxDistM) {
    if (distM <= 0 || maxDistM <= 0) return 0.05;
    return (math.log(1 + distM) / math.log(1 + maxDistM)).clamp(0.05, 0.93);
  }

  /// Marble color: warm red for close → blue for medium → purple for distant.
  static Color _marbleRim(double normR) {
    if (normR < 0.25) return const Color(0xFFEF4444);
    if (normR < 0.50) return const Color(0xFFF97316);
    if (normR < 0.75) return const Color(0xFF3B82F6);
    return const Color(0xFF8B5CF6);
  }

  static double _dotSize(double normR) => (54 - 34 * normR).clamp(18.0, 54.0);

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final mappable = widget.services
        .where((s) => s.lat != null && s.lon != null && s.distanceKm != null)
        .toList();
    final noGps = widget.services.length - mappable.length;

    final maxDistM = mappable.isEmpty ? 1.0 :
        mappable.fold(0.0, (m, s) => math.max(m, s.distanceKm! * 1000));

    return Column(children: [
      // ── Status strip ──────────────────────────────────────────────────────
      Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        child: Row(children: [
          Container(width: 7, height: 7,
              decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          const Text('GPS active', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: widget.onRefresh,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.refresh_rounded, size: 13, color: widget.accent),
              const SizedBox(width: 3),
              Text('Refresh', style: TextStyle(fontSize: 11, color: widget.accent, fontWeight: FontWeight.w700)),
            ]),
          ),
          const Spacer(),
          if (mappable.isNotEmpty)
            Text('${mappable.length} on map', style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          if (noGps > 0)
            Text('  $noGps no-GPS', style: const TextStyle(fontSize: 10, color: Color(0xFFD1D5DB))),
        ]),
      ),

      // ── Map canvas ────────────────────────────────────────────────────────
      Expanded(
        child: LayoutBuilder(builder: (_, box) {
          final w  = box.maxWidth;
          final h  = box.maxHeight;
          final cx = w / 2;
          final cy = h / 2;
          final maxR = math.min(w, h) / 2 * 0.86;

          // No GPS data at all
          if (mappable.isEmpty) {
            return Stack(children: [
              CustomPaint(size: Size(w, h), painter: _MapGridPainter(cx: cx, cy: cy, accent: widget.accent)),
              _youDot(cx, cy, maxR),
              Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(height: 60),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: widget.accent.withValues(alpha: 0.12), blurRadius: 16)],
                  ),
                  child: Column(children: [
                    Icon(Icons.location_searching_rounded, size: 36, color: widget.accent.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text('No GPS location on map',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                    const SizedBox(height: 6),
                    Text(
                      widget.services.isEmpty
                          ? 'No specialists found nearby. Try a wider search.'
                          : '${widget.services.length} specialist${widget.services.length != 1 ? 's' : ''} found but none have shared GPS coordinates yet.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.5),
                    ),
                  ]),
                ),
              ])),
            ]);
          }

          return InteractiveViewer(
            boundaryMargin: EdgeInsets.symmetric(horizontal: w * 0.5, vertical: h * 0.5),
            minScale: 0.25,
            maxScale: 8.0,
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(children: [
                // Grid
                CustomPaint(size: Size(w, h), painter: _MapGridPainter(cx: cx, cy: cy, accent: widget.accent, maxDistKm: maxDistM / 1000)),

                // Compass
                Positioned(left: cx - 7,  top: 10,     child: _compassTxt('N', widget.accent)),
                Positioned(right: 10,     top: cy - 8, child: _compassTxt('E', widget.accent)),
                Positioned(left: cx - 6,  bottom: 10,  child: _compassTxt('S', widget.accent)),
                Positioned(left: 10,      top: cy - 8, child: _compassTxt('W', widget.accent)),

                // Marbles + distance labels
                ...mappable.map((s) {
                  final b     = _bearing(widget.userLat, widget.userLon, s.lat!, s.lon!);
                  final normR = _logR(s.distanceKm! * 1000, maxDistM);
                  final sz    = _dotSize(normR);
                  final dx    = normR * maxR * math.sin(b);
                  final dy    = -normR * maxR * math.cos(b);
                  final sel   = _selected == s;
                  final rim   = _marbleRim(normR);

                  return Positioned(
                    left: cx + dx - sz / 2,
                    top:  cy + dy - sz / 2,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Marble(
                          service:  s,
                          rimColor: rim,
                          selected: sel,
                          size:     sz,
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _selected = sel ? null : s);
                          },
                        ),
                        const SizedBox(height: 3),
                        if (s.distanceKm != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.88),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: rim.withValues(alpha: 0.35), width: 0.8),
                            ),
                            child: Text(
                              s.distanceKm! < 1
                                  ? '${(s.distanceKm! * 1000).round()}m'
                                  : '${s.distanceKm!.toStringAsFixed(1)}km',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: rim,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }),

                // YOU dot + pulse
                _youDot(cx, cy, maxR),
              ]),
            ),
          );
        }),
      ),

      // ── Bottom profile panel ──────────────────────────────────────────────
      _ProfilePanel(
        service:   _selected,
        accent:    widget.accent,
        onConnect: () => widget.onConnect(_selected!),
        onDismiss: () => setState(() => _selected = null),
      ),
    ]);
  }

  Widget _youDot(double cx, double cy, double maxR) {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) => Stack(clipBehavior: Clip.none, children: [
        // Pulse rings
        for (int i = 0; i < 3; i++) ...[() {
          final v = (_pulseCtrl.value + i / 3) % 1.0;
          final r = v * maxR * 0.10;
          return Positioned(left: cx - r, top: cy - r,
            child: Container(width: r * 2, height: r * 2,
              decoration: BoxDecoration(shape: BoxShape.circle,
                border: Border.all(color: widget.accent.withValues(alpha: (1 - v) * 0.36), width: 1.4))));
        }()],
        // Dot
        Positioned(left: cx - 12, top: cy - 12,
          child: Container(width: 24, height: 24,
            decoration: BoxDecoration(color: widget.accent, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: widget.accent.withValues(alpha: 0.45), blurRadius: 14, spreadRadius: 2)]),
            child: Center(child: Container(width: 8, height: 8,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle))))),
        // Label
        Positioned(left: cx - 14, top: cy + 14,
          child: Text('YOU', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900,
              color: widget.accent, letterSpacing: 1.2))),
      ]),
    );
  }

  static Widget _compassTxt(String t, Color accent) {
    return Text(t, style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w800,
        color: accent.withValues(alpha: 0.28), letterSpacing: 1.2));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Grid painter (static)
// ─────────────────────────────────────────────────────────────────────────────

class _MapGridPainter extends CustomPainter {
  final double cx, cy;
  final Color  accent;
  final double maxDistKm;
  const _MapGridPainter({required this.cx, required this.cy, required this.accent, this.maxDistKm = 0});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = const Color(0xFFF8FBFF));

    const step      = 38.0;
    final gridPaint = Paint()..color = accent.withValues(alpha: 0.08)..strokeWidth = 0.7;
    final axisPaint = Paint()..color = accent.withValues(alpha: 0.20)..strokeWidth = 1.2;
    final tickPaint = Paint()..color = accent.withValues(alpha: 0.16)..strokeWidth = 0.8;

    for (double x = cx % step; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = cy % step; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), axisPaint);
    canvas.drawLine(Offset(0, cy), Offset(size.width, cy),  axisPaint);

    for (double x = cx % step; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, cy - 4), Offset(x, cy + 4), tickPaint);
    }
    for (double y = cy % step; y <= size.height; y += step) {
      canvas.drawLine(Offset(cx - 4, y), Offset(cx + 4, y), tickPaint);
    }

    final maxR = math.min(cx, cy) * 0.86;
    for (int i = 1; i <= 4; i++) {
      final r = (i / 4) * maxR;
      canvas.drawCircle(Offset(cx, cy), r,
          Paint()..color = accent.withValues(alpha: 0.055)..style = PaintingStyle.stroke..strokeWidth = 0.7);

      // Ring distance label (NE quadrant on each ring)
      if (maxDistKm > 0) {
        final ringKm = (math.log(1 + (i / 4) * maxDistKm * 1000) / math.log(1 + maxDistKm * 1000)) * maxDistKm;
        final label  = ringKm < 1 ? '${(ringKm * 1000).round()}m' : '${ringKm.toStringAsFixed(1)}km';
        final tp     = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(fontSize: 8, color: accent.withValues(alpha: 0.35), fontWeight: FontWeight.w700),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cx + r * 0.707 + 2, cy - r * 0.707 - 10));
      }
    }
  }

  @override
  bool shouldRepaint(_MapGridPainter old) => old.maxDistKm != maxDistKm;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Marble dot  — with glossy overlay + tooltip above when selected
// ─────────────────────────────────────────────────────────────────────────────

class _Marble extends StatelessWidget {
  final UserDetail   service;
  final Color        rimColor;
  final bool         selected;
  final double       size;
  final VoidCallback onTap;

  const _Marble({
    required this.service,
    required this.rimColor,
    required this.selected,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAvail = (service.call_status ?? '').toLowerCase() == 'active';
    final indSz   = (size * 0.26).clamp(8.0, 13.0);

    return GestureDetector(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [

        // ── Tooltip above marble (shown when selected) ──────────────────
        if (selected)
          Positioned(
            bottom: size + 10,
            left: size / 2 - 80,
            child: _MarbleTooltip(service: service, rimColor: rimColor),
          ),

        // ── Glow shadow when selected ──────────────────────────────────
        if (selected)
          Positioned(
            left: -8, top: -8, right: -8, bottom: -8,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: rimColor.withValues(alpha: 0.50), blurRadius: 20, spreadRadius: 4)],
              ),
            ),
          ),

        // ── Marble body ────────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: size, height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: selected ? rimColor : rimColor.withValues(alpha: 0.55),
                width: selected ? 3.0 : 2.0),
            boxShadow: [
              // Depth shadow
              BoxShadow(color: rimColor.withValues(alpha: selected ? 0.38 : 0.18),
                  blurRadius: selected ? 14 : 7, offset: const Offset(2, 4)),
              // Inner-ish highlight
              BoxShadow(color: Colors.white.withValues(alpha: 0.6),
                  blurRadius: 4, offset: const Offset(-2, -2), spreadRadius: -2),
            ],
          ),
          child: ClipOval(
            child: Stack(fit: StackFit.expand, children: [
              // Photo or fallback
              service.photo.isNotEmpty
                  ? Image.network(service.photo, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallback())
                  : _fallback(),

              // Glossy radial gradient overlay (top-left shine)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.55, -0.60),
                    radius: 0.80,
                    colors: [
                      Colors.white.withValues(alpha: 0.42),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // Subtle rim-coloured tint at the bottom
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: size * 0.35,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, rimColor.withValues(alpha: 0.25)],
                    ),
                  ),
                ),
              ),
            ]),
          ),
        ),

        // ── Online indicator ───────────────────────────────────────────
        if (isAvail)
          Positioned(
            top: 0, right: 0,
            child: Container(
              width: indSz, height: indSz,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.4),
                boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.5), blurRadius: 4)],
              ),
            ),
          ),
      ]),
    );
  }

  Widget _fallback() {
    return Container(
      color: rimColor.withValues(alpha: 0.15),
      child: Center(child: Text(
          service.business_name.isNotEmpty ? service.business_name[0].toUpperCase() : '?',
          style: TextStyle(color: rimColor, fontSize: size * 0.40, fontWeight: FontWeight.w900))),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tooltip that floats above the selected marble
// ─────────────────────────────────────────────────────────────────────────────

class _MarbleTooltip extends StatelessWidget {
  final UserDetail service;
  final Color      rimColor;
  const _MarbleTooltip({required this.service, required this.rimColor});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Card
      Container(
        width: 160,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: rimColor.withValues(alpha: 0.30), width: 1.2),
          boxShadow: [BoxShadow(color: rimColor.withValues(alpha: 0.22), blurRadius: 12, offset: const Offset(0, 3))],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Distance
          if (service.distance != null)
            Row(children: [
              Icon(Icons.near_me_rounded, size: 12, color: rimColor),
              const SizedBox(width: 4),
              Text(service.distance!,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: rimColor)),
            ]),
          // Location
          if (service.address.isNotEmpty && service.address != 'No Address') ...[
            const SizedBox(height: 3),
            Row(children: [
              Icon(Icons.location_on_rounded, size: 11, color: Colors.grey.shade400),
              const SizedBox(width: 3),
              Flexible(
                child: Text(service.address,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
              ),
            ]),
          ],
        ]),
      ),

      // Arrow pointing down to marble
      CustomPaint(size: const Size(14, 7), painter: _ArrowPainter(rimColor)),
    ]);
  }
}

class _ArrowPainter extends CustomPainter {
  final Color color;
  const _ArrowPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(p, Paint()..color = Colors.white);
    canvas.drawPath(p, Paint()
      ..color = color.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Bottom profile panel  — tapping content area navigates to AdvertPage
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
            color: service == null ? const Color(0xFFE5E7EB) : accent.withValues(alpha: 0.30),
            width: service == null ? 1 : 1.5),
        boxShadow: [
          BoxShadow(
              color: (service != null ? accent : Colors.black).withValues(alpha: service != null ? 0.10 : 0.04),
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
        Text('Tap a marble to view specialist details',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  Widget _card(UserDetail s) {
    final isAvail = (s.call_status ?? '').toLowerCase() == 'active';
    final views   = int.tryParse(s.user_viewed) ?? 0;
    final calls   = int.tryParse(s.user_called) ?? 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ── Main tappable content ──────────────────────────────────────
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
                      border: Border.all(color: accent.withValues(alpha: 0.35), width: 2),
                      boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.18), blurRadius: 8)],
                    ),
                    child: ClipOval(
                      child: s.photo.isNotEmpty
                          ? Image.network(s.photo, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _avatarFallback(s))
                          : _avatarFallback(s),
                    ),
                  ),
                  if (isAvail)
                    Positioned(bottom: 1, right: 1,
                      child: Container(width: 13, height: 13,
                          decoration: BoxDecoration(color: const Color(0xFF22C55E), shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5)))),
                ]),

                const SizedBox(width: 12),

                // Info
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Name row
                    Row(children: [
                      Expanded(child: Text(s.business_name,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: isAvail ? Colors.green.shade50 : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(isAvail ? 'Available' : 'Offline',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                                color: isAvail ? Colors.green.shade700 : Colors.grey.shade500)),
                      ),
                    ]),

                    const SizedBox(height: 3),

                    // Category + distance
                    Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(5)),
                        child: Text(s.category,
                            style: TextStyle(fontSize: 10, color: accent, fontWeight: FontWeight.w700)),
                      ),
                      if (s.distance != null) ...[
                        const SizedBox(width: 8),
                        Icon(Icons.near_me_rounded, size: 10, color: Colors.grey.shade400),
                        const SizedBox(width: 2),
                        Text(s.distance!,
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                      ],
                    ]),

                    const SizedBox(height: 4),

                    // Address
                    if (s.address.isNotEmpty && s.address != 'No Address')
                      Row(children: [
                        Icon(Icons.location_on_rounded, size: 10, color: Colors.grey.shade400),
                        const SizedBox(width: 2),
                        Expanded(child: Text(s.address,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500))),
                      ]),

                    const SizedBox(height: 4),

                    // Stats row
                    Row(children: [
                      Icon(Icons.visibility_outlined, size: 10, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text(Config.formatLargeNumber(views),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 10),
                      Icon(Icons.phone_outlined, size: 10, color: Colors.grey.shade400),
                      const SizedBox(width: 3),
                      Text(Config.formatLargeNumber(calls),
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Text('Tap to view profile →',
                          style: TextStyle(fontSize: 9.5, color: accent.withValues(alpha: 0.60), fontWeight: FontWeight.w700)),
                    ]),
                  ],
                )),
              ]),
            ),
          ),
        ),

        // ── Dismiss strip ──────────────────────────────────────────────
        GestureDetector(
          onTap: onDismiss,
          child: Container(
            width: 40,
            color: const Color(0xFFF9FAFB),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade400),
              const SizedBox(height: 4),
              Text('close', style: TextStyle(fontSize: 8, color: Colors.grey.shade400, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _avatarFallback(UserDetail s) {
    return Container(
      color: accent.withValues(alpha: 0.10),
      child: Center(child: Text(
          s.business_name.isNotEmpty ? s.business_name[0].toUpperCase() : '?',
          style: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.w800))),
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

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 8, height: 8,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color,
          boxShadow: [BoxShadow(color: widget.color.withValues(alpha: 0.5 * _ctrl.value), blurRadius: 6, spreadRadius: 2)]),
      ),
    );
  }
}
