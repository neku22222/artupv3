import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models.dart';
import '../services/supabase_service.dart';
import '../widgets/common_widgets.dart';
import '../theme/app_theme.dart';
import 'post_detail_screen.dart';
import 'dm_screen.dart';
import 'followers_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// UploadScreen — create NEW post  (pass no arguments)
//              — edit EXISTING   (pass post:)
// ─────────────────────────────────────────────────────────────────────────────

class UploadScreen extends StatefulWidget {
  final PostModel? post;
  const UploadScreen({super.key, this.post});

  bool get isEdit => post != null;

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  // ── Images ──────────────────────────────────────────────────────────────
  final List<File> _newImages = [];
  List<String> _existingUrls  = [];
  static const int _maxImages = 5;

  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _tagCtrl   = TextEditingController();
  List<String> _tags = [];
  int _visibility  = 0;
  String _category = '2D Illustration';
  String _ageRating = 'SFW';
  bool _uploading  = false;

  static const int _maxTags = 15;

  final List<String> _categories = [
    '2D Illustration', '3D / CGI', 'Photography',
    'Traditional / Oil Paint', 'Sketch / Line Art', 'Animation / GIF',
  ];

  /// Two rating options only: SFW and 18+
  final List<(String, String, Color)> _ageRatings = [
    ('SFW', '🌸 Safe for Work',  const Color(0xFF4CAF50)),
    ('18+', '🔒 18+ / Explicit', const Color(0xFFF44336)),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEdit) {
      final p = widget.post!;
      _titleCtrl.text  = p.title;
      _descCtrl.text   = p.description;
      _tags            = List<String>.from(p.tags);
      _category        = p.category;
      // Normalise legacy NSFW → 18+
      _ageRating       = p.ageRating == 'NSFW' ? '18+' : p.ageRating;
      _existingUrls    = List<String>.from(p.imageUrls);
      _visibility      = ['public', 'followers', 'private'].indexOf(p.visibility);
      if (_visibility < 0) _visibility = 0;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose(); _tagCtrl.dispose();
    super.dispose();
  }

  int get _totalImages => _existingUrls.length + _newImages.length;

  Future<void> _pickImages() async {
    if (_totalImages >= _maxImages) {
      _snack('Maximum $_maxImages images allowed');
      return;
    }
    final picker    = ImagePicker();
    final remaining = _maxImages - _totalImages;
    final picked    = await picker.pickMultiImage(imageQuality: 85, limit: remaining);
    if (picked.isNotEmpty) {
      setState(() {
        final toAdd = picked.take(remaining).map((x) => File(x.path));
        _newImages.addAll(toAdd);
      });
    }
  }

  void _removeExistingImage(int index) => setState(() => _existingUrls.removeAt(index));
  void _removeNewImage(int index)      => setState(() => _newImages.removeAt(index));

  void _addTag() {
    if (_tags.length >= _maxTags) {
      _snack('Maximum $_maxTags tags allowed');
      return;
    }
    final tag = _tagCtrl.text.trim().replaceAll(' ', '');
    if (tag.isEmpty) return;
    final formatted = tag.startsWith('#') ? tag : '#$tag';
    if (!_tags.contains(formatted)) setState(() => _tags.add(formatted));
    _tagCtrl.clear();
  }

