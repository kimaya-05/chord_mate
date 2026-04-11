import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../auth/auth_provider.dart';
import 'forum_models.dart';
import 'forum_service.dart';
import 'post_viewer_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ModeratorDashboardPage — 2-tab shell: Reports + Users
// ─────────────────────────────────────────────────────────────────────────────

class ModeratorDashboardPage extends StatefulWidget {
  const ModeratorDashboardPage({super.key});

  @override
  State<ModeratorDashboardPage> createState() =>
      _ModeratorDashboardPageState();
}

class _ModeratorDashboardPageState extends State<ModeratorDashboardPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final ForumService _service = ForumService();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: const Text(
          'Moderator Dashboard',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => auth.signOut(),
            child: const Text('Sign out',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.greenAccent,
          indicatorWeight: 2,
          labelColor: Colors.greenAccent,
          unselectedLabelColor: Colors.white38,
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'REPORTS'),
            Tab(text: 'USERS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ReportsTab(service: _service),
          _UsersTab(service: _service),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 1 — REPORTS
// ═════════════════════════════════════════════════════════════════════════════

class _ReportsTab extends StatefulWidget {
  final ForumService service;
  const _ReportsTab({required this.service});

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  /// false = unresolved, true = resolved
  bool _showResolved = false;

  String?   _filterReason;
  String?   _filterUser;
  DateTime? _filterDateFrom;
  final _userSearchCtrl = TextEditingController();

  static const List<String> _reasonOptions = [
    'Incorrect chords',
    'Inappropriate content',
    'Spam or advertisement',
    'Copyright violation',
    'Other',
  ];

  bool get _hasFilters =>
      _filterReason != null ||
      _filterUser   != null ||
      _filterDateFrom != null;

  void _clearFilters() {
    _userSearchCtrl.clear();
    setState(() {
      _filterReason   = null;
      _filterUser     = null;
      _filterDateFrom = null;
    });
  }

  List<ModeratorReport> _applyFilters(List<ModeratorReport> all) {
    return all.where((r) {
      if (_filterReason != null && r.reason != _filterReason) return false;
      if (_filterUser   != null &&
          !r.reporterName.toLowerCase()
              .contains(_filterUser!.toLowerCase())) return false;
      if (_filterDateFrom != null &&
          r.createdAt.isBefore(_filterDateFrom!)) return false;
      return true;
    }).toList();
  }

  @override
  void dispose() {
    _userSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildFilterBar(),
        if (_hasFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Text('Filters active',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4))),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _clearFilters,
                child: const Text('Clear all',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        Expanded(
          child: StreamBuilder<List<ModeratorReport>>(
            stream: widget.service
                .modReportsStream(resolvedOnly: _showResolved),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.greenAccent));
              }
              final reports = _applyFilters(snapshot.data ?? []);
              if (reports.isEmpty) {
                return _EmptyState(
                  icon: _showResolved
                      ? Icons.check_circle_outline
                      : Icons.inbox_outlined,
                  message: _hasFilters
                      ? 'No reports match your filters'
                      : _showResolved
                          ? 'No resolved reports yet'
                          : 'No open reports — all clear!',
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: reports.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _ReportCard(
                    report: reports[i], service: widget.service),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: const Color(0xFF0A0A0F),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('REPORTS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.3),
                    letterSpacing: 1.4)),
            const Spacer(),
            // Date filter
            _FilterPill(
              label: _filterDateFrom == null
                  ? 'Any date'
                  : 'From ${_filterDateFrom!.day}/${_filterDateFrom!.month}',
              active: _filterDateFrom != null,
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _filterDateFrom ?? DateTime.now(),
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now(),
                  builder: (_, child) => Theme(
                    data: ThemeData.dark().copyWith(
                      colorScheme: const ColorScheme.dark(
                          primary: Colors.greenAccent),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => _filterDateFrom = picked);
              },
              onClear: () => setState(() => _filterDateFrom = null),
            ),
            const SizedBox(width: 8),
            // Resolved / Unresolved toggle
            _SegmentedToggle(
              options: const ['Unresolved', 'Resolved'],
              selected: _showResolved ? 1 : 0,
              onChanged: (i) => setState(() => _showResolved = i == 1),
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: _FilterPill(
                label: _filterReason ?? 'Report type',
                active: _filterReason != null,
                onTap: _showReasonPicker,
                onClear: () => setState(() => _filterReason = null),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _userSearchCtrl,
                style:
                    const TextStyle(color: Colors.white, fontSize: 12),
                onChanged: (v) => setState(() =>
                    _filterUser = v.trim().isEmpty ? null : v.trim()),
                decoration: InputDecoration(
                  hintText: 'Reporter name…',
                  hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 12),
                  prefixIcon: Icon(Icons.person_search_outlined,
                      color: Colors.white.withOpacity(0.3), size: 16),
                  suffixIcon: _filterUser != null
                      ? GestureDetector(
                          onTap: () {
                            _userSearchCtrl.clear();
                            setState(() => _filterUser = null);
                          },
                          child: const Icon(Icons.close,
                              color: Colors.white38, size: 16),
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 12),
                  filled: true,
                  fillColor: const Color(0xFF13131A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                        color: Colors.greenAccent, width: 1.5),
                  ),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  void _showReasonPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13131A),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('Filter by report type',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700)),
          ),
          ..._reasonOptions.map((r) => ListTile(
                title: Text(r,
                    style: const TextStyle(color: Colors.white)),
                trailing: _filterReason == r
                    ? const Icon(Icons.check,
                        color: Colors.greenAccent)
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  setState(() =>
                      _filterReason = _filterReason == r ? null : r);
                },
              )),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 2 — USERS
// ═════════════════════════════════════════════════════════════════════════════

class _UsersTab extends StatefulWidget {
  final ForumService service;
  const _UsersTab({required this.service});

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final _searchCtrl = TextEditingController();
  String _query        = '';
  String _statusFilter = 'All';

  static const _statusOptions = [
    'All', 'Active', 'Warned', 'Muted', 'Suspended', 'Banned',
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Search + status filter bar ──────────────────────────────────────
        Container(
          color: const Color(0xFF0A0A0F),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                style:
                    const TextStyle(color: Colors.white, fontSize: 13),
                onChanged: (v) => setState(() => _query = v.trim()),
                decoration: InputDecoration(
                  hintText: 'Search by name or email…',
                  hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 13),
                  prefixIcon: Icon(Icons.search,
                      color: Colors.white.withOpacity(0.3), size: 18),
                  suffixIcon: _query.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _query = '');
                          },
                          child: const Icon(Icons.close,
                              color: Colors.white38, size: 16),
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: 10, horizontal: 14),
                  filled: true,
                  fillColor: const Color(0xFF13131A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: Colors.greenAccent, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _statusOptions.map((s) {
                    final active = _statusFilter == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _statusFilter = s),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: active
                                ? Colors.greenAccent.withOpacity(0.12)
                                : const Color(0xFF13131A),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: active
                                  ? Colors.greenAccent.withOpacity(0.5)
                                  : Colors.white12,
                            ),
                          ),
                          child: Text(
                            s,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? Colors.greenAccent
                                  : Colors.white38,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.white.withOpacity(0.06)),

        // ── User list ───────────────────────────────────────────────────────
        Expanded(
          child: StreamBuilder<List<AppUserRecord>>(
            stream: widget.service.usersStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.greenAccent));
              }
              if (snapshot.hasError) {
                return _EmptyState(
                  icon: Icons.error_outline,
                  message: 'Error loading users: ${snapshot.error}',
                );
              }
              var users = snapshot.data ?? [];

              if (_query.isNotEmpty) {
                final q = _query.toLowerCase();
                users = users
                    .where((u) =>
                        u.displayName.toLowerCase().contains(q) ||
                        u.email.toLowerCase().contains(q))
                    .toList();
              }
              if (_statusFilter != 'All') {
                users = users
                    .where((u) =>
                        u.status.toLowerCase() ==
                        _statusFilter.toLowerCase())
                    .toList();
              }

              if (users.isEmpty) {
                return _EmptyState(
                  icon: Icons.people_outline,
                  message: _query.isNotEmpty
                      ? 'No users match "$_query"'
                      : 'No users found',
                );
              }

              return ListView.separated(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: users.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 8),
                itemBuilder: (_, i) => _UserCard(
                    user: users[i], service: widget.service),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _UserCard
