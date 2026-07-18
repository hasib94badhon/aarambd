import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/widgets/app_toast.dart';
import 'package:aaram_bd/widgets/confirm_delete_dialog.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

final String host = Config.host;

const Color _brand = Color(0xFF1A56DB);
const Color _brandDark = Color(0xFF1040B0);

class Editpost extends StatefulWidget {
  final String postId;
  final String initialText;
  final List<String> mediaUrls;
  final List<String> mediaCaptions;

  const Editpost({
    required this.postId,
    required this.initialText,
    required this.mediaUrls,
    required this.mediaCaptions,
  });

  @override
  State<Editpost> createState() => _EditpostState();
}

class _EditpostState extends State<Editpost> {
  late TextEditingController _mainTextController;
  List<TextEditingController> _captionControllers = [];
  List<String> _existingMedia = [];
  List<XFile> _newMedia = [];
  List<String> mediaToRemove = [];
  bool _isLoading = true;
  bool _isUpdating = false; // Track update state

  final FocusNode _mainTextFocus = FocusNode();
  bool _mainTextFocused = false;

  final picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _mainTextController = TextEditingController(text: widget.initialText);
    _fetchPostDetails();
    _existingMedia = widget.mediaUrls;
    _captionControllers = widget.mediaCaptions
        .map((caption) => TextEditingController(text: caption))
        .toList();
    _mainTextFocus.addListener(() {
      if (mounted) setState(() => _mainTextFocused = _mainTextFocus.hasFocus);
    });
  }

  @override
  void dispose() {
    _mainTextController.dispose();
    _mainTextFocus.dispose();
    for (final c in _captionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickNewMedia() async {
    if (_isUpdating) return;

    final files = await picker.pickMultiImage();
    if (files != null && files.isNotEmpty) {
      setState(() {
        _newMedia.addAll(files);
        for (var _ in files) {
          _captionControllers.add(TextEditingController());
        }
      });
    }
  }

  Future<void> _fetchPostDetails() async {
    try {
      final response =
          await Config.apiGet('/get_post?post_id=${widget.postId}', context);

      if (response != null && response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Fetched post: $data");

        final post = data['post'];
        final mediaRaw = post['post_media'];
        final descriptionRaw = post['post_des'];
        final mainTextRaw = post['post_main_description'] ?? '';

        // final mediaUrls = mediaRaw != null && mediaRaw is String
        //     ? mediaRaw.split(',').map((e) => e.trim()).toList()
        //     : <String>[];
        final mediaUrls = (post['post_media'] is String &&
                (post['post_media'] as String).isNotEmpty)
            ? (post['post_media'] as String)
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList()
            : <String>[];

        final captions = descriptionRaw != null && descriptionRaw is String
            ? descriptionRaw.split(',').map((e) => e.trim()).toList()
            : <String>[];

        setState(() {
          _existingMedia = mediaUrls;
          _mainTextController.text = mainTextRaw;

          _captionControllers = captions
              .map((caption) => TextEditingController(text: caption))
              .toList();

          while (_captionControllers.length < _existingMedia.length) {
            _captionControllers.add(TextEditingController());
          }

          _isLoading = false;
        });
      } else {
        print("Failed to fetch post data: ${response?.body}");
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error fetching post: $e");
      setState(() => _isLoading = false);
    }
  }

  // Future<void> _updatePost() async {
  //   if (_isUpdating) return;

  //   setState(() => _isUpdating = true);

  //   final uri = Uri.parse('$host/edit_post');
  //   final request = http.MultipartRequest('POST', uri);
  //   final token = await Config.getAccessToken(); // implement this in Config
  //   request.headers['Authorization'] = 'Bearer $token';

  //   request.fields['post_id'] = widget.postId;
  //   request.fields['main_description'] = _mainTextController.text.trim();

  //   // Add new media files with compression
  //   for (int i = 0; i < _newMedia.length; i++) {
  //     final file = _newMedia[i];
  //     final originalFile = File(file.path);

  //     File processedFile;
  //     try {
  //       processedFile = await Config.compressImageIfNeeded(originalFile);
  //     } catch (e) {
  //       processedFile = originalFile; // Fallback to original
  //     }

  //     // Get MIME type
  //     final mimeType = lookupMimeType(processedFile.path) ?? 'image/jpeg';

  //     // Add to request
  //     request.files.add(await http.MultipartFile.fromPath(
  //       'post_media[]',
  //       processedFile.path,
  //       filename: processedFile.path.split('/').last,
  //       contentType: MediaType.parse(mimeType),
  //     ));
  //   }

  //   // Add captions
  //   for (int i = 0; i < _captionControllers.length; i++) {
  //     final original = _captionControllers[i].text.trim();
  //     final cleaned = original.replaceAll(',', '');
  //     request.fields['post_description[$i]'] = cleaned;
  //   }

  //   try {
  //     final response = await request.send();
  //     final resBody = await response.stream.bytesToString();

  //     if (response.statusCode == 200) {
  //       ScaffoldMessenger.of(context)
  //           .showSnackBar(SnackBar(content: Text("Post updated successfully")));
  //       Navigator.pop(context, true);
  //     } else {
  //       final error = json.decode(resBody);
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text("Error: ${error['error']}")),
  //       );
  //     }
  //   } catch (e) {
  //     print("Error: $e");
  //     ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text("Update failed: ${e.toString()}")));
  //   } finally {
  //     if (mounted) {
  //       setState(() => _isUpdating = false);
  //     }
  //   }
  // }

  Future<void> _updatePost() async {
    if (_isUpdating) return;

    if (!_mainTextController.text.trim().isNotEmpty && !_newMedia.isNotEmpty) {
      showAppToast(context, "Post cannot be updated as empty",
          icon: Icons.error_outline_rounded);
      return;
    }

    setState(() => _isUpdating = true);

    final uri = Uri.parse('$host/edit_post');
    final request = http.MultipartRequest('POST', uri);
    final token = await Config.getAccessToken(); // implement this in Config
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['post_id'] = widget.postId;
    request.fields['main_description'] = _mainTextController.text.trim();

    try {
      // --- Convert XFile → File ---
      final originalFiles = _newMedia.map((x) => File(x.path)).toList();

      // --- Compress all in parallel ---
      final compressedFiles = await Config.compressAllImages(originalFiles);

      // --- Add compressed files to request ---
      for (int i = 0; i < compressedFiles.length; i++) {
        final processedFile = compressedFiles[i];

        if (!await processedFile.exists()) {
          print('❌ Skipping invalid file: ${processedFile.path}');
          continue;
        }

        print('✅ Adding media: ${processedFile.path}');

        final mimeType = lookupMimeType(processedFile.path) ?? 'image/jpeg';

        request.files.add(await http.MultipartFile.fromPath(
          'post_media[]', // ✅ backend expects this key
          processedFile.path,
          filename: processedFile.path.split('/').last,
          contentType: MediaType.parse(mimeType),
        ));
      }

      // --- Add captions ---
      for (int i = 0; i < _captionControllers.length; i++) {
        final original = _captionControllers[i].text.trim();
        final cleaned = original.replaceAll(',', '');
        request.fields['post_description[$i]'] = cleaned;
      }

      // --- Send request ---
      final response = await request.send();
      final resBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        showAppToast(context, "Post updated successfully",
            icon: Icons.check_circle_outline_rounded);
        Navigator.pop(context, true);
      } else {
        final error = json.decode(resBody);
        showAppToast(context, "Error: ${error['error']}",
            icon: Icons.error_outline_rounded);
      }
    } catch (e) {
      print("Error: $e");
      showAppToast(context, "Update failed: ${e.toString()}",
          icon: Icons.error_outline_rounded);
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _deleteSingleMediaFromServer(
      String postId, String mediaUrl) async {
    final uri = Uri.parse('$host/delete_post_media');
    final token = await Config.getAccessToken();

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        "post_id": postId,
        "media_url": mediaUrl,
      }),
    );

    if (response.statusCode == 200) {
      print("Media deleted from server");
    } else {
      print("Failed to delete media: ${response.body}");
    }
  }

  Future<void> _confirmAndDeleteExisting(int i) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const ConfirmDeleteDialog(
        title: 'Delete this image?',
        message: 'The image and its caption will be removed from this post.',
      ),
    );
    if (confirmed != true) return;

    final removedMedia = _existingMedia[i];
    await _deleteSingleMediaFromServer(widget.postId, removedMedia);
    if (!mounted) return;

    setState(() {
      _existingMedia.removeAt(i);
      _captionControllers.removeAt(i);
    });

    showAppToast(context, 'Media deleted successfully',
        icon: Icons.check_circle_outline_rounded);
  }

  void _removeNewMedia(int localIndex) {
    final captionIndex = _existingMedia.length + localIndex;
    setState(() {
      _newMedia.removeAt(localIndex);
      _captionControllers.removeAt(captionIndex);
    });
  }

  // ─── Gradient header: back button + page title ───────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 14, 16, 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_brandDark, _brand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
              color: Color(0x331A56DB), blurRadius: 18, offset: Offset(0, 8)),
        ],
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
            child: const Icon(Icons.edit_note_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit Post',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
                SizedBox(height: 2),
                Text('Update text, photos & captions',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
              color: _brand, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 15, color: _brand),
        const SizedBox(width: 6),
        Text(text,
            style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827))),
      ],
    );
  }

  // ─── Main post text, focus-animated border ────────────────────────────────
  Widget _buildMainTextCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _mainTextFocused ? _brand : const Color(0xFFE5E9F2),
          width: _mainTextFocused ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: _mainTextFocused
                ? _brand.withValues(alpha: 0.14)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: _mainTextFocused ? 16 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(4),
      child: TextField(
        controller: _mainTextController,
        focusNode: _mainTextFocus,
        maxLines: 5,
        minLines: 3,
        style: const TextStyle(
            fontSize: 15, color: Color(0xFF1A2340), height: 1.5),
        decoration: const InputDecoration(
          hintText: "What's on your mind?",
          hintStyle: TextStyle(color: Color(0xFF94A3B8), fontSize: 14.5),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }

  Widget _captionField(TextEditingController controller, String hint) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontSize: 13.5, color: Color(0xFF1A2340)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _deleteBadge(VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 17),
      ),
    );
  }

  Widget _existingMediaCard(int i) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    _existingMedia[i],
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _deleteBadge(_isUpdating
                      ? null
                      : () => _confirmAndDeleteExisting(i)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _captionField(_captionControllers[i], 'Caption for this image'),
          ],
        ),
      ),
    );
  }

  Widget _newMediaCard(int localIndex, XFile file) {
    final captionIndex = _existingMedia.length + localIndex;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _brand.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
              color: _brand.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.topRight,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.file(
                    File(file.path),
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: _deleteBadge(
                      _isUpdating ? null : () => _removeNewMedia(localIndex)),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: _brand, borderRadius: BorderRadius.circular(20)),
                    child: const Text('New',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _captionField(
                _captionControllers[captionIndex], 'Caption for new image'),
          ],
        ),
      ),
    );
  }

  Widget _addMoreButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isUpdating ? null : _pickNewMedia,
        icon: const Icon(Icons.add_photo_alternate_outlined, color: _brand),
        label: const Text('Add More Media',
            style: TextStyle(fontWeight: FontWeight.w700)),
        style: OutlinedButton.styleFrom(
          foregroundColor: _brand,
          backgroundColor: _brand.withValues(alpha: 0.06),
          side: BorderSide(color: _brand.withValues(alpha: 0.35)),
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _updateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isUpdating ? null : _updatePost,
        style: ElevatedButton.styleFrom(
          backgroundColor: _brand,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: _isUpdating
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.2, color: Colors.white),
                  ),
                  SizedBox(width: 10),
                  Text('Updating…',
                      style: TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w700)),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 20),
                  SizedBox(width: 8),
                  Text('Update Post',
                      style: TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _brand))
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMainTextCard(),
                        const SizedBox(height: 22),
                        if (_existingMedia.isNotEmpty) ...[
                          _sectionLabel(Icons.photo_library_outlined,
                              'Your Uploaded Images'),
                          const SizedBox(height: 10),
                          ...List.generate(_existingMedia.length,
                              (i) => _existingMediaCard(i)),
                        ],
                        if (_newMedia.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _sectionLabel(Icons.add_photo_alternate_outlined,
                              'Newly Added Images'),
                          const SizedBox(height: 10),
                          ..._newMedia.asMap().entries.map(
                              (e) => _newMediaCard(e.key, e.value)),
                        ],
                        const SizedBox(height: 22),
                        _addMoreButton(),
                        const SizedBox(height: 14),
                        _updateButton(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
