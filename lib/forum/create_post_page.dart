import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import 'forum_models.dart';
import 'forum_service.dart';
import 'chord_sheet_renderer.dart';

class CreatePostPage extends StatefulWidget {
  final ForumPost? existingPost;
  const CreatePostPage({super.key, this.existingPost});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage>
    with SingleTickerProviderStateMixin {
  final ForumService _service = ForumService();
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  final _titleCtrl   = TextEditingController();
  final _artistCtrl  = TextEditingController();
  final _contentCtrl = TextEditingController();

  String _key        = 'C';
  int    _capo       = 0;
  String _difficulty = 'Beginner';
  String _genre      = 'Pop';

  bool _isSubmitting  = false;
  bool _showPreview   = false;
  bool _formatExpanded = false;

  // Track which fields have been touched for progress indicator
  bool get _hasTitle   => _titleCtrl.text.trim().isNotEmpty;
  bool get _hasArtist  => _artistCtrl.text.trim().isNotEmpty;
  bool get _hasContent => _contentCtrl.text.trim().isNotEmpty;
  int  get _stepsComplete => [_hasTitle, _hasArtist, _hasContent].where((b) => b).length;

  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) {
        setState(() => _showPreview = _tabCtrl.index == 1);
      }
    });

     if (widget.existingPost != null) {
        final p = widget.existingPost!;
        _titleCtrl.text   = p.title;
        _artistCtrl.text  = p.artist;
        _contentCtrl.text = p.content;
        _key        = p.key;
        _capo       = p.capo;
        _difficulty = p.difficulty;
        _genre      = p.genre;
      }

    // Rebuild for progress bar whenever text changes
    _titleCtrl.addListener(() => setState(() {}));
    _artistCtrl.addListener(() => setState(() {}));
    _contentCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _contentCtrl.dispose();
    _tabCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_hasContent) {
      ScaffoldMessenger.of(context).showSnackBar(
        _snackBar('Add a chord sheet before posting', isError: true),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final auth = context.read<AuthProvider>();
      final post = ForumPost(
        id:          '',
        authorUid:   auth.appUser!.uid,
        authorName:  auth.appUser!.displayName,
        title:       _titleCtrl.text.trim(),
        artist:      _artistCtrl.text.trim(),
        key:         _key,
        capo:        _capo,
        difficulty:  _difficulty,
        genre:       _genre,
        content:     _contentCtrl.text,
        ratingSum:   0,
        ratingCount: 0,
        reportCount: 0,
        createdAt:   DateTime.now(),
        updatedAt:   DateTime.now(),
      );
      await _service.createPost(post);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _snackBar('Failed to post: $e', isError: true),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  SnackBar _snackBar(String msg, {bool isError = false}) => SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.redAccent.withOpacity(0.9) : Colors.greenAccent.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Container(
              color: const Color(0xFF0A0A0F),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _progressLabel(),
                    style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4)),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _stepsComplete / 3,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _stepsComplete == 3
                            ? Colors.greenAccent
                            : Colors.greenAccent.withOpacity(0.6),
                      ),
                      minHeight: 3,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildEditor(),
                  _buildPreview(),
                ],
              ),
            ),
          ],
        ),
      ),
      // Sticky post button at the bottom
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0A0A0F),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.white54),
        tooltip: 'Discard and go back',
        onPressed: () => _confirmDiscard(),
      ),
      title: const Text(
        'New Chord Sheet',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      bottom: TabBar(
        controller: _tabCtrl,
        indicatorColor: Colors.greenAccent,
        labelColor: Colors.greenAccent,
        unselectedLabelColor: Colors.white38,
        tabs: const [
          Tab(icon: Icon(Icons.edit_outlined, size: 16), text: 'Edit'),
          Tab(icon: Icon(Icons.visibility_outlined, size: 16), text: 'Preview'),
        ],
      ),
    );
  }

  String _progressLabel() {
    if (_stepsComplete == 0) return 'Fill in the details below to get started';
    if (_stepsComplete == 1) return '1 of 3 required fields done';
    if (_stepsComplete == 2) return '2 of 3 — almost there!';
    return 'Ready to post ✓';
  }

  Widget _buildBottomBar() {
    final bool canPost = _hasTitle && _hasArtist && _hasContent;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: AnimatedOpacity(
          opacity: canPost ? 1.0 : 0.45,
          duration: const Duration(milliseconds: 300),
          child: ElevatedButton(
            onPressed: (_isSubmitting || !canPost) ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              disabledBackgroundColor: Colors.greenAccent.withOpacity(0.5),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.send_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        canPost ? 'Post Chord Sheet' : 'Complete all fields to post',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EDITOR TAB
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildEditor() {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Step 1: Song Info ──────────────────────────────────────
          _stepHeader(
            step: 1,
            title: 'Song Info',
            subtitle: 'What song is this chord sheet for?',
            isDone: _hasTitle && _hasArtist,
          ),
          const SizedBox(height: 12),
          _field(_titleCtrl, 'Song title *', Icons.music_note_outlined,
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a song title' : null),
          const SizedBox(height: 10),
          _field(_artistCtrl, 'Artist name *', Icons.person_outline,
              validator: (v) => v == null || v.trim().isEmpty ? 'Please enter an artist name' : null),

          const SizedBox(height: 28),

          // ── Step 2: Tags ───────────────────────────────────────────
          _stepHeader(
            step: 2,
            title: 'Tags',
            subtitle: 'Help others find and filter your sheet',
            isDone: true, // tags always have defaults
            isOptionallyDone: true,
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _dropdown(label: 'Key', value: _key, items: kKeys, onChanged: (v) => setState(() => _key = v!))),
            const SizedBox(width: 12),
            Expanded(child: _dropdown(label: 'Capo fret', value: _capo.toString(), items: List.generate(12, (i) => i.toString()), onChanged: (v) => setState(() => _capo = int.parse(v!)))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _dropdown(label: 'Difficulty', value: _difficulty, items: kDifficulties, onChanged: (v) => setState(() => _difficulty = v!))),
            const SizedBox(width: 12),
            Expanded(child: _dropdown(label: 'Genre', value: _genre, items: kGenres, onChanged: (v) => setState(() => _genre = v!))),
          ]),

          const SizedBox(height: 28),

          // ── Step 3: Chord Sheet ────────────────────────────────────
          _stepHeader(
            step: 3,
            title: 'Chord Sheet',
            subtitle: 'Paste or type your chord sheet below',
            isDone: _hasContent,
          ),
          const SizedBox(height: 12),

          // Collapsible format guide — much more prominent
          _buildFormatGuide(),
          const SizedBox(height: 10),

          // The text area itself, with a labeled border
          _buildChordSheetField(),

          const SizedBox(height: 8),
          // Character count
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${_contentCtrl.text.length} characters',
              style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.25)),
            ),
          ),
          const SizedBox(height: 80), // breathing room above bottom bar
        ],
      ),
    );
  }

  Widget _stepHeader({
    required int step,
    required String title,
    required String subtitle,
    required bool isDone,
    bool isOptionallyDone = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step circle
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? (isOptionallyDone ? Colors.white.withOpacity(0.15) : Colors.greenAccent)
                : Colors.white.withOpacity(0.08),
            border: Border.all(
              color: isDone && !isOptionallyDone
                  ? Colors.greenAccent
                  : Colors.white.withOpacity(0.15),
              width: 1.5,
            ),
          ),
          child: Center(
            child: isDone && !isOptionallyDone
                ? const Icon(Icons.check, size: 14, color: Colors.black)
                : Text(
                    '$step',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.4)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Prominent, collapsible format guide with real examples
  Widget _buildFormatGuide() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: Colors.greenAccent.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.greenAccent.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          // Header row — always visible
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _formatExpanded = !_formatExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.help_outline_rounded,
                      size: 16, color: Colors.greenAccent.withOpacity(0.8)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'How to format a chord sheet',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.greenAccent,
                      ),
                    ),
                  ),
                  Icon(
                    _formatExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.greenAccent.withOpacity(0.7),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
          // Expandable body
          if (_formatExpanded) ...[
            Divider(color: Colors.greenAccent.withOpacity(0.15), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ruleRow(
                    icon: Icons.tag,
                    label: 'Section headers',
                    example: '[Verse 1]',
                    desc: 'Wrap section names in square brackets on their own line.',
                  ),
                  const SizedBox(height: 10),
                  _ruleRow(
                    icon: Icons.music_note_outlined,
                    label: 'Chord lines',
                    example: '    Am        F',
                    desc: 'Put chord names on a line by themselves, spaced above the lyrics they land on.',
                  ),
                  const SizedBox(height: 10),
                  _ruleRow(
                    icon: Icons.format_align_left_outlined,
                    label: 'Lyric lines',
                    example: 'I walked a lonely road',
                    desc: 'Lyrics go directly below the chord line.',
                  ),
                  const SizedBox(height: 14),
                  // Full example block
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '[Verse 1]\n    Am        F\nI walked a lonely road\n    C         G\nThe only one that I have known\n\n[Chorus]\n    F     C      G\nDon\'t look back — keep moving on',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.75),
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline, size: 13, color: Colors.amber.withOpacity(0.7)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Tip: Use the Preview tab above to see how your sheet will look to other players.',
                          style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.35)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _ruleRow({
    required IconData icon,
    required String label,
    required String example,
    required String desc,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.white.withOpacity(0.35)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.45),
                      letterSpacing: 0.4)),
              const SizedBox(height: 2),
              Text(
                example,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: Colors.greenAccent),
              ),
              const SizedBox(height: 2),
              Text(desc,
                  style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.3))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChordSheetField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _hasContent
              ? Colors.greenAccent.withOpacity(0.3)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mini toolbar label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.piano_outlined, size: 14, color: Colors.white.withOpacity(0.3)),
                const SizedBox(width: 6),
                Text(
                  'Chord Sheet Editor  •  monospace',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.3),
                      letterSpacing: 0.3),
                ),
                const Spacer(),
                if (_hasContent)
                  GestureDetector(
                    onTap: () {
                      _tabCtrl.animateTo(1);
                    },
                    child: Row(
                      children: [
                        Icon(Icons.visibility_outlined,
                            size: 13, color: Colors.greenAccent.withOpacity(0.7)),
                        const SizedBox(width: 4),
                        Text(
                          'Preview',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.greenAccent.withOpacity(0.7)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          TextField(
            controller: _contentCtrl,
            maxLines: null,
            minLines: 14,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontFamily: 'monospace',
              height: 1.6,
            ),
            decoration: InputDecoration(
              hintText:
                  '[Verse 1]\n    Am        F\nI walked a lonely road\n    C         G\nThe only one that I have known',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.18),
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.6,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PREVIEW TAB
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPreview() {
    if (!_hasContent) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music_outlined,
                size: 48, color: Colors.white.withOpacity(0.12)),
            const SizedBox(height: 12),
            Text(
              'Your chord sheet will appear here',
              style: TextStyle(
                  color: Colors.white.withOpacity(0.3), fontSize: 14),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => _tabCtrl.animateTo(0),
              child: const Text('Go to Edit tab',
                  style: TextStyle(color: Colors.greenAccent, fontSize: 13)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metadata summary card
          Container(
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: const Color(0xFF13131A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.07)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _titleCtrl.text.isEmpty ? 'Untitled' : _titleCtrl.text,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
                if (_artistCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(_artistCtrl.text,
                      style: TextStyle(
                          fontSize: 14, color: Colors.white.withOpacity(0.4))),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _chip('Key of $_key'),
                    if (_capo > 0) _chip('Capo $_capo'),
                    _chip(_difficulty),
                    _chip(_genre),
                  ],
                ),
              ],
            ),
          ),
          ChordSheetRenderer(content: _contentCtrl.text),
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.55),
              fontWeight: FontWeight.w500)),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Warn before discarding if anything has been typed
  Future<void> _confirmDiscard() async {
    final dirty = _hasTitle || _hasArtist || _hasContent;
    if (!dirty) {
      Navigator.pop(context);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Discard post?',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(
          'You\'ll lose everything you\'ve typed.',
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing',
                style: TextStyle(color: Colors.greenAccent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Discard',
                style: TextStyle(color: Colors.redAccent.withOpacity(0.8))),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) Navigator.pop(context);
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: ctrl,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13),
        prefixIcon:
            Icon(icon, color: Colors.white.withOpacity(0.3), size: 18),
        filled: true,
        fillColor: const Color(0xFF13131A),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.greenAccent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.35),
                letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF13131A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E28),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white38, size: 18),
              items: items
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}