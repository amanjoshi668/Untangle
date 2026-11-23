import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/decision_book_catalog.dart';
import '../models/decision_model.dart';
import 'auth_service.dart';
import 'gcp_backend_service.dart';
import 'native_bridge_service.dart';

class VaultStorage extends ChangeNotifier {
  static const String _keyPrefix = 'untangle_vault_v2_';
  static const String _themePrefsKey = 'untangle_theme_mode_v2';

  final GcpBackendService backend;
  AuthService auth;

  String _loadedUserId = '';
  ThemeMode _themeMode = ThemeMode.light;
  bool _defaultSeeded = false;
  bool _hasUserCreatedItems = false;
  bool _remindersEnabled = false;
  String _amTime = '08:30';
  String _pmTime = '20:30';
  final Set<int> _bookmarks = <int>{};
  final List<SavedDecision> _decisions = <SavedDecision>[];
  final Map<int, DecisionWorkspaceData> _drafts = <int, DecisionWorkspaceData>{};

  VaultStorage({required this.backend, required this.auth});

  ThemeMode get themeMode => _themeMode;
  bool get defaultSeeded => _defaultSeeded;
  bool get hasUserCreatedItems => _hasUserCreatedItems;
  bool get remindersEnabled => _remindersEnabled;
  String get amTime => _amTime;
  String get pmTime => _pmTime;
  Set<int> get bookmarks => Set.unmodifiable(_bookmarks);
  List<SavedDecision> get decisions => List.unmodifiable(_decisions);

  List<SavedDecision> dueReviews(DateTime realNow) =>
      _decisions.where((d) => d.isReviewDueOn(realNow)).toList();

