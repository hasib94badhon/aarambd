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
  final _searchFocus = FocusNode();
  String _query = '';
  Timer? _debounce;
  bool _searchFocused = false;

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

  // Service-provider palette: indigo/violet distinguishes from shops (blue)
  static const Color _accent = Color(0xFF6D28D9);   // violet-700
  static const Color _accentLight = Color(0xFF7C3AED); // violet-600
  static const Color _bg = Color(0xFFF5F3FF);         // violet-50 tint

  static const _sortOptions = [
    {'value': 'most_called', 'label': 'Most Booked',  'icon': Icons.phone_rounded},
    {'value': 'most_viewed', 'label': 'Most Viewed',  'icon': Icons.visibility_rounded},
    {'value': 'recent',      'label': 'Recent',        'icon': Icons.schedule_rounded},
    {'value': 'nearby',      'label': 'Nearby',        'icon': Icons.near_me_rounded},
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
      child: Scaffold(
        backgroundColor: _bg,
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildSearchField(),
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
            widget.category_name,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          if (!isLoading)
            Text(
              '$count specialist${count != 1 ? 's' : ''} found',
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

  // ── Search field ──────────────────────────────────────────────────────────

  Widget _buildSearchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: _searchFocused ? Colors.white : const Color(0xFFEDE9FE),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _searchFocused ? _accent : const Color(0xFFDDD6FE),
            width: _searchFocused ? 1.8 : 1.0,
          ),
          boxShadow: _searchFocused
              ? [
                  BoxShadow(
                    color: _accent.withValues(alpha: 0.18),
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
            hintText: 'Search specialists by name...',
            hintStyle: TextStyle(
              color: _searchFocused
                  ? const Color(0xFFADB5C7)
                  : const Color(0xFFA78BFA),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.person_search_rounded,
                key: ValueKey(_searchFocused),
                color: _searchFocused ? _accent : const Color(0xFFA78BFA),
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
                          colors: [Color(0xFF6D28D9), Color(0xFF7C3AED)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: selected ? null : const Color(0xFFF5F3FF),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF6D28D9)
                        : const Color(0xFFDDD6FE),
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF6D28D9)
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
                                : const Color(0xFF7C3AED),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: selected
                                  ? Colors.white
                                  : const Color(0xFF6D28D9),
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
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6D28D9)),
      );
    }

    if (_visibleUsers.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      color: const Color(0xFF6D28D9),
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
                    color: Color(0xFF6D28D9), strokeWidth: 2.5),
              ),
            );
          }
          return _buildProviderCard(_visibleUsers[index]);
        },
      ),
    );
  }

  // ── Provider profile card ─────────────────────────────────────────────────

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

  Widget _buildProviderCard(UserDetail user) {
    final bool isAvailable =
        (user.call_status ?? '').toLowerCase() == 'active';
    // Recently interacted → warm amber; otherwise → violet accent
    final Color accent = _wasInteracted(user)
        ? const Color(0xFFD97706)
        : const Color(0xFF6D28D9);

    void navigate() {
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
                  // ── Top: avatar + profile info ─────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildAvatar(user, accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name + availability
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
                                _buildAvailabilityPill(isAvailable),
                              ],
                            ),
                            const SizedBox(height: 6),
                            // Specialty/category tag
                            _buildSpecialtyTag(user.category, accent),
                            // Location
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

                  // ── Bottom: stat + timestamps + Connect button ─────────
                  Row(
                    children: [
                      _buildStatChip(user, accent),
                      if (user.lastSeen.isNotEmpty ||
                          user.lastCalled.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        _buildTimestamps(user),
                      ],
                      const Spacer(),
                      // Connect button
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
                                'Connect',
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

  // ── Avatar with verified badge ────────────────────────────────────────────

  Widget _buildAvatar(UserDetail user, Color accent) {
    return Stack(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
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
          child: ClipOval(
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
                          color: _accentLight.withValues(alpha: 0.5),
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
                    ? _accentLight
                    : Colors.grey.shade400,
              ),
            ),
          ),
      ],
    );
  }

  // ── Specialty tag chip ────────────────────────────────────────────────────

  Widget _buildSpecialtyTag(String category, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.work_rounded,
              size: 11, color: accent.withValues(alpha: 0.85)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              category,
              style: TextStyle(
                fontSize: 11,
                color: accent,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Availability pill ─────────────────────────────────────────────────────

  Widget _buildAvailabilityPill(bool isAvailable) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAvailable
            ? Colors.green.shade50
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        boxShadow: isAvailable
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
              color: isAvailable ? Colors.green : Colors.grey.shade400,
              boxShadow: isAvailable
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
            isAvailable ? 'Available' : 'Offline',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isAvailable
                  ? Colors.green.shade700
                  : Colors.grey.shade500,
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
              ? 'No bookings'
              : '${Config.formatLargeNumber(int.parse(user.user_called))} bookings'),
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

  Widget _buildTimestamps(UserDetail user) {
    final seenStr = Config.getTimeDifference(user.lastSeen, fallback: '');
    final calledStr = Config.getTimeDifference(user.lastCalled, fallback: '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNearbyNoLoc
                    ? Icons.location_off_rounded
                    : Icons.person_search_rounded,
                size: 38,
                color: _accent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isNearbyNoLoc
                  ? 'Location Access Denied'
                  : 'No specialists found',
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isNearbyNoLoc
                  ? 'Allow location access to see nearby specialists.'
                  : 'No service providers have joined this category yet.\nTry a different filter.',
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

  // ── Avatar fallback ───────────────────────────────────────────────────────

  Widget _buildNoImage() {
    return Container(
      color: _accent.withValues(alpha: 0.08),
      child: Center(
        child: Icon(
          Icons.person_rounded,
          color: _accent,
          size: 30,
        ),
      ),
    );
  }
}