// ─────────────────────────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final AppUserRecord user;
  final ForumService  service;

  const _UserCard({required this.user, required this.service});

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'banned':    return Colors.redAccent;
      case 'suspended': return Colors.orangeAccent;
      case 'muted':     return Colors.amber;
      case 'warned':    return const Color(0xFF7E8CE0);
      default:          return Colors.greenAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sc = _statusColor(user.status);
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: const Color(0xFF13131A),
        shape: const RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) =>
            _UserDetailSheet(user: user, service: service),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: user.status == 'active'
                ? Colors.white.withOpacity(0.06)
                : sc.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: sc.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: sc.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  user.displayName.isNotEmpty
                      ? user.displayName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: sc),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(user.displayName,
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(width: 8),
                    _StatusBadge(status: user.status),
                    if (user.shadowBanned) ...[
                      const SizedBox(width: 6),
                      _ShadowBadge(),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(user.email,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.35)),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    _InfractionDot(
                        count: user.majorInfractions,
                        color: Colors.redAccent,
                        label: 'major'),
                    const SizedBox(width: 10),
                    _InfractionDot(
                        count: user.minorInfractions,
                        color: Colors.orangeAccent,
                        label: 'minor'),
                  ]),
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: Colors.white.withOpacity(0.2), size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _UserDetailSheet
// ─────────────────────────────────────────────────────────────────────────────

