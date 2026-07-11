import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import '../utils/TextHelper.dart';

final String host = Config.host;

const _kPrimary     = Color(0xFF2563EB);
const _kPrimaryDark = Color(0xFF1E40AF);
const _kBg          = Color(0xFFF1F5F9);
const _kCard        = Colors.white;
const _kTextHead    = Color(0xFF0F172A);
const _kTextSub     = Color(0xFF64748B);
const _kBorder      = Color(0xFFE2E8F0);
const _kSuccess     = Color(0xFF059669);
const _kLocked      = Color(0xFF94A3B8);

class EditProfileScreen extends StatefulWidget {
  final String userName;
  final String userPhone;
  final String userCategory;
  final String userCategoryId;
  final String userDescription;
  final String userAddress;

  EditProfileScreen({
    required this.userName,
    required this.userPhone,
    required this.userCategory,
    required this.userCategoryId,
    required this.userDescription,
    required this.userAddress,
  });

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController        = TextEditingController();
  final TextEditingController _phoneController       = TextEditingController();
  final TextEditingController _categoryController    = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _referralController    = TextEditingController();

  String? _referralError;
  String? _existingReferralId;
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategory;
  int? _selectedCatYesService;
  int? _selectedCatYesShop;
  List<XFile> _images   = [];
  List<XFile> _nidFiles = [];
  List<XFile> _tinFiles = [];

  // Existing photos already on the server
  List<String> _existingPhotoUrls = [];
  List<String> _existingNidUrls   = [];
  List<String> _existingTinUrls   = [];

  bool _canChangeCategory = false;
  bool _isUploading       = false;
  bool _isCompressing     = false;
  String _displayCategoryName = '';

  // ─── Lifecycle ───────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _nameController.text        = widget.userName;
    _phoneController.text       = widget.userPhone;
    _descriptionController.text = widget.userDescription;

    _selectedCategory       = widget.userCategoryId;
    _canChangeCategory      = (widget.userCategoryId == '56');
    _displayCategoryName    = widget.userCategory;