  static String storageKeyFor(String userId) => '$_keyPrefix$userId';

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themePrefsKey);
    if (savedTheme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else if (savedTheme == 'light') {
      _themeMode = ThemeMode.light;
    }
    await loadForUser(auth.currentUser.id, sessionToken: auth.sessionToken);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefsKey, mode == ThemeMode.dark ? 'dark' : 'light');
    notifyListeners();
  }

  void _clearInMemory() {
    _defaultSeeded = false;
    _hasUserCreatedItems = false;
    _remindersEnabled = false;
    _amTime = '08:30';
    _pmTime = '20:30';
    _bookmarks.clear();
    _decisions.clear();
    _drafts.clear();
  }

  Future<void> loadForUser(String userId, {String sessionToken = ''}) async {
    _loadedUserId = userId;
    _clearInMemory();

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKeyFor(userId));
    if (raw != null && raw.isNotEmpty) {
      try {
        _hydrateFromMap(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    }

    // Seed starter item strictly ONCE per vault so deleted defaults never respawn
    if (!_defaultSeeded) {
      _defaultSeeded = true;
      _bookmarks.addAll(const [1, 6, 14]);
      final rubberBand = modelById(6);
      final sampleWs = DecisionWorkspaceData.fromSpec(
        rubberBand,
        loadSample: true,
        initialTopic: 'Startup Head of Product Offer vs. Current Role',
      );
      final todayStr = _dateStr(DateTime.now());
      _decisions.add(
        SavedDecision(
          id: 'seed_rubber_band_1',
          modelId: 6,
          title: sampleWs.topic,
          verdict: sampleWs.computeTakeaway(rubberBand),
          createdAtIso: DateTime.now().toIso8601String(),
          nextReviewDateIso: todayStr,
          reviewStage: 0,
          seeded: true,
          workspaceMap: sampleWs.toMap(),
        ),
      );
      await _persistToDisk();
    }

    notifyListeners();

    // Background cloud hydrate for authenticated sessions when local vault has no user-authored items
    if (!auth.isGuest && !sessionToken.startsWith('local_') && !_hasUserCreatedItems) {
      final cloudMap = await backend.pullVaultSnapshot(sessionToken);
      if (cloudMap != null && _loadedUserId == userId) {
        _hydrateFromMap(cloudMap);
        await _persistToDisk();
        notifyListeners();
      }
    }
  }

  /// Zero-loss Guest -> Authenticated Account upgrade, plus strict isolation on sign-out
  Future<String?> upgradeGuestOrSwitchAccount({
    required Future<String?> Function() authAction,
  }) async {
    final wasGuest = auth.isGuest;
    final guestDecisions = wasGuest
        ? _decisions.where((d) => !d.seeded).toList()
        : <SavedDecision>[];
    final guestBookmarks = wasGuest ? Set<int>.from(_bookmarks) : <int>{};
    final guesthadUserItems = wasGuest && _hasUserCreatedItems;

    final err = await authAction();
    if (err != null) return err;

    final newUserId = auth.currentUser.id;
    await loadForUser(newUserId, sessionToken: auth.sessionToken);

    if (wasGuest && (guestDecisions.isNotEmpty || guesthadUserItems)) {
      final existingIds = _decisions.map((d) => d.id).toSet();
      for (final gd in guestDecisions.reversed) {
        if (existingIds.add(gd.id)) {
          _decisions.insert(0, gd);
        }
      }
      _bookmarks.addAll(guestBookmarks);
      _hasUserCreatedItems = true;
      await _persistToDisk();
      _syncToCloud();

      // Clean guest storage key after successful migration
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKeyFor(AppUser.guest.id));
      notifyListeners();
    }
    return null;
  }

  Future<void> signOutCleanly() async {
    _clearInMemory();
    await auth.signOutToGuest();
    await loadForUser(auth.currentUser.id, sessionToken: auth.sessionToken);
  }

  DecisionWorkspaceData getWorkspaceDraft(DecisionModelSpec spec, {String? problemSeed}) {
    if (problemSeed != null && problemSeed.trim().isNotEmpty) {
      final seededWs = DecisionWorkspaceData.fromSpec(spec, loadSample: true, initialTopic: problemSeed);
      _drafts[spec.id] = seededWs;
      return seededWs;
    }
    return _drafts.putIfAbsent(spec.id, () => DecisionWorkspaceData.fromSpec(spec, loadSample: true));
  }

  void setWorkspaceDraft(int modelId, DecisionWorkspaceData ws) {
    _drafts[modelId] = ws;
    notifyListeners();
  }

  Future<void> toggleBookmark(int modelId) async {
    if (!_bookmarks.remove(modelId)) {
      _bookmarks.add(modelId);
    }
    await _persistToDisk();
    notifyListeners();
    _syncToCloud();
  }

  Future<SavedDecision> saveDecisionFromWorkspace(
    DecisionModelSpec spec,
    DecisionWorkspaceData ws, {
    DateTime? nowOverride,
  }) async {
    final now = nowOverride ?? DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final saved = SavedDecision(
      id: 'dec_${now.microsecondsSinceEpoch}',
      modelId: spec.id,
      title: ws.topic.trim().isEmpty ? spec.title : ws.topic.trim(),
      verdict: ws.computeTakeaway(spec),
      createdAtIso: now.toIso8601String(),
      nextReviewDateIso: _dateStr(tomorrow),
      reviewStage: 0,
      seeded: false,
      workspaceMap: ws.toMap(),
    );
    _decisions.insert(0, saved);
    _hasUserCreatedItems = true;
    await _persistToDisk();
    notifyListeners();
    _syncToCloud();
    return saved;
  }

  Future<void> deleteDecision(String decisionId) async {
    _decisions.removeWhere((d) => d.id == decisionId);
    await _persistToDisk();
    notifyListeners();
    _syncToCloud();
  }

  /// Real-calendar resilient 1-tap catch-up for SuperMemo spaced decision reviews
  Future<void> completeReviewCatchUp(String decisionId, {DateTime? realToday}) async {
    final today = realToday ?? DateTime.now();
    final idx = _decisions.indexWhere((d) => d.id == decisionId);
    if (idx == -1) return;
    _decisions[idx] = _decisions[idx].advanceSuperMemo(today);
    await _persistToDisk();
    notifyListeners();
    _syncToCloud();
  }

  Future<void> catchUpAllOverdueReviews({DateTime? realToday}) async {
    final today = realToday ?? DateTime.now();
    for (int i = 0; i < _decisions.length; i++) {
      if (_decisions[i].isReviewDueOn(today)) {
        _decisions[i] = _decisions[i].advanceSuperMemo(today);
      }
    }
    await _persistToDisk();
    notifyListeners();
    _syncToCloud();
  }

  Future<void> updateReminders({
    required bool enabled,
    String? amTime24,
    String? pmTime24,
  }) async {
    if (amTime24 != null) _amTime = amTime24;
    if (pmTime24 != null) _pmTime = pmTime24;
    final applied = await NativeBridgeService.syncReflectionReminders(
      enabled: enabled,
      amTime24: _amTime,
      pmTime24: _pmTime,
    );
    _remindersEnabled = enabled ? applied : false;
    await _persistToDisk();
    notifyListeners();
    _syncToCloud();
  }

  String buildMarkdownBrief() {
    if (_decisions.isEmpty) {
      return '# Untangle Decision Journal\n\nNo saved decisions yet.\n';
    }
    final buf = StringBuffer('# Untangle Decision Journal\n\n');
    for (final d in _decisions) {
      final spec = modelById(d.modelId);
      buf.writeln('## ${d.title}');
      buf.writeln('- **Technique:** #${spec.id.toString().padLeft(2, '0')} ${spec.title}');
      buf.writeln('- **Takeaway:** ${d.verdict}');
      buf.writeln('- **Next Spaced Review:** ${d.nextReviewDateIso}');
      buf.writeln();
    }
    return buf.toString();
  }

  Map<String, dynamic> exportSnapshotMap() => {
        'defaultSeeded': _defaultSeeded,
        'hasUserCreatedItems': _hasUserCreatedItems,
        'remindersEnabled': _remindersEnabled,
        'amTime': _amTime,
        'pmTime': _pmTime,
        'bookmarks': _bookmarks.toList(),
        'decisions': _decisions.map((d) => d.toMap()).toList(),
      };

  void _hydrateFromMap(Map<String, dynamic> map) {
    _defaultSeeded = map['defaultSeeded'] == true;
    _hasUserCreatedItems = map['hasUserCreatedItems'] == true;
    _remindersEnabled = map['remindersEnabled'] == true;
    _amTime = (map['amTime'] ?? '08:30').toString();
    _pmTime = (map['pmTime'] ?? '20:30').toString();
    _bookmarks
      ..clear()
      ..addAll(((map['bookmarks'] as List?) ?? []).map((e) => (e as num).toInt()));
    _decisions
      ..clear()
      ..addAll(
        ((map['decisions'] as List?) ?? [])
            .map((e) => SavedDecision.fromMap(Map<String, dynamic>.from(e as Map))),
      );
  }

  Future<void> _persistToDisk() async {
    if (_loadedUserId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKeyFor(_loadedUserId), jsonEncode(exportSnapshotMap()));
  }

  void _syncToCloud() {
    if (auth.isGuest || auth.sessionToken.startsWith('local_')) return;
    backend.pushVaultSnapshot(auth.sessionToken, exportSnapshotMap());
  }

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
