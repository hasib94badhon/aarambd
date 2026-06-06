import 'package:aaram_bd/config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

import '../utils/TextHelper.dart';

final String host = Config.host;

class EditProfileScreen extends StatefulWidget {
  final String userName;
  final String userPhone;
  final String userCategory;
  final String userDescription;
  final String userAddress;

  EditProfileScreen({
    required this.userName,
    required this.userPhone,
    required this.userCategory,
    required this.userDescription,
    required this.userAddress,
  });

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _referralController = TextEditingController();

  String? _referralError;
  String? _existingReferralId;
  List<Map<String, dynamic>> _categories = [];
  String? _selectedCategory;
  int? _selectedCatYesService;
  int? _selectedCatYesShop;
  bool _isLoading = true;

  List<XFile> _images = [];
  List<XFile> _nidFiles = [];
  List<XFile> _tinFiles = [];

  bool _canChangeCategory = false;
  bool _isUploading = false;
  bool _isCompressing = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.userName;
    _phoneController.text = widget.userPhone;
    _descriptionController.text = widget.userDescription;

    fetchCategories();
    fetchUserDetails(context);
  }

  Future<void> fetchCategories() async {
    final res = await Config.apiGet('/get_categories_name', context);
    if (res == null) {
      return;
    }

    if (res.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(res.body);
      final List<dynamic> categoryList = data['categories'];

      setState(() {
        _categories = categoryList.cast<Map<String, dynamic>>();

        final selected = _categories.firstWhere(
          (c) => c['cat_name'] == widget.userCategory,
          orElse: () => {
            'cat_id': '0',
            'yes_service': 0,
            'yes_shop': 0,
          },
        );

        _selectedCategory = selected['cat_id'].toString();
        _selectedCatYesService = selected['yes_service'] ?? 0;
        _selectedCatYesShop = selected['yes_shop'] ?? 0;
        _canChangeCategory = (_selectedCategory == '56');
        _categoryController.text = _selectedCategory!;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
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
        });
      } else {
        // ignore: avoid_print
        print("Failed to fetch user details: ${res?.statusCode}");
      }
    } catch (e) {
      // ignore: avoid_print
      print("Error fetching user details: $e");
    }
  }

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
        _images = [XFile(compressed.path)];
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

  Future<void> updateProfile() async {
    if (_isUploading) return;
    setState(() {
      _isUploading = true;
      _referralError = null;
    });

    const endpoint = '/update_user_profile';

    final fields = <String, String>{
      'name': _nameController.text.trim(),
      'category': _selectedCategory ?? '',
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
      final originalFile = File(_images[i].path);
      final compressedFile = await _compressOrFallback(originalFile);
      files['images[$i]'] = compressedFile;
    }

    for (int i = 0; i < _nidFiles.length; i++) {
      final originalFile = File(_nidFiles[i].path);
      final compressedFile = await _compressOrFallback(originalFile);
      files['nids[$i]'] = compressedFile;
    }

    for (int i = 0; i < _tinFiles.length; i++) {
      final originalFile = File(_tinFiles[i].path);
      final compressedFile = await _compressOrFallback(originalFile);
      files['tins[$i]'] = compressedFile;
    }

    try {
      final streamedResponse = await Config.apiMultipartPost(
        endpoint,
        context,
        fields: fields,
        files: files,
      );

      if (streamedResponse == null) {
        return;
      }
      final response = await http.Response.fromStream(streamedResponse);
      final data = json.decode(response.body);

      final msg = (data['message'] ?? '').toString().toLowerCase();
      final success = data['success'] == true;

      if (response.statusCode == 200 && success) {
        if (fields.containsKey('reg_referral_id')) {
          setState(() => _existingReferralId = fields['reg_referral_id']);
          setState(() => _referralError = null);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
        Navigator.pop(context, true);
        return;
      }

      if (response.statusCode == 400) {
        if (msg.contains('wrong referral')) {
          setState(() => _referralError = 'Wrong referral ID');
          return;
        }
        if (msg.contains('cannot use your own referral')) {
          setState(
              () => _referralError = 'You cannot use your own referral ID');
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed: ${data["message"] ?? "Unknown error"}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('⚠️ Error: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // ---------- UI Helpers (visuals only, no logic change) ----------

  Widget _sectionHeader(IconData icon, String title,
      {Color? color, EdgeInsets margin = const EdgeInsets.only(bottom: 8)}) {
    final c = color ?? Colors.blueGrey.shade800;
    return Container(
      margin: margin,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF86A8E7), Color(0xFF91EAE4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w900,
              fontSize: 16.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoBadge(
      {required String text, required Color color, IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: TextStyle(
              color: color.withValues(alpha: 0.95),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label,
      {IconData? icon, bool readOnly = false}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
      fillColor: readOnly ? const Color(0xFFF2F3F7) : const Color(0xFFF7F8FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black12.withValues(alpha: 0.06)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.black12.withValues(alpha: 0.06)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
        borderSide: BorderSide(color: Color(0xFF86A8E7), width: 1.3),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      inputFormatters: [
        WordLimitFormatter(150),
      ],
      decoration: _fieldDecoration(label, icon: _mapIcon(label)),
    );
  }

  IconData? _mapIcon(String label) {
    switch (label.toLowerCase()) {
      case 'name':
        return Icons.person;
      case 'description':
        return Icons.notes_rounded;
      default:
        return null;
    }
  }

  Widget _buildFilePreview(List<XFile> files) {
    // same function name & purpose; nicer layout (visual only)
    if (files.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: files.map((file) {
        return Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
            ],
            gradient: const LinearGradient(
              colors: [Color(0xFFE3F2FD), Color(0xFFE0F7FA)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.file(
              File(file.path),
              fit: BoxFit.cover,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _uploadButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color start = const Color(0xFF86A8E7),
    Color end = const Color(0xFF91EAE4),
  }) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          minimumSize: const Size(140, 44),
          backgroundColor: Colors.transparent,
        ).merge(
          ButtonStyle(
            backgroundColor:
                MaterialStateProperty.resolveWith((_) => Colors.transparent),
            shadowColor: MaterialStateProperty.all(Colors.transparent),
            overlayColor: MaterialStateProperty.all(Colors.white24),
          ),
        ),
      ),
    ).buildGradientButton(start, end);
  }

  Widget _submitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: updateProfile,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        child: const Text('Update Profile'),
      ).buildGradientButton(const Color(0xFF7F7FD5), const Color(0xFF86A8E7)),
    );
  }

  // ------------------- BUILD -------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text('Update Profile',
            style: TextStyle(fontWeight: FontWeight.w800)),
        foregroundColor: Colors.black87,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFE8F1FF), Color(0xFFF8FBFF)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top card with general info
                      _glassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader(Icons.person_rounded, 'Basic Info'),
                            const SizedBox(height: 8),
                            _buildTextField(
                                label: 'Name', controller: _nameController),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _phoneController,
                              readOnly: true,
                              decoration: _fieldDecoration(
                                  'Phone (not editable)',
                                  icon: Icons.phone,
                                  readOnly: true),
                            ),
                            const SizedBox(height: 16),
                            // Category state badge
                            Row(
                              children: [
                                _infoBadge(
                                  text: _canChangeCategory
                                      ? 'You can change your category once.'
                                      : 'You cannot change your category.',
                                  color: _canChangeCategory
                                      ? Colors.teal
                                      : Colors.redAccent,
                                  icon: _canChangeCategory
                                      ? Icons.lock_open
                                      : Icons.lock,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            // Category Autocomplete
                            _sectionHeader(Icons.category, 'Category'),
                            AbsorbPointer(
                              absorbing: !_canChangeCategory,
                              child: Opacity(
                                opacity: _canChangeCategory ? 1.0 : 0.6,
                                child: Autocomplete<String>(
                                  optionsBuilder:
                                      (TextEditingValue textEditingValue) {
                                    if (!_canChangeCategory) {
                                      return const Iterable<String>.empty();
                                    }
                                    final input =
                                        textEditingValue.text.toLowerCase();
                                    final allNames = _categories
                                        .map((c) => c['cat_name'] as String);
                                    if (input.isEmpty) return allNames;
                                    final starts = allNames.where((name) =>
                                        name.toLowerCase().startsWith(input));
                                    final contains = allNames.where((name) =>
                                        name.toLowerCase().contains(input) &&
                                        !name.toLowerCase().startsWith(input));
                                    return [...starts, ...contains];
                                  },
                                  onSelected: (String selection) {
                                    final selectedCat = _categories.firstWhere(
                                      (c) => c['cat_name'] == selection,
                                      orElse: () => {
                                        'cat_id': '0',
                                        'yes_service': 0,
                                        'yes_shop': 0
                                      },
                                    );
                                    setState(() {
                                      _selectedCategory =
                                          selectedCat['cat_id'].toString();
                                      _categoryController.text = selection;
                                      _selectedCatYesService =
                                          selectedCat['yes_service'] ?? 0;
                                      _selectedCatYesShop =
                                          selectedCat['yes_shop'] ?? 0;
                                    });
                                  },
                                  fieldViewBuilder: (
                                    BuildContext context,
                                    TextEditingController fieldController,
                                    FocusNode focusNode,
                                    VoidCallback onFieldSubmitted,
                                  ) {
                                    fieldController.text = _categories
                                            .firstWhere(
                                                (c) =>
                                                    c['cat_id'].toString() ==
                                                    _selectedCategory,
                                                orElse: () => {
                                                      'cat_name': ''
                                                    })['cat_name']
                                            .toString() ??
                                        '';
                                    return TextFormField(
                                      controller: fieldController,
                                      focusNode: focusNode,
                                      textInputAction: TextInputAction.search,
                                      onFieldSubmitted: (_) =>
                                          onFieldSubmitted(),
                                      decoration: _fieldDecoration(
                                          'Select Category',
                                          icon: Icons.search),
                                    );
                                  },
                                  optionsViewBuilder: (
                                    BuildContext context,
                                    AutocompleteOnSelected<String> onSelected,
                                    Iterable<String> options,
                                  ) {
                                    return Align(
                                      alignment: Alignment.topLeft,
                                      child: Material(
                                        elevation: 8,
                                        borderRadius: BorderRadius.circular(12),
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            maxHeight: MediaQuery.of(context)
                                                    .size
                                                    .height *
                                                0.4,
                                            maxWidth: MediaQuery.of(context)
                                                    .size
                                                    .width -
                                                32,
                                          ),
                                          child: ListView.separated(
                                            padding: EdgeInsets.zero,
                                            itemCount: options.length,
                                            separatorBuilder: (_, __) =>
                                                const Divider(height: 1),
                                            itemBuilder: (ctx, i) {
                                              final option =
                                                  options.elementAt(i);
                                              return ListTile(
                                                dense: true,
                                                title: Text(
                                                  option,
                                                  style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                                onTap: () => onSelected(option),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            _sectionHeader(Icons.notes_rounded, 'Description'),
                            _buildTextField(
                              label: 'Description',
                              controller: _descriptionController,
                              maxLines: 3,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Referral
                      if (_existingReferralId == null ||
                          _existingReferralId == "0") ...[
                        _glassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionHeader(
                                  Icons.card_giftcard_rounded, 'Referral'),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _referralController,
                                decoration: _fieldDecoration(
                                  "Enter Referral ID (optional)",
                                  icon: Icons.confirmation_number_outlined,
                                ).copyWith(errorText: _referralError),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Document Uploads (NID/TIN)
                      if (_selectedCatYesService == 1 &&
                          _selectedCatYesShop == 0) ...[
                        _glassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionHeader(
                                  Icons.badge_rounded, 'NID Documents'),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _uploadButton(
                                    icon: Icons.upload_file,
                                    label: 'Pick NID Files',
                                    onPressed: () => _pickFiles(true),
                                    start: const Color(0xFF00B09B),
                                    end: const Color(0xFF96C93D),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildFilePreview(_nidFiles),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ] else if (_selectedCatYesService == 0 &&
                          _selectedCatYesShop == 1) ...[
                        _glassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _sectionHeader(
                                  Icons.receipt_long_rounded, 'TIN Documents'),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  _uploadButton(
                                    icon: Icons.upload_file,
                                    label: 'Pick TIN Files',
                                    onPressed: () => _pickFiles(false),
                                    start: const Color(0xFF00B09B),
                                    end: const Color(0xFF96C93D),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildFilePreview(_tinFiles),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Images Upload
                      _glassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _sectionHeader(
                                Icons.photo_library_rounded, 'Profile Images'),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                _uploadButton(
                                  icon: Icons.photo_library_rounded,
                                  label: 'Upload Images',
                                  onPressed: _pickImages,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildFilePreview(_images),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Submit
                      _submitButton(),
                    ],
                  ),
                ),

          // Overlays
          if (_isCompressing)
            Container(
              color: Colors.black26,
              child: const Center(child: CircularProgressIndicator()),
            ),
          if (_isUploading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  // Pretty card container (visual only)
  Widget _glassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 12, offset: Offset(0, 6)),
        ],
        border: Border.all(color: Colors.black12.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}

// ------------ tiny extension to paint gradient on ElevatedButton ------------
extension _GradientButton on Widget {
  Widget buildGradientButton(Color start, Color end) {
    return Ink(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [start, end]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
        child: this,
      ),
    );
  }
}