class _UserDetailSheet extends StatelessWidget {
  final AppUserRecord user;
  final ForumService  service;

  const _UserDetailSheet({required this.user, required this.service});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize:     0.5,
      maxChildSize:     0.95,
      expand: false,
      builder: (_, ctrl) => SingleChildScrollView(
        controller: ctrl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(children: [
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Center(
                    child: Text(
                      user.displayName.isNotEmpty
                          ? user.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.displayName,
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(user.email,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.4))),
                      const SizedBox(height: 6),
                      Row(children: [
                        _StatusBadge(status: user.status),
                        if (user.shadowBanned) ...[
                          const SizedBox(width: 6),
                          _ShadowBadge(),
                        ],
                      ]),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 20),

              // Stats
              Row(children: [
                _StatBox(label: 'Major',
                    value: '${user.majorInfractions}',
                    valueColor: Colors.redAccent),
                const SizedBox(width: 8),
                _StatBox(label: 'Minor',
                    value: '${user.minorInfractions}',
                    valueColor: Colors.orangeAccent),
                const SizedBox(width: 8),
                _StatBox(label: 'Joined',
                    value: _shortDate(user.joinedAt)),
              ]),
              const SizedBox(height: 24),

              // Restriction end time (if active)
              if (user.restrictionEndsAt != null &&
                  user.restrictionEndsAt!.isAfter(DateTime.now())) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orangeAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: Colors.orangeAccent.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.timer_outlined,
                        size: 14, color: Colors.orangeAccent),
                    const SizedBox(width: 8),
                    Text(
                      'Restriction ends ${_fullDate(user.restrictionEndsAt!)}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.orangeAccent),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),
              ],

              // Infraction history
              Text('INFRACTION HISTORY',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withOpacity(0.3),
                      letterSpacing: 1.4)),
              const SizedBox(height: 10),
              if (user.infractionHistory.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text('No infractions on record.',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.3))),
                )
              else ...[
                ...user.infractionHistory.reversed
                    .map((inf) => _InfractionRow(infraction: inf)),
                const SizedBox(height: 20),
              ],

              // Actions
              Text('MODERATION ACTIONS',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withOpacity(0.3),
                      letterSpacing: 1.4)),
              const SizedBox(height: 12),
              _UserActionGrid(
                  user: user, service: service),
            ],
          ),
        ),
      ),
    );
  }

  String _shortDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year.toString().substring(2)}';
  String _fullDate(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year} at ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

// ─────────────────────────────────────────────────────────────────────────────
// _UserActionGrid
// ─────────────────────────────────────────────────────────────────────────────

class _UserActionGrid extends StatelessWidget {
  final AppUserRecord user;
  final ForumService  service;