  Future<void> _post() async {
    if (_totalImages == 0 && !widget.isEdit) {
      _snack('Please select at least one image');
      return;
    }
    if (_titleCtrl.text.trim().isEmpty) {
      _snack('Please add a title');
      return;
    }

    setState(() => _uploading = true);
    try {
      final uid = authService.currentUserId!;

      List<String> newUrls = [];
      if (_newImages.isNotEmpty) {
        final uploadFutures = _newImages.map((f) => storageService.uploadPostImage(f, uid));
        newUrls = List<String>.from(await Future.wait(uploadFutures));
      }

      final allUrls = [..._existingUrls, ...newUrls];

      if (widget.isEdit) {
        final p = widget.post!;
        p.title       = _titleCtrl.text.trim();
        p.description = _descCtrl.text.trim();
        p.category    = _category;
        p.tags        = _tags;
        p.visibility  = ['public', 'followers', 'private'][_visibility];
        p.ageRating   = _ageRating;
        await postService.editPost(p);
        if (mounted) {
          _snack('Post updated! ✅');
          Navigator.of(context).pop(p);
        }
      } else {
        print('DEBUG ageRating: "$_ageRating"');
        print('DEBUG visibility: "${['public', 'followers', 'private'][_visibility]}"');
        print('DEBUG category: "$_category"');
        await postService.createPost(PostModel(
          id:          '',
          authorId:    uid,
          title:       _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          imageUrl:    allUrls.isNotEmpty ? allUrls.first : '',
          imageUrls:   allUrls,
          category:    _category,
          tags:        _tags,
          visibility:  ['public', 'followers', 'private'][_visibility],
          likesCount:  0,
          createdAt:   DateTime.now(),
          ageRating:   _ageRating,
        ));
        if (mounted) {
          _snack('Artwork posted! 🎉');
          Navigator.of(context).pop(true);
        }
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
        title: Text(widget.isEdit ? 'Edit Post' : 'New Post',
            style: GoogleFonts.dmSans(
                fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.dark)),
        bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.border)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!widget.isEdit) ...[
            _buildImagePicker(),
            const SizedBox(height: 16),
          ] else ...[
            _buildExistingImagesPreview(),
            const SizedBox(height: 16),
          ],

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

          // ── Tags ────────────────────────────────────────────────────────
          Row(children: [
            _label('Tags'),
            const SizedBox(width: 6),
            Text('${_tags.length} / $_maxTags',
                style: GoogleFonts.dmSans(
                    fontSize: 10,
                    color: _tags.length >= _maxTags ? AppColors.errorRed : AppColors.muted)),
          ]),
          const SizedBox(height: 5),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _tagCtrl,
                style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.dark),
                onSubmitted: (_) => _addTag(),
                enabled: _tags.length < _maxTags,
                decoration: InputDecoration(
                    hintText: _tags.length >= _maxTags ? 'Limit reached' : 'Add a tag…',
                    prefixText: '#'),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _tags.length < _maxTags ? _addTag : null,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: _tags.length < _maxTags ? AppColors.peach : AppColors.muted,
                    shape: BoxShape.circle),
                child: const Icon(Icons.add, color: Colors.white, size: 18),
              ),
            ),
          ]),
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6, runSpacing: 6,
              children: _tags.map((t) => Chip(
                label: Text(t, style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.brown)),
                backgroundColor: AppColors.peachPale,
                side: const BorderSide(color: AppColors.peachLight),
                deleteIcon: const Icon(Icons.close, size: 14, color: AppColors.muted),
                onDeleted: () => setState(() => _tags.remove(t)),
                visualDensity: VisualDensity.compact,
              )).toList(),
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

          // ── Age Rating (2 options) ────────────────────────────────────
          _label('Age Rating'),
          const SizedBox(height: 8),
          Row(children: _ageRatings.map(((String key, String label, Color col) r) {
            final selected = _ageRating == r.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _ageRating = r.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.only(right: 6),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? r.$3.withOpacity(0.12) : AppColors.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: selected ? r.$3 : AppColors.border, width: 1.5),
                  ),
                  child: Text(r.$2,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: selected ? r.$3 : AppColors.muted)),
                ),
              ),
            );
          }).toList()),
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
              label: _uploading
                  ? (widget.isEdit ? 'Saving…' : 'Posting…')
                  : (widget.isEdit ? 'Save Changes' : 'Post Artwork'),
              onPressed: _post,
              loading: _uploading),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  // ── Existing images preview (edit mode) ──────────────────────────────────
  Widget _buildExistingImagesPreview() {
    if (_existingUrls.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Images (cannot be changed after posting)'),
      const SizedBox(height: 8),
      SizedBox(
        height: 80,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _existingUrls.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) => ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(_existingUrls[i],
                width: 80, height: 80, fit: BoxFit.cover),
          ),
        ),
      ),
    ]);
  }

  // ── Multi-image grid picker ───────────────────────────────────────────────
  Widget _buildImagePicker() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _label('Images'),
        Text('$_totalImages / $_maxImages',
            style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
      ]),
      const SizedBox(height: 8),
      if (_totalImages == 0)
        GestureDetector(
          onTap: _pickImages,
          child: Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.peachPale,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.peachLight, width: 2),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.add_photo_alternate_outlined,
                  color: AppColors.peach, size: 40),
              const SizedBox(height: 8),
              Text('Tap to add images',
                  style: GoogleFonts.dmSans(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.brown)),
              Text('Up to $_maxImages images · JPG, PNG',
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.muted)),
            ]),
          ),
        )
      else
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
          itemCount: _totalImages < _maxImages ? _totalImages + 1 : _totalImages,
          itemBuilder: (_, i) {
            if (i == _totalImages && _totalImages < _maxImages) {
              return GestureDetector(
                onTap: _pickImages,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.peachPale,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.peachLight, width: 1.5),
                  ),
                  child: const Icon(Icons.add_photo_alternate_outlined,
                      color: AppColors.peach, size: 28),
                ),
              );
            }
            final isExisting = i < _existingUrls.length;
            final label = i == 0 ? 'Cover' : null;
            return Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: isExisting
                    ? Image.network(_existingUrls[i],
                    fit: BoxFit.cover,
                    width: double.infinity, height: double.infinity)
                    : Image.file(_newImages[i - _existingUrls.length],
                    fit: BoxFit.cover,
                    width: double.infinity, height: double.infinity),
              ),
              if (label != null)
                Positioned(
                  top: 4, left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                        color: AppColors.peach, borderRadius: BorderRadius.circular(6)),
                    child: Text(label,
                        style: GoogleFonts.dmSans(
                            fontSize: 8, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              Positioned(
                top: 4, right: 4,
                child: GestureDetector(
                  onTap: () => isExisting
                      ? _removeExistingImage(i)
                      : _removeNewImage(i - _existingUrls.length),
                  child: Container(
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
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
        fontSize: 10, fontWeight: FontWeight.w700,
        color: AppColors.muted, letterSpacing: 0.5),
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
              color: _visibility == index ? AppColors.peach : AppColors.border, width: 1.5),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
                fontSize: 11, fontWeight: FontWeight.w500,
                color: _visibility == index ? Colors.white : AppColors.muted)),
      ),
    ),
  );
}