import 'dart:convert';
import 'dart:io';
import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

String host = Config.host;

const int _maxPhotos = 10;

class PostUpload extends StatefulWidget {
  final String postName;
  final String postPhone;
  final String postCategory;
  final String postDescription;

  const PostUpload({
    super.key,
    required this.postName,
    required this.postPhone,
    required this.postCategory,
    required this.postDescription,
  });

  @override
  State<PostUpload> createState() => _PostUploadState();
}

enum _UploadStage { idle, compressing, uploading }

class _PostUploadState extends State<PostUpload> {
  final List<XFile> _selectedMediaList = [];
  final List<TextEditingController> _descriptionControllers = [];
  final ImagePicker _picker = ImagePicker();

  _UploadStage _stage = _UploadStage.idle;
  bool get _isUploading => _stage != _UploadStage.idle;

  static const Color _bg = Color(0xFFF6F7F9);
  static const Color _surface = Colors.white;
  static const Color _border = Color(0x14000000);
  static const Color _title = Color(0xFF111827);
  static const Color _text = Color(0xFF1F2937);
  static const Color _hint = Color(0xFF6B7280);
  static const Color _primary = Color(0xFF1A56DB);

  @override
  void initState() {
    super.initState();
    _descriptionControllers.add(TextEditingController());
  }

  @override
  void dispose() {
    for (final c in _descriptionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickMedia() async {
    if (_isUploading) return;

    final remaining = _maxPhotos - _selectedMediaList.length;
    if (remaining <= 0) {
      showAppToast(context, 'You can add up to $_maxPhotos photos.',
          icon: Icons.error_outline_rounded);
      return;
    }

    final List<XFile>? mediaFiles = await _picker.pickMultiImage();
    if (mediaFiles == null || mediaFiles.isEmpty) return;

    final toAdd = mediaFiles.take(remaining).toList();
    if (mediaFiles.length > remaining) {
      showAppToast(context, 'Only added $remaining more (limit $_maxPhotos).',
          icon: Icons.info_outline_rounded);
    }

    setState(() {
      for (var file in toAdd) {
        _selectedMediaList.add(file);
        _descriptionControllers.add(TextEditingController());
      }
    });
  }

  void _removeMediaAt(int index) {
    setState(() {
      _selectedMediaList.removeAt(index);
      _descriptionControllers.removeAt(index + 1).dispose();
    });
  }

  Future<void> submitPost() async {
    if (_isUploading) return;

    final hasTextOnlyPost = _descriptionControllers.isNotEmpty &&
        _descriptionControllers[0].text.trim().isNotEmpty;

    if (_selectedMediaList.isEmpty && !hasTextOnlyPost) {
      showAppToast(context, 'Please write something or add media.',
          icon: Icons.error_outline_rounded);
      return;
    }

    setState(() => _stage = _UploadStage.compressing);

    try {
      final fields = <String, String>{
        'phone': widget.postPhone,
      };
      if (hasTextOnlyPost) {
        fields['main_description'] = _descriptionControllers[0].text.trim();
      }

      final originalFiles =
          _selectedMediaList.map((x) => File(x.path)).toList();
      final compressedFiles = await Config.compressAllImages(originalFiles);

      final mediaFiles = <File>[];
      for (int i = 0; i < compressedFiles.length; i++) {
        final processedFile = compressedFiles[i];
        if (!await processedFile.exists()) continue;

        mediaFiles.add(processedFile);
        final description = _descriptionControllers.length > i + 1
            ? _descriptionControllers[i + 1].text.trim()
            : "";
        fields['post_description[$i]'] = description;
      }
      final files = <String, List<File>>{
        if (mediaFiles.isNotEmpty) 'post_media[]': mediaFiles,
      };

      if (!mounted) return;
      setState(() => _stage = _UploadStage.uploading);

      final resp = await Config.apiMultipartPost(
        "/submit_post",
        context,
        fields: fields,
        files: files,
      );

      if (resp != null) {
        final body = await resp.stream.bytesToString();
        if (resp.statusCode == 201) {
          if (mounted) Navigator.pop(context, true);
        } else {
          final errorData = json.decode(body);
          if (mounted) {
            showAppToast(context, 'Error: ${errorData['error']}',
                icon: Icons.error_outline_rounded);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        showAppToast(context, 'Failed to submit post: ${e.toString()}',
            icon: Icons.error_outline_rounded);
      }
    } finally {
      if (mounted) setState(() => _stage = _UploadStage.idle);
    }
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: padding ?? const EdgeInsets.all(14),
      child: child,
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1040B0), Color(0xFF1A56DB), Color(0xFF3B7CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.campaign_rounded,
                color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Share Your Ad',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Add photos and details to reach buyers in your category.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hintText, {Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: _hint),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primary, width: 1.2),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    final canAddMore = _selectedMediaList.length < _maxPhotos;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Photos',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: _title),
              ),
              const Spacer(),
              Text(
                '${_selectedMediaList.length}/$_maxPhotos',
                style: const TextStyle(fontSize: 12.5, color: _hint),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _selectedMediaList.length + (canAddMore ? 1 : 0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemBuilder: (context, index) {
              if (index == _selectedMediaList.length) {
                return _addPhotoTile();
              }
              return _photoTile(index);
            },
          ),
        ],
      ),
    );
  }

