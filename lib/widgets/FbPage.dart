import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/widgets/FbCategoryPostsPage.dart';
import 'package:flutter/material.dart';

class FbCategoryPage extends StatefulWidget {
  final List<dynamic> pages;
  const FbCategoryPage({required this.pages, Key? key}) : super(key: key);

  @override
  _FbCategoryPageState createState() => _FbCategoryPageState();
}

class _FbCategoryPageState extends State<FbCategoryPage> {
  late List<String> _allCats;
  late List<String> _filteredCats;
  final _searchCtrl = TextEditingController();

  // Single, consistent app accent
  static const Color _accent = Color(0xFF2563EB); // blue-600
  static const Color _cardBorder = Color(0x1F000000); // faint border
  static const Color _cardShadow = Color(0x12000000); // faint shadow
  static const Color _bg = Color(0xFFF5F7FB);

  @override
  void initState() {
    super.initState();
    // Extract unique categories
    _allCats = widget.pages.map((e) => e['cat'] as String).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    _filteredCats = List.from(_allCats);
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredCats = List.from(_allCats);
      } else {
        _filteredCats = _allCats.where((c) => c.toLowerCase().contains(q)).toList();
      }
    });
  }

  void _gotoCategory(String category) {
    final catPages = widget.pages.where((p) => p['cat'] == category).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FbCategoryPostsPage(
          category: category,
          pages: catPages,
        ),
      ),
    );
  }

  int _gridCountForWidth(double w) {
    if (w >= 1100) return 5;
    if (w >= 900) return 4;
    if (w >= 650) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor:const Color.fromARGB(255, 136, 188, 255),
      appBar: AppBar(
        elevation: 0,
      backgroundColor:const Color.fromARGB(255, 136, 188, 255),
        leading: const BackButton(color: Colors.black87),
        title: const Text(
          'Visit Categories',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: _cardBorder),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: _cardShadow, blurRadius: 10, offset: Offset(0, 4)),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search categories...',
                    hintStyle: const TextStyle(color: Colors.black54),
                    prefixIcon: const Icon(Icons.search_rounded, color: Colors.black54),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            splashRadius: 18,
                            icon: const Icon(Icons.clear_rounded, color: Colors.black54),
                            onPressed: () => setState(() {
                              _searchCtrl.clear();
                            }),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  ),
                  onSubmitted: (_) {
                    if (_filteredCats.isNotEmpty) {
                      _gotoCategory(_filteredCats.first);
                    }
                  },
                ),
              ),
            ),

            // Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: _filteredCats.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: _gridCountForWidth(w),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.98,
                ),
                itemBuilder: (context, index) {
                  final category = _filteredCats[index];
                  final catPages = widget.pages.where((p) => p['cat'] == category).toList();
                  final pagesCount = catPages.length;

                  // SAFE view count extraction (keeps your logic of taking it from the first page)
                  int viewsInt = 0;
                  if (catPages.isNotEmpty) {
                    final dynamic raw = catPages.first['total_view_per_cat'] ?? 0;
                    // Handle int, string (with commas), null safely
                    viewsInt = int.tryParse(raw.toString().replaceAll(',', '').trim()) ?? 0;
                  }

                  return _CategoryCard(
                    category: category,
                    pagesCount: pagesCount,
                    totalViews: viewsInt, // pass as int
                    onTap: () => _gotoCategory(category),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final String category;
  final int pagesCount;
  final int totalViews; // now strongly typed
  final VoidCallback onTap;

  const _CategoryCard({
    required this.category,
    required this.pagesCount,
    required this.totalViews,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    const Color accent = _FbCategoryPageState._accent;
    const Color cardBorder = _FbCategoryPageState._cardBorder;
    const Color cardShadow = _FbCategoryPageState._cardShadow;

    // A soft animated elevation/translation for tactile feedback
    final double yOffset = _pressed ? 1.5 : 0.0;
    final List<BoxShadow> shadows = [
      BoxShadow(
        color: Colors.black.withValues(alpha: _pressed ? 0.06 : 0.08),
        blurRadius: _pressed ? 8 : 12,
        offset: Offset(0, _pressed ? 2 : 4),
      ),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(0, yOffset, 0),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        scale: _pressed ? 0.99 : 1.0,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          elevation: 0,
          child: InkWell(
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapCancel: () => setState(() => _pressed = false),
            onTapUp: (_) => setState(() => _pressed = false),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: cardBorder),
                borderRadius: BorderRadius.circular(16),
                boxShadow: shadows,
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top decorative gradient band (badge removed)
                  Container(
                    height: 25,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          accent.withValues(alpha: 0.12),
                          accent.withValues(alpha: 0.06),
                        ],
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        width: 120,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              Colors.white,
                              Colors.white,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Category title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Center(
                      child: Text(
                        widget.category,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          height: 1.15,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Divider line
                  Container(
                    height: 1,
                    margin: const EdgeInsets.only(left: 12, right: 12, bottom: 0),
                    color: Colors.black12.withValues(alpha: 0.08),
                  ),

                  // Stats section — redesigned to avoid overflow
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
                    child: Row(
                      children: [
                        // Pages block
                        Expanded(
                          child: _StatBlock(
                            icon: Icons.library_books_outlined,
                            value: Config.formatLargeNumber(widget.pagesCount),
                            label: 'Pages',
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          color: Colors.black12.withValues(alpha: 0.12),
                        ),
                        // Views block
                        Expanded(
                          child: _StatBlock(
                            icon: Icons.visibility_outlined,
                            value: Config.formatLargeNumber(widget.totalViews),
                            label: 'Views',
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Chevron hint
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: accent.withValues(alpha: 0.15)),
                          ),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: accent.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _StatBlock({
    Key? key,
    required this.icon,
    required this.value,
    required this.label,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color accent = _FbCategoryPageState._accent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: accent.withValues(alpha: 0.9)),
        const SizedBox(height: 4),
        // Value (bold) — wrapped to avoid overflow
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827), // gray-900
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Label (small, muted)
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B7280), // gray-500
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatPill({required this.icon, required this.label, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color accent = _FbCategoryPageState._accent;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.2,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937), // gray-800
              ),
            ),
          ),
        ],
      ),
    );
  }
}
