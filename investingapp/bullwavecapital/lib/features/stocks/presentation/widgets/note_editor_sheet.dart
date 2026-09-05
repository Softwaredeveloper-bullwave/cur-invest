import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/storage/note_image_store.dart';
import '../../../../core/theme/colors.dart';
import '../../../../core/theme/theme_a.dart';
import '../../../../core/utils/image_pick_helper.dart';
import '../../../../models/trader_note_model.dart';
import '../../../education/data/education_ui.dart';
import '../provider/notes_provider.dart';
import 'note_attached_image.dart';

class NoteEditorSheet extends StatefulWidget {
  final TraderNoteModel? note;
  final String defaultCategory;

  const NoteEditorSheet({
    super.key,
    this.note,
    this.defaultCategory = 'general',
  });

  static Future<bool?> show(
    BuildContext context, {
    TraderNoteModel? note,
    String defaultCategory = 'general',
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          NoteEditorSheet(note: note, defaultCategory: defaultCategory),
    );
  }

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late final TextEditingController _symbolController;
  late String _category;
  late bool _isPinned;
  late List<String> _imagePaths;
  bool _isSaving = false;
  bool _isPickingPhoto = false;

  bool get _isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _titleController = TextEditingController(text: note?.title ?? '');
    _bodyController = TextEditingController(text: note?.body ?? '');
    _symbolController = TextEditingController(text: note?.symbol ?? '');
    _category = note?.category ?? widget.defaultCategory;
    _isPinned = note?.isPinned ?? false;
    _imagePaths = [...(note?.imagePaths ?? const <String>[])];
    _symbolController.addListener(_fillSymbolPlaceholder);
  }

  @override
  void dispose() {
    _symbolController.removeListener(_fillSymbolPlaceholder);
    _titleController.dispose();
    _bodyController.dispose();
    _symbolController.dispose();
    super.dispose();
  }

  void _fillSymbolPlaceholder() {
    final symbol = _symbolController.text.trim().toUpperCase();
    if (symbol.isEmpty) return;
    final title = _titleController.text;
    final body = _bodyController.text;
    var nextTitle = title;
    var nextBody = body;
    if (title.contains('SYMBOL')) {
      nextTitle = title.replaceAll('SYMBOL', symbol);
    } else if (RegExp(r'^Stock research — .+$').hasMatch(title)) {
      nextTitle = 'Stock research — $symbol';
    }
    if (body.contains('SYMBOL')) {
      nextBody = body.replaceAll('SYMBOL', symbol);
    }
    if (nextTitle == title && nextBody == body) return;
    _titleController.value = _titleController.value.copyWith(
      text: nextTitle,
      selection: TextSelection.collapsed(offset: nextTitle.length),
    );
    if (nextBody != body) {
      _bodyController.value = _bodyController.value.copyWith(
        text: nextBody,
        selection: TextSelection.collapsed(offset: nextBody.length),
      );
    }
  }

  void _applyTemplate(({String title, String body}) template) {
    final symbol = _symbolController.text.trim().toUpperCase();
    var title = template.title;
    var body = template.body;
    if (symbol.isNotEmpty) {
      title = title.replaceAll('SYMBOL', symbol);
      body = body.replaceAll('SYMBOL', symbol);
    }
    _titleController.text = title;
    _bodyController.text = body;
    setState(() {
      if (template.title.contains('Stock research')) {
        _category = 'stock';
      } else if (template.title.contains('journal')) {
        _category = 'journal';
      } else {
        _category = 'general';
      }
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty && body.isEmpty && _imagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title, note, or photo')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final saved = await context.read<NotesProvider>().saveNote(
      id: widget.note?.id,
      title: title.isEmpty ? 'Untitled note' : title,
      body: body,
      symbol: _symbolController.text.trim().toUpperCase(),
      category: _category,
      isPinned: _isPinned,
      imagePaths: _imagePaths,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (saved != null) {
      final offline = context.read<NotesProvider>().isOffline;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            offline
                ? 'Note saved on this device'
                : (_isEditing ? 'Note updated' : 'Note saved'),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      final err = context.read<NotesProvider>().error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? 'Could not save note'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showPhotoOptions() async {
    if (_imagePaths.length >= NoteImageStore.maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You can attach up to ${NoteImageStore.maxImages} photos'),
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _addPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _addPhoto(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addPhoto(ImageSource source) async {
    if (_isPickingPhoto) return;
    setState(() => _isPickingPhoto = true);
    try {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      final picked = await ImagePickHelper.pickProfileAvatar(
        context: context,
        source: source,
      );
      if (picked == null) {
        if (!mounted) return;
        if (source == ImageSource.camera) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ImagePickHelper.permissionDeniedMessage(source)),
            ),
          );
        }
        return;
      }
      final stored = await NoteImageStore.persist(picked.bytes);
      if (!mounted) return;
      setState(() => _imagePaths = [..._imagePaths, stored]);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ImagePickHelper.pickFailedMessage(source))),
      );
    } finally {
      if (mounted) setState(() => _isPickingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.55,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(color: p.borderLight),
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.textMuted.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit note' : 'New note',
                        style: ThemeAType.sectionTitle(color: p.textDark),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => _isPinned = !_isPinned),
                      icon: Icon(
                        _isPinned
                            ? Icons.push_pin_rounded
                            : Icons.push_pin_outlined,
                        color: _isPinned ? ThemeA.primary : p.textGrey,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 4),
                    FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(_isEditing ? 'Update' : 'Save'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (!_isEditing) ...[
                  Text(
                    'Beginner templates',
                    style: ThemeAType.label(size: 12, color: p.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: BeginnerNoteTemplates.templates.map((template) {
                      return ActionChip(
                        label: Text(
                          template.title,
                          style: ThemeAType.label(size: 12),
                        ),
                        onPressed: () => _applyTemplate(template),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: _titleController,
                  style: ThemeAType.cardTitle(color: p.textDark),
                  decoration: InputDecoration(
                    hintText: 'Title — e.g. RELIANCE breakout plan',
                    hintStyle: ThemeAType.body(color: p.textMuted),
                    filled: true,
                    fillColor: p.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _symbolController,
                        style: ThemeAType.body(color: p.textDark),
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'Symbol (optional)',
                          hintStyle: ThemeAType.body(color: p.textMuted),
                          prefixIcon: Icon(
                            Icons.tag_rounded,
                            color: p.textGrey,
                            size: 20,
                          ),
                          filled: true,
                          fillColor: p.card,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey(_category),
                        initialValue: _category,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: p.card,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'general',
                            child: Text('General'),
                          ),
                          DropdownMenuItem(
                            value: 'stock',
                            child: Text('Stock'),
                          ),
                          DropdownMenuItem(
                            value: 'trade_idea',
                            child: Text('Trade Idea'),
                          ),
                          DropdownMenuItem(
                            value: 'journal',
                            child: Text('Journal'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _category = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyController,
                  minLines: 10,
                  maxLines: 18,
                  style: ThemeAType.body(color: p.textDark, size: 15),
                  decoration: InputDecoration(
                    hintText:
                        'Write your research, entry/exit plan, risk notes, or daily market reflections…',
                    hintStyle: ThemeAType.body(color: p.textMuted),
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: p.card,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      'Photos',
                      style: ThemeAType.label(size: 12, color: p.textMuted),
                    ),
                    const Spacer(),
                    Text(
                      '${_imagePaths.length}/${NoteImageStore.maxImages}',
                      style: ThemeAType.label(size: 12, color: p.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 92,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ..._imagePaths.asMap().entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: SizedBox(
                                  width: 92,
                                  height: 92,
                                  child: NoteAttachedImage(source: entry.value),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Material(
                                  color: Colors.black54,
                                  shape: const CircleBorder(),
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: () {
                                      setState(() {
                                        _imagePaths = [
                                          for (var i = 0;
                                              i < _imagePaths.length;
                                              i++)
                                            if (i != entry.key) _imagePaths[i],
                                        ];
                                      });
                                    },
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (_imagePaths.length < NoteImageStore.maxImages)
                        InkWell(
                          onTap: _isPickingPhoto ? null : _showPhotoOptions,
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              color: p.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: p.borderLight),
                            ),
                            child: _isPickingPhoto
                                ? const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        color: ThemeA.primary,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Add photo',
                                        style: ThemeAType.label(
                                          size: 11,
                                          color: ThemeA.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Photos stay on this device and are not uploaded with the note.',
                  style: ThemeAType.label(size: 11, color: p.textMuted),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