  Widget _addPhotoTile() {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: _isUploading ? null : _pickMedia,
      child: DottedBorderBox(
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_photo_alternate_outlined,
                  color: _primary, size: 26),
              SizedBox(height: 4),
              Text('Add',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: _primary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _photoTile(int index) {
    final media = _selectedMediaList[index];
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(media.path),
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: GestureDetector(
            onTap: _isUploading ? null : () => _removeMediaAt(index),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  size: 14, color: Colors.white),
            ),
          ),
        ),
        Positioned(
          bottom: 4,
          left: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCaptionsCard() {
    if (_selectedMediaList.isEmpty) return const SizedBox.shrink();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Photo captions (optional)',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: _title),
          ),
          const SizedBox(height: 10),
          ..._selectedMediaList.asMap().entries.map((entry) {
            final index = entry.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _descriptionControllers[index + 1],
                maxLines: 1,
                style: const TextStyle(color: _text, fontSize: 13.5),
                decoration: _fieldDecoration(
                  'Caption for photo ${index + 1}',
                  prefixIcon: const Icon(Icons.description_outlined,
                      color: _hint, size: 18),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildProgressBanner() {
    if (_stage == _UploadStage.idle) return const SizedBox.shrink();
    final label = _stage == _UploadStage.compressing
        ? 'Compressing photos...'
        : 'Uploading post...';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w700, color: _primary),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              minHeight: 5,
              backgroundColor: Color(0x1A1A56DB),
              valueColor: AlwaysStoppedAnimation<Color>(_primary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Gradient hero header — matches the rest of the app (AccountSettingsPage,
  // FavoriteProfilesPage, notification_show.dart): back button + icon bubble +
  // title/subtitle on a rounded-bottom blue gradient.
  Widget _buildAppBarHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, MediaQuery.of(context).padding.top + 14, 16, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1040B0), _primary],
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
            child: const Icon(Icons.add_photo_alternate_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create Post',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
                SizedBox(height: 2),
                Text(
                  'Share an ad with buyers in your category',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          _buildAppBarHeader(context),
          Expanded(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            
                            _card(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "What's on your mind?",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: _title,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller:
                                        _descriptionControllers.isNotEmpty
                                            ? _descriptionControllers[0]
                                            : TextEditingController(),
                                    maxLines: 4,
                                    style: const TextStyle(color: _text),
                                    decoration: _fieldDecoration(
                                        'Write your post here...'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildPhotoGrid(),
                            if (_selectedMediaList.isNotEmpty) ...[
                              const SizedBox(height: 14),
                              _buildCaptionsCard(),
                            ],
                            const SizedBox(height: 14),
                          ],
                        ),
                      ),
                    ),

                    _buildProgressBanner(),

                    /// Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: _primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: _isUploading ? null : submitPost,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!_isUploading) ...[
                              const Icon(Icons.send_outlined, size: 22),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _isUploading ? 'Posting...' : 'Post Now',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            if (_isUploading) ...[
                              const SizedBox(width: 14),
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Simple dashed-border container for the "add photo" grid tile.
class DottedBorderBox extends StatelessWidget {
  final Widget child;
  const DottedBorderBox({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A56DB).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF1A56DB).withValues(alpha: 0.35),
          width: 1.4,
        ),
      ),
      child: child,
    );
  }
}