  const _UserActionGrid({required this.user, required this.service});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(children: [
          Expanded(child: _UserActionButton(
            label: 'Warn',
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFF7E8CE0),
            onTap: () => _warn(context),
          )),
          const SizedBox(width: 8),
          Expanded(child: _UserActionButton(
            label: 'Mute',
            icon: Icons.mic_off_outlined,
            color: Colors.amber,
            onTap: () => _showDurationPicker(context,
                title: 'Mute ${user.displayName}',
                onConfirm: (d) => service.muteUser(user.uid, d)),
          )),
          const SizedBox(width: 8),
          Expanded(child: _UserActionButton(
            label: 'Suspend',
            icon: Icons.pause_circle_outline,
            color: Colors.orangeAccent,
            onTap: () => _showDurationPicker(context,
                title: 'Suspend ${user.displayName}',
                onConfirm: (d) => service.suspendUser(user.uid, d)),
          )),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _UserActionButton(
            label: 'Ban',
            icon: Icons.block,
            color: Colors.redAccent,
            onTap: () => _ban(context),
          )),
          const SizedBox(width: 8),
          Expanded(child: _UserActionButton(
            label: user.shadowBanned ? 'Un-shadow' : 'Shadow Ban',
            icon: Icons.visibility_off_outlined,
            color: Colors.purple,
            onTap: () => _shadowBan(context),
          )),
          const SizedBox(width: 8),
          Expanded(child: _UserActionButton(
            label: 'Restore',
            icon: Icons.undo_rounded,
            color: Colors.greenAccent,
            onTap: () => _restore(context),
          )),
        ]),
      ],
    );
  }

  void _warn(BuildContext ctx) async {
    await service.warnUser(user.uid);
    if (ctx.mounted) {
      Navigator.pop(ctx);
      ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('${user.displayName} warned')));
    }
  }

  void _ban(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => _ConfirmDialog(
        title: 'Ban ${user.displayName}?',
        body:  'This user will be permanently banned.',
        confirmLabel: 'Ban',
        confirmColor: Colors.redAccent,
        onConfirm: () async {
          await service.banUser(user.uid);
          if (ctx.mounted) Navigator.pop(ctx);
        },
      ),
    );
  }

  void _shadowBan(BuildContext ctx) async {
    await service.shadowBanUser(user.uid, enable: !user.shadowBanned);
    if (ctx.mounted) {
      Navigator.pop(ctx);
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(user.shadowBanned
              ? '${user.displayName} un-shadow-banned'
              : '${user.displayName} shadow-banned')));
    }
  }

  void _restore(BuildContext ctx) async {
    await service.restoreUser(user.uid);
    if (ctx.mounted) {
      Navigator.pop(ctx);
      ScaffoldMessenger.of(ctx).showSnackBar(
          SnackBar(content: Text('${user.displayName} restored')));
    }
  }

  void _showDurationPicker(
    BuildContext ctx, {
    required String title,
    required Future<void> Function(Duration) onConfirm,
  }) {
    Duration selected = const Duration(hours: 24);
    final options = {
      '1 hour':   const Duration(hours: 1),
      '24 hours': const Duration(hours: 24),
      '7 days':   const Duration(days: 7),
      '30 days':  const Duration(days: 30),
    };
    showDialog(
      context: ctx,
      builder: (_) => StatefulBuilder(
        builder: (dCtx, setS) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E28),
          title: Text(title,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.entries.map((e) {
              return RadioListTile<Duration>(
                value: e.value,
                groupValue: selected,
                onChanged: (v) => setS(() => selected = v!),
                activeColor: Colors.greenAccent,
                title: Text(e.key,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14)),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dCtx),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white38))),
            TextButton(
                onPressed: () async {
                  Navigator.pop(dCtx);
                  await onConfirm(selected);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Confirm',
                    style:
                        TextStyle(color: Colors.greenAccent))),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReportCard
// ─────────────────────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final ModeratorReport report;
  final ForumService    service;
  const _ReportCard({required this.report, required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: report.resolved
              ? Colors.white.withOpacity(0.05)
              : Colors.redAccent.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: report.resolved
                    ? Colors.white.withOpacity(0.05)
                    : Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                report.resolved ? 'Resolved' : 'Open',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: report.resolved
                        ? Colors.white38
                        : Colors.redAccent,
                    letterSpacing: 0.5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(report.postTitle,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.flag_outlined,
                size: 13,
                color: Colors.white.withOpacity(0.35)),
            const SizedBox(width: 6),
            Text(report.reason,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.6))),
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Icon(Icons.person_outline,
                size: 13,
                color: Colors.white.withOpacity(0.3)),
            const SizedBox(width: 6),
            Expanded(
              child: Text('Reported by ${report.reporterName}',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.3))),
            ),
            Text(_timeAgo(report.createdAt),
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.25))),
          ]),

          // Action buttons — only on unresolved reports
          if (!report.resolved) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: Colors.white.withOpacity(0.06)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _ActionButton(
                label: 'View',
                icon: Icons.visibility_outlined,
                color: Colors.white54,
                onTap: () async {
                  try {
                    final post = await FirebaseForumHelper
                        .getPostDoc(report.postId);
                    if (post != null && context.mounted) {
                      Navigator.push(context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  PostViewerPage(post: post)));
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Post not found')));
                    }
                  }
                },
              )),
              const SizedBox(width: 6),
              Expanded(child: _ActionButton(
                label: 'Edit',
                icon: Icons.edit_outlined,
                color: const Color(0xFF7E8CE0),
                onTap: () async {
                  try {
                    final post = await FirebaseForumHelper
                        .getPostDoc(report.postId);
                    if (post != null && context.mounted) {
                      _showEditSheet(context, post);
                    }
                  } catch (_) {}
                },
              )),
              const SizedBox(width: 6),
              Expanded(child: _ActionButton(
                label: 'Delete',
                icon: Icons.delete_outline,
                color: Colors.redAccent,
                onTap: () => _confirmDelete(context),
              )),
              const SizedBox(width: 6),
              Expanded(child: _ActionButton(
                label: 'Dismiss',
                icon: Icons.check,
                color: Colors.greenAccent,
                onTap: () => service.resolveReport(report.id),
              )),
            ]),
            const SizedBox(height: 8),
            _ActionButton(
              label: 'Ban Post Author',
              icon: Icons.block,
              color: Colors.orangeAccent,
              onTap: () => _confirmBan(context),
              fullWidth: true,
            ),
          ],
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, ForumPost post) {
    final contentCtrl = TextEditingController(text: post.content);
    String key        = post.key;
    int    capo       = post.capo;
    String difficulty = post.difficulty;
    String genre      = post.genre;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF13131A),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                Text('Edit: ${post.title}',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _EditDropdown(
                    label: 'Key', value: key, items: kKeys,
                    onChanged: (v) =>
                        setModalState(() => key = v!),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _EditDropdown(
                    label: 'Capo',
                    value: capo.toString(),
                    items: List.generate(12, (i) => i.toString()),
                    onChanged: (v) =>
                        setModalState(() => capo = int.parse(v!)),
                  )),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _EditDropdown(
                    label: 'Difficulty', value: difficulty,
                    items: kDifficulties,
                    onChanged: (v) =>
                        setModalState(() => difficulty = v!),
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _EditDropdown(
                    label: 'Genre', value: genre, items: kGenres,
                    onChanged: (v) =>
                        setModalState(() => genre = v!),
                  )),
                ]),
                const SizedBox(height: 12),
                Text('Chord Sheet',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.35),
                        letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0A0A0F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.08)),
                  ),
                  child: TextField(
                    controller: contentCtrl,
                    maxLines: 8,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    await service.updatePost(post.copyWith(
                      content: contentCtrl.text,
                      key: key,
                      capo: capo,
                      difficulty: difficulty,
                      genre: genre,
                    ));
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Post updated')));
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7E8CE0)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: const Color(0xFF7E8CE0)
                              .withOpacity(0.4)),
                    ),
                    child: const Text('Save Changes',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF7E8CE0))),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Delete post?',
        body:
            'This will permanently delete "${report.postTitle}".',
        confirmLabel: 'Delete',
        confirmColor: Colors.redAccent,
        onConfirm: () => service.moderatorDeletePost(report.postId),
      ),
    );
  }

  void _confirmBan(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'Ban post author?',
        body:
            'This will permanently ban the author of "${report.postTitle}".',
        confirmLabel: 'Ban',
        confirmColor: Colors.orangeAccent,
        onConfirm: () async {
          await service.banUser(report.postAuthorUid);
          await service.resolveReport(report.id);
        },
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared small widgets
// ═════════════════════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String   message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48,
              color: Colors.greenAccent.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(message,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.35),
                  fontSize: 14),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  final List<String>  options;
  final int           selected;
  final ValueChanged<int> onChanged;

  const _SegmentedToggle({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.asMap().entries.map((e) {
          final active = e.key == selected;
          return GestureDetector(
            onTap: () => onChanged(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: active
                    ? Colors.greenAccent.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: active
                      ? Colors.greenAccent.withOpacity(0.4)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                e.value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: active
                      ? Colors.greenAccent
                      : Colors.white38,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  Color get _color {
    switch (status.toLowerCase()) {
      case 'banned':    return Colors.redAccent;
      case 'suspended': return Colors.orangeAccent;
      case 'muted':     return Colors.amber;
      case 'warned':    return const Color(0xFF7E8CE0);
      default:          return Colors.greenAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            color: _color,
            letterSpacing: 0.5),
      ),
    );
  }
}

class _ShadowBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.purple.withOpacity(0.4)),
      ),
      child: const Text('SHADOW',
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: Colors.purple,
              letterSpacing: 0.5)),
    );
  }
}

