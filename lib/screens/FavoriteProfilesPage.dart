import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/screens/advert_screen.dart';
import 'package:aaram_bd/widgets/thoughtsection.dart' show CatTheme, themeFor;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

final String host = Config.host;

const Color _kBlue = Color(0xFF1A56DB);

class FavoriteProfilesPage extends StatefulWidget {
  final String userId;

  const FavoriteProfilesPage({required this.userId});

  @override
  _FavoriteProfilesPageState createState() => _FavoriteProfilesPageState();
}

class _FavoriteProfilesPageState extends State<FavoriteProfilesPage>
    with SingleTickerProviderStateMixin {
  List<dynamic> favoriteProfiles = [];
  bool _loading = true;
  late AnimationController _controller;
  late Animation<double> _pulse;

  final _searchCtrl = TextEditingController();
  String _query = '';

  List<dynamic> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return favoriteProfiles;
    return favoriteProfiles.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final cat = (p['cat_name'] ?? '').toString().toLowerCase();
      return name.contains(q) || cat.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    fetchFavorites();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  Future<void> fetchFavorites() async {
    try {
      final response = await http.get(
        Uri.parse('$host/get_favorite_user_profiles?user_id=${widget.userId}'),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          favoriteProfiles = data['favorite_profiles'];
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // Category photo when the person has no photo of their own; the category
  // emoji is the final fallback if even that fails to load.
  Widget _catFallback(String catPhoto, CatTheme catTheme) {
    final emojiFallback = Container(
      color: catTheme.primary.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(catTheme.emoji, style: const TextStyle(fontSize: 32)),
    );
    if (catPhoto.trim().isEmpty) return emojiFallback;
    return Image.network(
      catPhoto,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => emojiFallback,
    );
  }

  Widget _statMini(IconData icon, String value) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: _kBlue.withValues(alpha: 0.75)),
      const SizedBox(width: 3),
      Text(value,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _kBlue.withValues(alpha: 0.85))),
    ]);
  }

  Widget buildFavoriteItem(Map<String, dynamic> profile) {
    final int service = profile['service_id'] ?? 0;
    final int shop = profile['shop_id'] ?? 0;
    final int userId = profile['user_id'] ?? 0;
    final int viewCount = profile['my_view_count'] ?? 0;
    final int callCount = profile['my_call_count'] ?? 0;
    final String favoritedAgo = Config.getTimeDifference(
        (profile['favorited_at'] ?? '').toString(),
        fallback: '');
    final String photo = (profile['photo'] ?? '').toString();
    final String catPhoto = (profile['cat_photo'] ?? '').toString();
    final catTheme = themeFor((profile['cat_id'] as num?)?.toInt());
    final bool isVerified = profile['type'] == 'paid';

    return _Tilt3DCard(
      onTap: () {
        late final String targetId;
        late final bool tappedIsService;
        late final Map<String, String> additionalData;

        if (service != 0) {
          targetId = service.toString();
          tappedIsService = true;
          additionalData = {'service_id': targetId};
        } else if (shop != 0) {
          targetId = shop.toString();
          tappedIsService = false;
          additionalData = {'shop_id': targetId};
        } else {
          targetId = userId.toString();
          tappedIsService = false;
          additionalData = {'user_only': targetId};
        }
        Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AdvertScreen(
                // targetId (service/shop id) is only for additionalData
                // routing — AdvertScreen's userId must be the real user_id.
                userId: userId.toString(),
                isService: tappedIsService,
                advertData: AdvertData(
                  userId: userId.toString(),
                  isService: tappedIsService,
                  additionalData: additionalData,
                ),
              ),
            ));
      },
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo — circular, category-icon fallback, verified + heart badges
            SizedBox(
              width: 84,
              height: 84,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: [
                  ClipOval(
                    child: photo.trim().isNotEmpty
                        ? Image.network(
                            photo,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _catFallback(catPhoto, catTheme),
                          )
                        : _catFallback(catPhoto, catTheme),
                  ),
                  // Subtle top sheen — adds glassy depth to the photo
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [
                            Colors.white.withValues(alpha: 0.16),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Verified badge — bottom-right, only for paid/verified profiles
                  if (isVerified)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 6,
                                offset: const Offset(0, 2)),
                          ],
                        ),
                        child: const Icon(Icons.verified_rounded,
                            color: _kBlue, size: 20),
                      ),
                    ),
                  // Floating heart badge
                  Positioned(
                    top: -6,
                    right: -6,
                    child: ScaleTransition(
                      scale: _pulse,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18),
                                blurRadius: 8,
                                offset: const Offset(0, 3)),
                          ],
                        ),
                        child: const Icon(Icons.favorite_rounded,
                            color: Colors.redAccent, size: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Info area
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile['name'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: Color(0xFF1A2340)),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    profile['cat_name'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Color(0xFF6B7280), fontSize: 12.5),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    _statMini(Icons.visibility_outlined, '$viewCount views'),
                    const SizedBox(width: 14),
                    _statMini(Icons.call_outlined, '$callCount calls'),
                  ]),
                  if (favoritedAgo.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('Saved $favoritedAgo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Gradient hero header — matches the drawer pages (AccountSettingsPage,
  // NotificationSettingsPage): back button + icon bubble + title/subtitle on
  // a rounded-bottom blue gradient, instead of a plain Material AppBar.
  Widget _buildHeader(BuildContext context) {
    final subtitle = favoriteProfiles.isEmpty
        ? 'Profiles you save will show up here'
        : '${favoriteProfiles.length} saved ${favoriteProfiles.length == 1 ? 'profile' : 'profiles'}';

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 14, 16, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1040B0), _kBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => Navigator.pop(context),
            child: const Padding(
              padding: EdgeInsets.all(6),
              child: Icon(Icons.arrow_back_ios_new_rounded,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Saved Profiles',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Search bar — filters by profile name OR category name as you type
  // (see _filtered above), shown whenever there's at least one saved profile.
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: _query.isEmpty
                  ? const Color(0xFFE8ECF4)
                  : _kBlue.withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
                color: _kBlue.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(fontSize: 14, color: Color(0xFF1A2340)),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Search by name or category...',
            hintStyle: const TextStyle(fontSize: 14, color: Color(0xFFA0A6B8)),
            prefixIcon:
                const Icon(Icons.search_rounded, size: 21, color: _kBlue),
            suffixIcon: _query.isEmpty
                ? null
                : GestureDetector(
                    onTap: () => setState(() {
                      _searchCtrl.clear();
                      _query = '';
                    }),
                    child: const Icon(Icons.close_rounded,
                        size: 19, color: Color(0xFFA0A6B8)),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(
                        color: _kBlue, strokeWidth: 2.5))
                : favoriteProfiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ScaleTransition(
                              scale: _pulse,
                              child: Container(
                                padding: const EdgeInsets.all(22),
                                decoration: const BoxDecoration(
                                    color: Color.fromARGB(255, 255, 255, 255),
                                    shape: BoxShape.circle),
                                child: const Icon(Icons.favorite_border_rounded,
                                    size: 42, color: _kBlue),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No saved profiles yet',
                              style: TextStyle(
                                fontSize: 17,
                                color: Color(0xFF1A2340),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Profiles you save will show up here',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          _buildSearchBar(),
                          Expanded(
                            child: Builder(builder: (context) {
                              final results = _filtered;
                              if (results.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.search_off_rounded,
                                          size: 34,
                                          color: Colors.black
                                              .withValues(alpha: 0.20)),
                                      const SizedBox(height: 10),
                                      Text('No matching profiles',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade500)),
                                    ],
                                  ),
                                );
                              }
                              return ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.all(12),
                                itemCount: results.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (context, i) =>
                                    buildFavoriteItem(results[i]),
                              );
                            }),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  3D-style card: layered "floating" shadow that compresses on press, plus a
//  slight scale-down, for a tactile raised/pressable feel.
// ─────────────────────────────────────────────────────────────────────────────
class _Tilt3DCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _Tilt3DCard({required this.child, required this.onTap});

  @override
  State<_Tilt3DCard> createState() => _Tilt3DCardState();
}

class _Tilt3DCardState extends State<_Tilt3DCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: _pressed
                ? [
                    BoxShadow(
                      color: _kBlue.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    // Deep ambient glow — the "lifted off the page" shadow
                    BoxShadow(
                      color: _kBlue.withValues(alpha: 0.16),
                      blurRadius: 22,
                      spreadRadius: -4,
                      offset: const Offset(0, 12),
                    ),
                    // Tight contact shadow for crisp edge definition
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
