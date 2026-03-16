import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import 'forum_models.dart';
import 'forum_service.dart';
import 'chord_sheet_renderer.dart';

class CreatePostPage extends StatefulWidget {
  const CreatePostPage({super.key});

  @override
  State<CreatePostPage> createState() => _CreatePostPageState();
}

class _CreatePostPageState extends State<CreatePostPage>
    with SingleTickerProviderStateMixin {

  final ForumService _service = ForumService();
  final _formKey = GlobalKey<FormState>();

  // Metadata controllers
  final _titleCtrl  = TextEditingController();
  final _artistCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  String _key        = 'C';
  int    _capo       = 0;
  String _difficulty = 'Beginner';
  String _genre      = 'Pop';

  bool _showPreview = false;
  bool _isSubmitting = false;

  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {
      _showPreview = _tabCtrl.index == 1;
    }));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _contentCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_contentCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add some chord sheet content')),
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
          SnackBar(content: Text('Failed to post: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white54),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('New Chord Sheet',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.greenAccent))
                  : const Text('Post',
                      style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.greenAccent,
          labelColor: Colors.greenAccent,
          unselectedLabelColor: Colors.white38,
          tabs: const [
            Tab(text: 'Edit'),
            Tab(text: 'Preview'),
          ],
        ),
      ),
      body: Form(
        key: _formKey,
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildEditor(),
            _buildPreview(),
          ],
        ),
      ),
    );
  }

  // ── Editor tab ──────────────────────────────────────────────────────────────

  Widget _buildEditor() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Song info ────────────────────────────────────────────────
          _sectionLabel('Song Info'),
          const SizedBox(height: 10),
          _field(_titleCtrl,  'Song title',  Icons.music_note_outlined,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Title required' : null),
          const SizedBox(height: 10),
          _field(_artistCtrl, 'Artist name', Icons.person_outline,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Artist required' : null),
          const SizedBox(height: 20),

          // ── Tags ─────────────────────────────────────────────────────
          _sectionLabel('Tags'),
          const SizedBox(height: 10),

          // Key + Capo
          Row(children: [
            Expanded(
              child: _dropdown(
                label: 'Key',
                value: _key,
                items: kKeys,
                onChanged: (v) => setState(() => _key = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dropdown(
                label: 'Capo',
                value: _capo.toString(),
                items: List.generate(12, (i) => i.toString()),
                onChanged: (v) => setState(() => _capo = int.parse(v!)),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          // Difficulty + Genre
          Row(children: [
            Expanded(
              child: _dropdown(
                label: 'Difficulty',
                value: _difficulty,
                items: kDifficulties,
                onChanged: (v) => setState(() => _difficulty = v!),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _dropdown(
                label: 'Genre',
                value: _genre,
                items: kGenres,
                onChanged: (v) => setState(() => _genre = v!),
              ),
            ),
          ]),
          const SizedBox(height: 20),

          // ── Chord sheet ──────────────────────────────────────────────
          _sectionLabel('Chord Sheet'),
          const SizedBox(height: 6),
          _buildFormatHint(),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF13131A),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: TextField(
              controller: _contentCtrl,
              maxLines: null,
              minLines: 16,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.white,
                fontFamily: 'monospace',
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText:
                    '[Verse 1]\n    Am        F\nI walked a lonely road\n    C         G\nThe only one that I have known',
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.2),
                    fontFamily: 'monospace',
                    fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatHint() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Format guide',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.4),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
          const SizedBox(height: 6),
          _hint('[Verse 1]',   'Section header in square brackets'),
          _hint('    Am    F', 'Chord line — names separated by spaces'),
          _hint('lyrics here', 'Lyric line directly below chords'),
        ],
      ),
    );
  }

  Widget _hint(String code, String desc) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(children: [
        Text(code,
            style: const TextStyle(
                fontSize: 12,
                color: Colors.greenAccent,
                fontFamily: 'monospace')),
        const SizedBox(width: 10),
        Text(desc,
            style: TextStyle(
                fontSize: 12,
                color: Colors.white.withOpacity(0.35))),
      ]),
    );
  }

  // ── Preview tab ─────────────────────────────────────────────────────────────

  Widget _buildPreview() {
    if (_contentCtrl.text.trim().isEmpty) {
      return Center(
        child: Text('Nothing to preview yet',
            style: TextStyle(
                color: Colors.white.withOpacity(0.3), fontSize: 14)),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _titleCtrl.text.isEmpty ? 'Untitled' : _titleCtrl.text,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white),
          ),
          if (_artistCtrl.text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_artistCtrl.text,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.45))),
          ],
          const SizedBox(height: 16),
          ChordSheetRenderer(content: _contentCtrl.text),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Text(
        label.toUpperCase(),
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(0.3),
            letterSpacing: 1.4),
      );

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
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Colors.greenAccent, width: 1.5),
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
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF13131A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.white.withOpacity(0.08)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E28),
              style: const TextStyle(
                  color: Colors.white, fontSize: 14),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white38, size: 18),
              items: items
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e),
                      ))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}