class _InfractionDot extends StatelessWidget {
  final int    count;
  final Color  color;
  final String label;
  const _InfractionDot({
    required this.count,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 7, height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 4),
      Text('$count $label',
          style: TextStyle(
              fontSize: 11, color: Colors.white.withOpacity(0.4))),
    ]);
  }
}

class _InfractionRow extends StatelessWidget {
  final InfractionRecord infraction;
  const _InfractionRow({required this.infraction});

  @override
  Widget build(BuildContext context) {
    final isMajor = infraction.severity == 'major';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 7, height: 7,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: isMajor
                  ? Colors.redAccent
                  : Colors.orangeAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(infraction.reason,
                    style: const TextStyle(
                        fontSize: 13, color: Colors.white70)),
                Text(
                  '${isMajor ? 'Major' : 'Minor'} · ${_date(infraction.createdAt)}',
                  style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.3)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _date(DateTime dt) =>
      '${dt.day}/${dt.month}/${dt.year}';
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _StatBox(
      {required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0F),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: Colors.white.withOpacity(0.06)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: valueColor ?? Colors.white)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.3),
                    letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }
}

class _UserActionButton extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  const _UserActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String       label;
  final IconData     icon;
  final Color        color;
  final VoidCallback onTap;
  final bool         fullWidth;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding:
            const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize:
              fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmDialog extends StatelessWidget {
  final String       title;
  final String       body;
  final String       confirmLabel;
  final Color        confirmColor;
  final VoidCallback onConfirm;

  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.confirmColor,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E1E28),
      title: Text(title,
          style: const TextStyle(color: Colors.white, fontSize: 16)),
      content: Text(body,
          style: TextStyle(color: Colors.white.withOpacity(0.6))),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white38))),
        TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text(confirmLabel,
                style: TextStyle(color: confirmColor))),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String       label;
  final bool         active;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: active ? onClear : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active
              ? Colors.greenAccent.withOpacity(0.1)
              : const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: active
                  ? Colors.greenAccent.withOpacity(0.4)
                  : Colors.white12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: active
                        ? Colors.greenAccent
                        : Colors.white38),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              active ? Icons.close : Icons.keyboard_arrow_down,
              size: 14,
              color: active ? Colors.greenAccent : Colors.white38,
            ),
          ],
        ),
      ),
    );
  }
}

class _EditDropdown extends StatelessWidget {
  final String               label;
  final String               value;
  final List<String>         items;
  final ValueChanged<String?> onChanged;

  const _EditDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.35),
                letterSpacing: 0.4)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0F),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: Colors.white.withOpacity(0.08)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E28),
              style: const TextStyle(
                  color: Colors.white, fontSize: 13),
              icon: const Icon(Icons.keyboard_arrow_down,
                  color: Colors.white38, size: 16),
              items: items
                  .map((e) =>
                      DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FirebaseForumHelper
// ─────────────────────────────────────────────────────────────────────────────

class FirebaseForumHelper {
  static Future<ForumPost?> getPostDoc(String postId) async {
    final snap = await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .get();
    if (!snap.exists) return null;
    return ForumPost.fromFirestore(snap);
  }
}