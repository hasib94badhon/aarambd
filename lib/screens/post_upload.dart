import 'dart:convert';
import 'dart:io';
import 'package:aaram_bd/config.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

String host = Config.host;

class PostUpload extends StatefulWidget {
  final String postName;
  final String postPhone;
  final String postCategory;
  final String postDescription;

  PostUpload({
    required this.postName,
    required this.postPhone,
    required this.postCategory,
    required this.postDescription,
  });

  @override
  _PostUploadState createState() => _PostUploadState();
}

class _PostUploadState extends State<PostUpload> {
  final List<XFile> _selectedMediaList = [];
  final List<TextEditingController> _descriptionControllers = [];
  final ImagePicker _picker = ImagePicker();

  // Upload state tracking
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _descriptionControllers.add(TextEditingController());
  }

  Future<void> _pickMedia() async {
    if (_isUploading) return;

    final List<XFile>? mediaFiles = await _picker.pickMultiImage();
    if (mediaFiles != null && mediaFiles.isNotEmpty) {
      setState(() {
        for (var file in mediaFiles) {
          _selectedMediaList.add(file);
          _descriptionControllers.add(TextEditingController());
        }
      });
    }
  }

  Future<void> submitPost() async {
    if (_isUploading) return;

    setState(() => _isUploading = true);

    final hasTextOnlyPost = _descriptionControllers.isNotEmpty &&
        _descriptionControllers[0].text.trim().isNotEmpty;

    if (_selectedMediaList.isEmpty &&
        (!hasTextOnlyPost || _descriptionControllers[0].text.trim().isEmpty)) {
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write something or add media.')),
      );
      return;
    }

    try {
      // Prepare fields
      final fields = <String, String>{
        'phone': widget.postPhone,
      };

      if (hasTextOnlyPost) {
        fields['main_description'] = _descriptionControllers[0].text.trim();
      }

      // Convert XFile → File
      final originalFiles =
          _selectedMediaList.map((x) => File(x.path)).toList();

      // ✅ Compress all in parallel
      final compressedFiles = await Config.compressAllImages(originalFiles);

      // Prepare files map
      final files = <String, File>{};
      for (int i = 0; i < compressedFiles.length; i++) {
        final processedFile = compressedFiles[i];

        if (!await processedFile.exists()) {
          print('❌ Skipping invalid file: ${processedFile.path}');
          continue;
        }

        print('✅ Adding media: ${processedFile.path}');

        // ✅ Use the same key for all files (backend expects post_media[])
        files['post_media[]'] = processedFile;

        // Captions
        final description = _descriptionControllers.length > i + 1
            ? _descriptionControllers[i + 1].text.trim()
            : "";
        fields['post_description[$i]'] = description;
      }

      // Send request with token
      final resp = await Config.apiMultipartPost(
        "/submit_post",
        context,
        fields: fields,
        files: files,
      );

      if (resp != null) {
        final body = await resp.stream.bytesToString();
        if (resp.statusCode == 201) {
          print(
              '✅ Post submitted successfully with ${files.length} media files');
          Navigator.pop(context, true);
        } else {
          final errorData = json.decode(body);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${errorData['error']}')),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit post: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Neutrals & accents for a clean white theme
    final Color surface = Colors.white;
    final Color bg = const Color(0xFFF6F7F9);
    final Color border = const Color(0x14000000); // faint
    final Color shadow = const Color(0x12000000); // faint
    final Color title = const Color(0xFF111827);
    final Color text = const Color(0xFF1F2937);
    final Color hint = const Color(0xFF6B7280);
    const Color primary = Color(0xFF1A56DB);
    const Color secondary = Color(0xFF1A56DB);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: surface,
        foregroundColor: title,
        title: const Text(
          'Upload Post',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      /// 🔹 Post Description (white card + shadow)
                      Container(
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: border),
                          boxShadow: [
                            BoxShadow(
                              color: shadow,
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "What's on your mind?",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: title,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _descriptionControllers.isNotEmpty
                                  ? _descriptionControllers[0]
                                  : TextEditingController(),
                              maxLines: 4,
                              decoration: InputDecoration(
                                hintText: "Write your post here...",
                                hintStyle: TextStyle(color: hint),
                                filled: true,
                                fillColor: surface,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: border),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: border),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide:
                                      BorderSide(color: primary, width: 1.2),
                                ),
                              ),
                              style: TextStyle(color: text),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      /// 🔹 Picked Media (each as white card + shadow)
                      ..._selectedMediaList.asMap().entries.map((entry) {
                        final index = entry.key;
                        final media = entry.value;
                        return Container(
                          decoration: BoxDecoration(
                            color: surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: border),
                            boxShadow: [
                              BoxShadow(
                                color: shadow,
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(media.path),
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _descriptionControllers[index + 1],
                                maxLines: 2,
                                decoration: InputDecoration(
                                  hintText: 'Description for this photo',
                                  hintStyle: TextStyle(color: hint),
                                  prefixIcon: Icon(Icons.description_outlined,
                                      color: hint),
                                  filled: true,
                                  fillColor: surface,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: border),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: border),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: primary, width: 1.2),
                                  ),
                                ),
                                style: TextStyle(color: text),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),

              /// 🔹 Pick Media Button (solid, rounded)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: secondary,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.photo_library_outlined, size: 22),
                label: const Text("Add Photos",
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                onPressed: _isUploading ? null : _pickMedia,
              ),

              const SizedBox(height: 10),

              /// 🔹 Submit Button with spinner (primary)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: primary,
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
                      const Icon(Icons.send_outlined, size: 22),
                      const SizedBox(width: 8),
                      const Text('Post Now',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
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

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
