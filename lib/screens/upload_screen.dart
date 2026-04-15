import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models.dart';
import '../services/supabase_service.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  // ── Fix #8: up to 5 images ──────────────────────────────────────────────
  final List<File> _images = [];
  static const int _maxImages = 5;

  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _tagCtrl   = TextEditingController();
  List<String> _tags = [];
  int _visibility  = 0;
  String _category = '2D Illustration';
  bool _uploading  = false;

  final List<String> _categories = [
    '2D Illustration', '3D / CGI', 'Photography',
    'Traditional / Oil Paint', 'Sketch / Line Art', 'Animation / GIF',
  ];

  Future<void> _pickImages() async {
    if (_images.length >= _maxImages) {
      _snack('Maximum $_maxImages images allowed');
      return;
    }
    final picker = ImagePicker();
    final remaining = _maxImages - _images.length;
    final picked = await picker.pickMultiImage(imageQuality: 85, limit: remaining);
    if (picked.isNotEmpty) {
      setState(() {
        final toAdd = picked.take(remaining).map((x) => File(x.path));
        _images.addAll(toAdd);
      });
    }
  }

  void _removeImage(int index) => setState(() => _images.removeAt(index));

  void _addTag() {
    final tag = _tagCtrl.text.trim().replaceAll(' ', '');
    if (tag.isEmpty) return;
    final formatted = tag.startsWith('#') ? tag : '#$tag';
    if (!_tags.contains(formatted)) setState(() => _tags.add(formatted));
    _tagCtrl.clear();
  }

  Future<void> _post() async {
    if (_images.isEmpty) { _snack('Please select at least one image'); return; }
    if (_titleCtrl.text.trim().isEmpty) { _snack('Please add a title'); return; }

    setState(() => _uploading = true);
    try {
      final uid = authService.currentUserId!;

      // Upload all images in parallel
      final uploadFutures = _images.map((f) => storageService.uploadPostImage(f, uid));
      final imageUrls = await Future.wait(uploadFutures);

      await postService.createPost(PostModel(
        id:          '',
        authorId:    uid,
        title:       _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        imageUrl:    imageUrls.first,  // primary = first image
        imageUrls:   imageUrls,
        category:    _category,
        tags:        _tags,
        visibility:  ['public', 'followers', 'private'][_visibility],
        likesCount:  0,
        createdAt:   DateTime.now(),
      ));

      if (mounted) {
        _snack('Artwork posted! 🎉');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) _snack('Failed to post: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose(); _tagCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.warmWhite,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.dark),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('New Post',
            style: GoogleFonts.dmSans(
                fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.dark)),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.border)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Image picker area ──────────────────────────────────────────
          _buildImagePicker(),
          const SizedBox(height: 16),

          _label('Title'),
          const SizedBox(height: 5),
          TextField(
              controller: _titleCtrl,
              style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
              decoration: const InputDecoration(hintText: 'Name your work…')),
          const SizedBox(height: 14),

          _label('Description'),
          const SizedBox(height: 5),
          TextField(
              controller: _descCtrl,
              maxLines: 3,
              style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
              decoration: const InputDecoration(
                  hintText: 'Share your process, inspiration, tools…')),
          const SizedBox(height: 14),

          _label('Tags'),
          const SizedBox(height: 5),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _tagCtrl,
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
                onSubmitted: (_) => _addTag(),
                decoration: const InputDecoration(
                    hintText: 'Add a tag…', prefixText: '#'),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _addTag,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                    color: AppColors.peach, shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            ),
          ]),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: _tags
                  .map((t) => Chip(
                        label: Text(t,
                            style: GoogleFonts.dmSans(
                                fontSize: 11, color: AppColors.brown)),
                        backgroundColor: AppColors.peachPale,
                        side: const BorderSide(color: AppColors.peachLight),
                        deleteIcon:
                            const Icon(Icons.close, size: 14, color: AppColors.muted),
                        onDeleted: () => setState(() => _tags.remove(t)),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
          const SizedBox(height: 14),

          _label('Category'),
          const SizedBox(height: 5),
          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _category,
                isExpanded: true,
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
            ),
          ),
          const SizedBox(height: 14),

          _label('Visibility'),
          const SizedBox(height: 5),
          Row(children: [
            _visBtn('🌍 Public', 0),
            const SizedBox(width: 8),
            _visBtn('👥 Followers', 1),
            const SizedBox(width: 8),
            _visBtn('🔒 Private', 2),
          ]),
          const SizedBox(height: 24),

          GradientButton(
              label: _uploading ? 'Posting…' : 'Post Artwork',
              onPressed: _post,
              loading: _uploading),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  // ── Fix #8: multi-image grid picker ──────────────────────────────────────
  Widget _buildImagePicker() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _label('Images'),
        Text('${_images.length} / $_maxImages',
            style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
      ]),
      const SizedBox(height: 8),
      if (_images.isEmpty)
        // Empty state — tap to pick
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.peachPale,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: AppColors.peachLight, width: 2,
                  style: BorderStyle.solid),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.add_photo_alternate_outlined,
                  color: AppColors.peach, size: 40),
              const SizedBox(height: 8),
              Text('Tap to add images',
                  style: GoogleFonts.dmSans(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppColors.brown)),
              Text('Up to $_maxImages images · JPG, PNG',
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
            ]),
          ),
        )
      else
        // Grid of selected images + add button
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
          itemCount: _images.length < _maxImages
              ? _images.length + 1
              : _images.length,
          itemBuilder: (_, i) {
            // Last cell = add button (if under limit)
            if (i == _images.length) {
              return GestureDetector(
                onTap: _pickImages,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.peachPale,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.peachLight, width: 1.5,
                        style: BorderStyle.solid),
                  ),
                  child: const Icon(Icons.add_photo_alternate_outlined,
                      color: AppColors.peach, size: 28),
                ),
              );
            }
            // Image cell with remove button
            return Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.file(_images[i],
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity),
              ),
              // First image badge
              if (i == 0)
                Positioned(
                  top: 4, left: 4,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.peach,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('Cover',
                        style: GoogleFonts.dmSans(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ),
                ),
              // Remove button
              Positioned(
                top: 4, right: 4,
                child: GestureDetector(
                  onTap: () => _removeImage(i),
                  child: Container(
                    decoration: const BoxDecoration(
                        color: Colors.black54, shape: BoxShape.circle),
                    padding: const EdgeInsets.all(3),
                    child: const Icon(Icons.close, color: Colors.white, size: 13),
                  ),
                ),
              ),
            ]);
          },
        ),
    ]);
  }

  Widget _label(String t) => Text(
        t.toUpperCase(),
        style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: AppColors.muted,
            letterSpacing: 0.5),
      );

  Widget _visBtn(String label, int index) => Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _visibility = index),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: _visibility == index ? AppColors.peach : AppColors.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: _visibility == index ? AppColors.peach : AppColors.border,
                  width: 1.5),
            ),
            child: Text(label,
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _visibility == index ? Colors.white : AppColors.muted)),
          ),
        ),
      );
}
