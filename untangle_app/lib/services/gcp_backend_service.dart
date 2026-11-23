import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CloudAiSuggestion {
  final List<int> modelIds;
  final String fitReason;
  final String suggestedTitle;
  final String source;

  const CloudAiSuggestion({
    required this.modelIds,
    required this.fitReason,
    required this.suggestedTitle,
    required this.source,
  });
}

class BugReportRecord {
  final String id;
  final String description;
  final String pageContext;
  final String appVersion;
  final String userEmail;
  final String createdAt;
  final bool syncedToCloud;
  final String status;

  const BugReportRecord({
    required this.id,
    required this.description,
    required this.pageContext,
    required this.appVersion,
    required this.userEmail,
    required this.createdAt,
    required this.syncedToCloud,
    this.status = 'open',
  });

  String get signature => '${userEmail.toLowerCase().trim()}|${description.trim()}';

  Map<String, dynamic> toMap() => {
        'id': id,
        'description': description,
        'pageContext': pageContext,
        'appVersion': appVersion,
        'userEmail': userEmail,
        'createdAt': createdAt,
        'syncedToCloud': syncedToCloud,
        'status': status,
      };

  factory BugReportRecord.fromMap(Map<String, dynamic> m, {bool defaultSynced = false}) {
    return BugReportRecord(
      id: (m['id'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      pageContext: (m['pageContext'] ?? m['page_context'] ?? '').toString(),
      appVersion: (m['appVersion'] ?? m['app_version'] ?? '1.0.0+1').toString(),
      userEmail: (m['userEmail'] ?? m['user_email'] ?? 'anonymous@tester.local').toString(),
      createdAt: (m['createdAt'] ?? m['created_at'] ?? DateTime.now().toIso8601String()).toString(),
      syncedToCloud: m['syncedToCloud'] == true || defaultSynced,
      status: (m['status'] ?? 'open').toString(),
    );
  }
}

class GcpBackendService {
  static const String defaultBaseUrl = String.fromEnvironment(
    'UNTANGLE_API_URL',
    defaultValue: 'http://localhost:8080',
  );
  static const String _localBugsKey = 'untangle_local_bugs_v1';
  static const String appVersion = '1.0.0+1';

  final String baseUrl;
  http.Client _client;

  GcpBackendService({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = (baseUrl ?? defaultBaseUrl).replaceAll(RegExp(r'/$'), ''),
        _client = client ?? http.Client();

  void setHttpClient(http.Client client) {
    _client = client;
  }

  // ===========================================================================
  // AUTH & CLOUD SNAPSHOT CALLS
  // ===========================================================================
  Future<Map<String, dynamic>?> registerEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final resp = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'name': name, 'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> loginEmail({
    required String email,
    required String password,
  }) async {
    try {
      final resp = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> initMobileGoogleSession() async {
    try {
      final resp = await _client
          .post(Uri.parse('$baseUrl/api/v1/auth/mobile-google/init'))
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        return data['sessionId']?.toString();
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> pollMobileGoogleSession(String sessionId) async {
    try {
      final resp = await _client
          .get(Uri.parse('$baseUrl/api/v1/auth/mobile-google/poll?session=$sessionId'))
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['ready'] == true) return data;
      }
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>?> pullVaultSnapshot(String jwtToken) async {
    if (jwtToken.isEmpty || jwtToken.startsWith('local_')) return null;
    try {
      final resp = await _client
          .get(
            Uri.parse('$baseUrl/api/v1/untangle/state'),
            headers: {'Authorization': 'Bearer $jwtToken'},
          )
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        if (data['snapshot'] is Map) {
          return Map<String, dynamic>.from(data['snapshot'] as Map);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<bool> pushVaultSnapshot(String jwtToken, Map<String, dynamic> snapshot) async {
    if (jwtToken.isEmpty || jwtToken.startsWith('local_')) return false;
    try {
      final resp = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/untangle/state'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $jwtToken',
            },
            body: jsonEncode({'snapshot': snapshot}),
          )
          .timeout(const Duration(seconds: 4));
      return resp.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ===========================================================================
  // TIER-3 $0.00 GEMINI-2.5-FLASH-LITE PROXY (~2.8s CLIENT TIMEOUT)
  // ===========================================================================
  Future<CloudAiSuggestion?> aiSuggestModels(String problem) async {
    try {
      final resp = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/untangle/ai-parse'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'problem': problem}),
          )
          .timeout(const Duration(milliseconds: 2800));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final ids = (data['modelIds'] as List?)?.map((e) => (e as num).toInt()).toList() ?? [];
        if (ids.isNotEmpty) {
          return CloudAiSuggestion(
            modelIds: ids,
            fitReason: (data['fitReason'] ?? '').toString(),
            suggestedTitle: (data['suggestedTitle'] ?? '').toString(),
            source: (data['source'] ?? 'gemini-2.5-flash-lite').toString(),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  // ===========================================================================
  // CLOSED-LOOP IN-APP BUG TRIAGE (LOCAL-FIRST + SERVER-RECONCILED)
  // ===========================================================================
  static String normalizeReporterEmail(String rawEmail) {
    final clean = rawEmail.trim().toLowerCase();
    return clean.isEmpty ? 'anonymous@tester.local' : clean;
  }

  Future<BugReportRecord> submitBugReport({
    required String description,
    required String pageContext,
    required String userEmail,
  }) async {
    final email = normalizeReporterEmail(userEmail);
    final nowIso = DateTime.now().toIso8601String();
    String? serverId = await _postBugToCloud(
      description: description,
      pageContext: pageContext,
      userEmail: email,
    );

    final record = BugReportRecord(
      id: serverId ?? 'local-${DateTime.now().microsecondsSinceEpoch}',
      description: description.trim(),
      pageContext: pageContext,
      appVersion: appVersion,
      userEmail: email,
      createdAt: nowIso,
      syncedToCloud: serverId != null,
      status: 'open',
    );

    final list = await _loadLocalBugs();
    list.insert(0, record);
    await _saveLocalBugs(list);

    if (serverId != null) {
      await _flushPendingBugs(list);
    }
    return record;
  }

  Future<String?> _postBugToCloud({
    required String description,
    required String pageContext,
    required String userEmail,
  }) async {
    try {
      final resp = await _client
          .post(
            Uri.parse('$baseUrl/api/v1/bugs'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'description': description.trim(),
              'pageContext': pageContext,
              'appVersion': appVersion,
              'userEmail': userEmail,
            }),
          )
          .timeout(const Duration(seconds: 3));
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final bug = data['bug'];
        if (bug is Map && bug['id'] != null) {
          return bug['id'].toString();
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _flushPendingBugs(List<BugReportRecord> current) async {
    bool changed = false;
    final updated = <BugReportRecord>[];
    for (final b in current) {
      if (!b.syncedToCloud && b.status != 'resolved') {
        final sid = await _postBugToCloud(
          description: b.description,
          pageContext: b.pageContext,
          userEmail: b.userEmail,
        );
        if (sid != null) {
          updated.add(BugReportRecord(
            id: sid,
            description: b.description,
            pageContext: b.pageContext,
            appVersion: b.appVersion,
            userEmail: b.userEmail,
            createdAt: b.createdAt,
            syncedToCloud: true,
            status: b.status,
          ));
          changed = true;
          continue;
        }
      }
      updated.add(b);
    }
    if (changed) await _saveLocalBugs(updated);
  }

  Future<List<BugReportRecord>> getOpenBugReportsForCurrentUser(String rawUserEmail) async {
    final ownerEmail = normalizeReporterEmail(rawUserEmail);
    final local = await _loadLocalBugs();

    try {
      final resp = await _client
          .get(Uri.parse('$baseUrl/api/v1/bugs?status=all&limit=100'))
          .timeout(const Duration(seconds: 4));
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final rows = (data['bugs'] as List?) ?? [];
        final resolvedIds = <String>{};
        final resolvedSignatures = <String>{};
        final serverOpenForUser = <BugReportRecord>[];

        for (final r in rows) {
          if (r is! Map) continue;
          final rec = BugReportRecord.fromMap(Map<String, dynamic>.from(r), defaultSynced: true);
          if (rec.status == 'resolved') {
            resolvedIds.add(rec.id);
            resolvedSignatures.add(rec.signature);
          } else if (rec.userEmail.toLowerCase().trim() == ownerEmail) {
            serverOpenForUser.add(rec);
          }
        }

        // Prune resolved entries from local storage so fixed issues never stay visible
        final prunedLocal = local
            .where((b) =>
                b.status != 'resolved' &&
                !resolvedIds.contains(b.id) &&
                !resolvedSignatures.contains(b.signature))
            .toList();
        if (prunedLocal.length != local.length) {
          await _saveLocalBugs(prunedLocal);
        }

        final seenSignatures = serverOpenForUser.map((e) => e.signature).toSet();
        final combined = <BugReportRecord>[...serverOpenForUser];
        for (final b in prunedLocal) {
          if (b.userEmail.toLowerCase().trim() == ownerEmail && seenSignatures.add(b.signature)) {
            combined.add(b);
          }
        }
        return combined;
      }
    } catch (_) {}

    // Offline fallback: strictly filter to current user's open tickets
    return local
        .where((b) => b.status != 'resolved' && b.userEmail.toLowerCase().trim() == ownerEmail)
        .toList();
  }

  Future<List<BugReportRecord>> _loadLocalBugs() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_localBugsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => BugReportRecord.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveLocalBugs(List<BugReportRecord> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localBugsKey, jsonEncode(list.map((e) => e.toMap()).toList()));
  }
}