    fetchCategories();
    fetchUserDetails(context);
  }

  // ─── Data Fetching ───────────────────────────────────────────────────────────

  Future<void> fetchCategories() async {
    http.Response? res = await Config.apiGet('/get_categories_name', context);
    if (res == null || res.statusCode != 200) {
      if (!mounted) return;
      res = await Config.apiGet('/category/get_categories_name', context);
    }
    if (res == null) return;

    if (res.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(res.body);
      final List<dynamic> categoryList = data['categories'];

      setState(() {
        _categories = categoryList.cast<Map<String, dynamic>>();

        final matched = _categories.firstWhere(
          (c) => c['cat_id'].toString() == widget.userCategoryId,
          orElse: () => {
            'cat_id': widget.userCategoryId,
            'cat_name': widget.userCategory,
            'yes_service': 0,
            'yes_shop': 0,
          },
        );

        _selectedCatYesService  = matched['yes_service'] ?? 0;
        _selectedCatYesShop     = matched['yes_shop'] ?? 0;
        _displayCategoryName    = matched['cat_name'] ?? widget.userCategory;
      });
    }
  }

  Future<void> fetchUserDetails(BuildContext context) async {
    try {
      final url = '/get_user_by_phone?phone=${widget.userPhone}';
      final res = await Config.apiGet(url, context);

      if (res != null && res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _existingReferralId = data['referral_id']?.toString();
          if (_existingReferralId != null &&
              _existingReferralId != "0" &&
              _existingReferralId!.isNotEmpty) {
            _referralController.text = _existingReferralId!;
          }

          // Parse existing uploaded file URLs (comma-separated strings)
          _existingPhotoUrls = _parseUrls(data['photo']);
          _existingNidUrls   = _parseUrls(data['nid']);
          _existingTinUrls   = _parseUrls(data['tin']);
        });
      }
    } catch (_) {}
  }

  List<String> _parseUrls(dynamic raw) {
    if (raw == null) return [];
    final str = raw.toString().trim();
    if (str.isEmpty) return [];
    return str
        .split(',')
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty && u.startsWith('http'))
        .toList();
  }

  // ─── Image Picking ───────────────────────────────────────────────────────────

  Future<void> _pickFiles(bool isNID) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _isCompressing = true);
      final compressed = await _compressOrFallback(File(picked.path));
      setState(() {
        if (isNID) {
          _nidFiles = [XFile(compressed.path)];
        } else {
          _tinFiles = [XFile(compressed.path)];
        }
        _isCompressing = false;
      });
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _isCompressing = true);
      final compressed = await _compressOrFallback(File(picked.path));
      setState(() {
        _images        = [XFile(compressed.path)];
        _isCompressing = false;
      });
    }
  }

  Future<File> _compressOrFallback(File file) async {
    try {
      return await Config.compressImageIfNeeded(file);
    } catch (_) {
      return file;
    }
  }

  // ─── Submit ──────────────────────────────────────────────────────────────────

  Future<void> updateProfile() async {
    if (_isUploading) return;
    setState(() {
      _isUploading   = true;
      _referralError = null;
    });

    const endpoint = '/update_user_profile';

    final fields = <String, String>{
      'name':        _nameController.text.trim(),
      'category':    _selectedCategory ?? '',
      'description': _descriptionController.text.trim(),
    };

    final isFirstTimeReferral =
        _existingReferralId == null || _existingReferralId == "0";
    final referralInput = _referralController.text.trim();
    if (isFirstTimeReferral && referralInput.isNotEmpty) {
      fields['reg_referral_id'] = referralInput;
    }

    final files = <String, File>{};

    for (int i = 0; i < _images.length; i++) {
      files['images[$i]'] = await _compressOrFallback(File(_images[i].path));
    }
    for (int i = 0; i < _nidFiles.length; i++) {
      files['nids[$i]'] = await _compressOrFallback(File(_nidFiles[i].path));
    }
    for (int i = 0; i < _tinFiles.length; i++) {
      files['tins[$i]'] = await _compressOrFallback(File(_tinFiles[i].path));
    }

    try {
      final streamed = await Config.apiMultipartPost(
        endpoint, context, fields: fields, files: files,
      );
      if (streamed == null) return;
      if (!mounted) return;

      final response = await http.Response.fromStream(streamed);
      final data     = json.decode(response.body);
      final msg      = (data['message'] ?? '').toString().toLowerCase();
      final success  = data['success'] == true;

      if (response.statusCode == 200 && success) {
        if (fields.containsKey('reg_referral_id')) {
          setState(() {
            _existingReferralId = fields['reg_referral_id'];
            _referralError      = null;
          });
        }
        if (!mounted) return;
        showAppToast(context, 'Profile updated successfully',
            icon: Icons.check_circle_outline_rounded);
        Navigator.pop(context, true);
        return;
      }

      if (response.statusCode == 400) {
        if (msg.contains('wrong referral')) {
          setState(() => _referralError = 'Wrong referral ID');
          return;
        }
        if (msg.contains('cannot use your own referral')) {
          setState(() => _referralError = 'You cannot use your own referral ID');
          return;
        }
      }

      if (!mounted) return;
      showAppToast(
          context, 'Failed: ${data["message"] ?? "Unknown error"}',
          icon: Icons.error_outline_rounded);
    } catch (e) {
      if (!mounted) return;
      showAppToast(context, 'Error: $e',
          icon: Icons.error_outline_rounded);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildHeader(context),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(_buildSections()),
                ),
              ),
            ],
          ),
          if (_isCompressing || _isUploading) _buildLoadingOverlay(),
        ],
      ),
      bottomNavigationBar: _buildSaveBar(),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────────

  Widget _headerAvatarFallback(String initials) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 28,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final initials = widget.userName.trim().isNotEmpty
        ? widget.userName.trim()[0].toUpperCase()
        : 'U';
    final photoUrl =
        _existingPhotoUrls.isNotEmpty ? _existingPhotoUrls.first : null;

    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: _kPrimaryDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Edit Profile',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
      ),
      centerTitle: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_kPrimaryDark, _kPrimary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── Profile photo (from DB if available) ──────────────────
                  Container(
                    width: 82,
                    height: 82,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: photoUrl != null
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              width: 82,
                              height: 82,
                              errorBuilder: (_, __, ___) =>
                                  _headerAvatarFallback(initials),
                            )
                          : _headerAvatarFallback(initials),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // ── Name + phone, to the right of the photo ────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone_rounded,
                                  size: 13,
                                  color: Colors.white.withValues(alpha: 0.85)),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  widget.userPhone,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.90),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
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

  // ─── Sections ────────────────────────────────────────────────────────────────

  List<Widget> _buildSections() {
    return [
      const SizedBox(height: 16),
      _infoCard(),
      const SizedBox(height: 12),
      _categoryCard(),
      const SizedBox(height: 12),
      _aboutCard(),
      if (_existingReferralId == null || _existingReferralId == "0") ...[
        const SizedBox(height: 12),
        _referralCard(),
      ],
      if (_selectedCatYesService == 1 && _selectedCatYesShop == 0) ...[
        const SizedBox(height: 12),
        _documentCard(
          icon: Icons.credit_card_rounded,
          iconColor: const Color(0xFF10B981),
          title: 'NID Document',
          subtitle: 'Required for service providers',
          files: _nidFiles,
          existingUrls: _existingNidUrls,
          onTap: () => _pickFiles(true),
          fieldKey: 'nid',
        ),
      ] else if (_selectedCatYesService == 0 && _selectedCatYesShop == 1) ...[
        const SizedBox(height: 12),
        _documentCard(
          icon: Icons.receipt_long_rounded,
          iconColor: const Color(0xFF10B981),
          title: 'TIN Document',
          subtitle: 'Required for shop owners',
          files: _tinFiles,
          existingUrls: _existingTinUrls,
          onTap: () => _pickFiles(false),
          fieldKey: 'tin',
        ),
      ],
      const SizedBox(height: 12),
      _photoCard(),
    ];
  }

  // ─── Info Card ───────────────────────────────────────────────────────────────

  Widget _infoCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.person_outline_rounded, 'Basic Information', _kPrimary),
          const SizedBox(height: 16),
          _field(
            label: 'Full Name',
            controller: _nameController,
            prefixIcon: Icons.badge_outlined,
          ),
          const SizedBox(height: 14),
          _field(
            label: 'Phone Number',
            controller: _phoneController,
            prefixIcon: Icons.phone_outlined,
            readOnly: true,
            suffix: _lockedTag(),
          ),
        ],
      ),
    );
  }

  // ─── Category Card ───────────────────────────────────────────────────────────

  Widget _categoryCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.category_outlined, 'Category', const Color(0xFF7C3AED)),
          const SizedBox(height: 14),
          _categoryBadge(),
          const SizedBox(height: 14),
          AbsorbPointer(
            absorbing: !_canChangeCategory,
            child: AnimatedOpacity(
              opacity: _canChangeCategory ? 1.0 : 0.55,
              duration: const Duration(milliseconds: 200),
              child: _categoryAutocomplete(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryBadge() {
    final canChange = _canChangeCategory;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: canChange
            ? _kSuccess.withValues(alpha: 0.08)
            : _kLocked.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: canChange
              ? _kSuccess.withValues(alpha: 0.3)
              : _kLocked.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            canChange ? Icons.lock_open_rounded : Icons.lock_rounded,
            size: 14,
            color: canChange ? _kSuccess : _kLocked,
          ),
          const SizedBox(width: 6),
          Text(
            canChange
                ? 'One-time change available'
                : 'Category is locked',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: canChange ? _kSuccess : _kLocked,
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryAutocomplete() {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue tv) {
        if (!_canChangeCategory) return const Iterable<String>.empty();
        final input    = tv.text.toLowerCase();
        final allNames = _categories.map((c) => c['cat_name'] as String);
        if (input.isEmpty) return allNames;
        final starts   = allNames.where((n) => n.toLowerCase().startsWith(input));
        final contains = allNames.where(
            (n) => n.toLowerCase().contains(input) && !n.toLowerCase().startsWith(input));
        return [...starts, ...contains];
      },
      onSelected: (String selection) {
        final cat = _categories.firstWhere(
          (c) => c['cat_name'] == selection,
          orElse: () => {'cat_id': '0', 'yes_service': 0, 'yes_shop': 0},
        );
        setState(() {
          _selectedCategory       = cat['cat_id'].toString();
          _displayCategoryName    = selection;
          _categoryController.text = selection;
          _selectedCatYesService  = cat['yes_service'] ?? 0;
          _selectedCatYesShop     = cat['yes_shop'] ?? 0;
        });
      },
      fieldViewBuilder: (ctx, fieldController, focusNode, onSubmit) {
        if (!focusNode.hasFocus) fieldController.text = _displayCategoryName;
        return TextFormField(
          controller: fieldController,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onFieldSubmitted: (_) => onSubmit(),
          style: const TextStyle(color: _kTextHead, fontSize: 15),
          decoration: _inputDecoration(
            label: 'Search category...',
            prefixIcon: Icons.search_rounded,
          ),
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 12,
            shadowColor: Colors.black.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.38,
                maxWidth: MediaQuery.of(ctx).size.width - 32,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: options.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: _kBorder),
                  itemBuilder: (_, i) {
                    final opt = options.elementAt(i);
                    return InkWell(
                      onTap: () => onSelected(opt),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13),
                        child: Row(
                          children: [
                            const Icon(Icons.category_outlined,
                                size: 16, color: _kTextSub),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                opt,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: _kTextHead,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ─── About Card ──────────────────────────────────────────────────────────────

  Widget _aboutCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.edit_note_rounded, 'About', const Color(0xFF0EA5E9)),
          const SizedBox(height: 16),
          _field(
            label: 'Describe yourself or your business...',
            controller: _descriptionController,
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  // ─── Referral Card ───────────────────────────────────────────────────────────

  Widget _referralCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _cardHeader(
                  Icons.card_giftcard_rounded, 'Referral Code', const Color(0xFFF59E0B)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Optional',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFB45309),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Enter the referral code shared by a data collector',
            style: TextStyle(
              fontSize: 12,
              color: _kTextSub.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 14),
          _field(
            label: 'Referral ID',
            controller: _referralController,
            prefixIcon: Icons.confirmation_number_outlined,
            errorText: _referralError,
          ),
        ],
      ),
    );
  }

  // ─── Document Card ───────────────────────────────────────────────────────────

  Widget _documentCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<XFile> files,
    required List<String> existingUrls,
    required VoidCallback onTap,
    required String fieldKey,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(icon, title, iconColor),
          const SizedBox(height: 4),
          Text(subtitle,
              style: const TextStyle(fontSize: 12, color: _kTextSub)),
          const SizedBox(height: 14),
          _uploadZone(files: files, existingUrls: existingUrls, onTap: onTap),
        ],
      ),
    );
  }

  // ─── Photo Card ──────────────────────────────────────────────────────────────

  Widget _photoCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.photo_camera_outlined, 'Profile Photo',
              const Color(0xFFEC4899)),
          const SizedBox(height: 4),
          const Text('Upload a clear photo of yourself or your business',
              style: TextStyle(fontSize: 12, color: _kTextSub)),
          const SizedBox(height: 14),
          _uploadZone(
            files: _images,
            existingUrls: _existingPhotoUrls,
            onTap: _pickImages,
          ),
        ],
      ),
    );
  }

  // ─── Upload Zone ─────────────────────────────────────────────────────────────

  Widget _uploadZone({
    required List<XFile> files,
    required List<String> existingUrls,
    required VoidCallback onTap,
  }) {
    // Priority 1: user just picked a new local file
    if (files.isNotEmpty) {
      return _localFilePreview(file: files.first, onTap: onTap);
    }

    // Priority 2: photos already on the server
    if (existingUrls.isNotEmpty) {
      return _serverPhotosPreview(urls: existingUrls, onTap: onTap);
    }

    // Priority 3: empty — show upload zone
    return _emptyUploadZone(onTap: onTap);
  }

  Widget _emptyUploadZone({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.07),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.cloud_upload_outlined,
                    size: 28, color: _kPrimary),
              ),
              const SizedBox(height: 10),
              const Text(
                'Tap to upload',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _kPrimary),
              ),
              const SizedBox(height: 2),
              const Text('JPG or PNG supported',
                  style: TextStyle(fontSize: 12, color: _kTextSub)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _localFilePreview({required XFile file, required VoidCallback onTap}) {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(file.path),
            width: 80,
            height: 80,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: _kSuccess, size: 15),
                  const SizedBox(width: 5),
                  const Text('New file ready',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _kSuccess,
                          fontSize: 13)),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                file.path.split('/').last,
                style: const TextStyle(fontSize: 12, color: _kTextSub),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              _changeButton(onTap: onTap),
            ],
          ),
        ),
      ],
    );
  }

  Widget _serverPhotosPreview(
      {required List<String> urls, required VoidCallback onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status row
        Row(
          children: [
            const Icon(Icons.cloud_done_rounded, color: _kSuccess, size: 15),
            const SizedBox(width: 5),
            Text(
              '${urls.length} file${urls.length > 1 ? 's' : ''} already uploaded',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kSuccess),
            ),
          ],
        ),
        const SizedBox(height: 10),
        // Thumbnail row
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...urls.map((url) => _networkThumb(url)),
            // "+" tile to add / replace
            GestureDetector(
              onTap: onTap,
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: _kPrimary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _kPrimary.withValues(alpha: 0.25), width: 1.2),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined,
                        color: _kPrimary, size: 20),
                    SizedBox(height: 3),
                    Text('Replace',
                        style: TextStyle(
                            fontSize: 10,
                            color: _kPrimary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _networkThumb(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        url,
        width: 72,
        height: 72,
        fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) => progress == null
            ? child
            : Container(
                width: 72,
                height: 72,
                color: _kBorder,
                child: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _kPrimary),
                  ),
                ),
              ),
        errorBuilder: (_, __, ___) => Container(
          width: 72,
          height: 72,
          color: _kBorder,
          child: const Icon(Icons.broken_image_outlined,
              color: _kTextSub, size: 28),
        ),
      ),
    );
  }

  Widget _changeButton({required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: _kPrimary),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Change file',
          style: TextStyle(
              fontSize: 12, color: _kPrimary, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  // ─── Save Bar ────────────────────────────────────────────────────────────────

  Widget _buildSaveBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: _kCard,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: _isUploading ? null : updateProfile,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            disabledBackgroundColor: _kPrimary.withValues(alpha: 0.5),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: _isUploading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : const Text(
                  'Save Changes',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
        ),
      ),
    );
  }

  // ─── Loading Overlay ─────────────────────────────────────────────────────────

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 30),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: _kPrimary, strokeWidth: 3),
              const SizedBox(height: 16),
              Text(
                _isCompressing ? 'Compressing image...' : 'Uploading...',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: _kTextHead),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Shared UI Helpers ───────────────────────────────────────────────────────

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _cardHeader(IconData icon, String title, Color color) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _kTextHead,
          ),
        ),
      ],
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    IconData? prefixIcon,
    bool readOnly = false,
    int maxLines = 1,
    Widget? suffix,
    String? errorText,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      maxLines: maxLines,
      inputFormatters: readOnly ? [] : [WordLimitFormatter(150)],
      style: const TextStyle(color: _kTextHead, fontSize: 15),
      decoration: _inputDecoration(
        label: label,
        prefixIcon: prefixIcon,
        readOnly: readOnly,
        suffix: suffix,
        errorText: errorText,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    IconData? prefixIcon,
    bool readOnly = false,
    Widget? suffix,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _kTextSub, fontSize: 14),
      prefixIcon: prefixIcon != null
          ? Icon(prefixIcon, color: _kTextSub, size: 20)
          : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: readOnly
          ? const Color(0xFFF8FAFC)
          : const Color(0xFFFAFBFF),
      errorText: errorText,
      errorStyle: const TextStyle(fontSize: 12),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kPrimary, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _kBorder),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Widget _lockedTag() {
    return Container(
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _kLocked.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'Locked',
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: _kLocked),
      ),
    );
  }
}

// ─── Dashed Border Painter ────────────────────────────────────────────────────

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const radius = 12.0;
    const dashW  = 6.0;
    const dashS  = 5.0;

    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        const Radius.circular(radius),
      ));

    final dash = Path();
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        dash.addPath(metric.extractPath(d, d + dashW), Offset.zero);
        d += dashW + dashS;
      }
    }
    canvas.drawPath(dash, paint);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter _) => false;
}
