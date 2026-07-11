import 'package:aaram_bd/config.dart';
import 'package:aaram_bd/widgets/app_toast.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

final String host = Config.host;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Edit Post"),
        backgroundColor: const Color(0xFF1A56DB),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🟩 Main Post Description
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _mainTextController,
                        maxLines: 4,
                        style: TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: "What's on your mind?",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // 🟨 Existing Media List
                  Text(
                    "Your Uploaded Images",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 10),
                  ...List.generate(_existingMedia.length, (i) {
                    return Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Stack(
                              alignment: Alignment.topRight,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(
                                    _existingMedia[i],
                                    width: double.infinity,
                                    height: 180,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 10,
                                  right: 10,
                                  child: Material(
                                    elevation: 4,
                                    color: Colors.white,
                                    shape: CircleBorder(),
                                    child: IconButton(
                                      icon:
                                          Icon(Icons.close, color: Colors.red),
                                      splashRadius: 20,
                                      onPressed: _isUpdating
                                          ? null
                                          : () async {
                                              final confirmed =
                                                  await showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                  title: Text("Confirm Delete"),
                                                  content: Text(
                                                      "Do you want to delete this image and caption?"),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(false),
                                                      child: Text("Cancel"),
                                                    ),
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.of(context)
                                                              .pop(true),
                                                      child: Text("Delete",
                                                          style: TextStyle(
                                                              color:
                                                                  Colors.red)),
                                                    ),
                                                  ],
                                                ),
                                              );

                                              if (confirmed == true) {
                                                final removedMedia =
                                                    _existingMedia[i];

                                                await _deleteSingleMediaFromServer(
                                                    widget.postId,
                                                    removedMedia);

                                                setState(() {
                                                  _existingMedia.removeAt(i);
                                                  _captionControllers
                                                      .removeAt(i);
                                                });

                                                showAppToast(context,
                                                    'Media deleted successfully',
                                                    icon: Icons
                                                        .check_circle_outline_rounded);
                                              }
                                            },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 10),
                            TextField(
                              controller: _captionControllers[i],
                              decoration: InputDecoration(
                                hintText: "Caption for this image",
                                filled: true,
                                fillColor: Colors.grey[100],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  // 🟦 New Media Files
                  if (_newMedia.isNotEmpty) ...[
                    SizedBox(height: 20),
                    Text(
                      "Newly Added Images",
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 10),
                    ..._newMedia.map((file) {
                      final index =
                          _existingMedia.length + _newMedia.indexOf(file);
                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(file.path),
                                  width: double.infinity,
                                  height: 180,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              SizedBox(height: 10),
                              TextField(
                                controller: _captionControllers[index],
                                decoration: InputDecoration(
                                  hintText: 'Caption for new image',
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: BorderSide.none,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],

                  SizedBox(height: 20),

                  // 🟪 Add More Button
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _isUpdating ? null : _pickNewMedia,
                      icon: Icon(Icons.add_photo_alternate_outlined),
                      label: Text("Add More Media"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A56DB),
                        foregroundColor: Colors.white,
                        padding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  // 🟥 Submit Button with spinner
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isUpdating ? null : _updatePost,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A56DB),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.update, size: 24),
                          SizedBox(width: 8),
                          Text('Update Post', style: TextStyle(fontSize: 18)),
                          if (_isUpdating) ...[
                            SizedBox(width: 15),
                            SizedBox(
                              width: 20,
                              height: 20,
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
                  SizedBox(height: 30),
                ],
              ),
            ),
    );
  }
}
