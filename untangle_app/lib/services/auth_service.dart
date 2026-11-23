import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'gcp_backend_service.dart';

class AppUser {
  final String id;
  final String name;
  final String email;
  final bool isGuest;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.isGuest,
  });

  static const AppUser guest = AppUser(
    id: 'local_guest_vault',
    name: 'Guest',
    email: '',
    isGuest: true,
  );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'email': email,
        'isGuest': isGuest,
      };

  factory AppUser.fromMap(Map<String, dynamic> m) => AppUser(
        id: (m['id'] ?? 'local_guest_vault').toString(),
        name: (m['name'] ?? 'Explorer').toString(),
        email: (m['email'] ?? '').toString(),
        isGuest: m['isGuest'] == true,
      );
}

class AuthService extends ChangeNotifier {
  static const String _sessionPrefsKey = 'untangle_active_session_v2';
  static const String _localAccountsKey = 'untangle_local_accounts_v2';

  final GcpBackendService backend;
  AppUser _currentUser = AppUser.guest;
  String _sessionToken = 'local_guest_token';

  AuthService({required this.backend});

  AppUser get currentUser => _currentUser;
  String get sessionToken => _sessionToken;
  bool get isGuest => _currentUser.isGuest;

  Future<void> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionPrefsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _currentUser = AppUser.fromMap(Map<String, dynamic>.from(data['user'] as Map));
        _sessionToken = (data['token'] ?? 'local_guest_token').toString();
        notifyListeners();
        return;
      } catch (_) {}
    }
    _currentUser = AppUser.guest;
    _sessionToken = 'local_guest_token';
    notifyListeners();
  }

  Future<String?> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = name.trim().isEmpty ? cleanEmail.split('@').first : name.trim();
    if (!cleanEmail.contains('@') || password.length < 6) {
      return 'Enter a valid email and a password of at least 6 characters.';
    }

    // Try cloud backend first; fall back seamlessly to local offline account vault if offline
    final cloud = await backend.registerEmail(name: cleanName, email: cleanEmail, password: password);
    if (cloud != null && cloud['token'] != null && cloud['user'] is Map) {
      final u = Map<String, dynamic>.from(cloud['user'] as Map);
      await _setActiveSession(
        AppUser(
          id: u['id'].toString(),
          name: (u['name'] ?? cleanName).toString(),
          email: cleanEmail,
          isGuest: false,
        ),
        cloud['token'].toString(),
      );
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final accounts = _readLocalAccounts(prefs);
    if (accounts.containsKey(cleanEmail)) {
      return 'An account with this email already exists. Sign in instead.';
    }
    final uid = 'usr_${cleanEmail.hashCode.abs()}';
    accounts[cleanEmail] = {
      'id': uid,
      'name': cleanName,
      'email': cleanEmail,
      'secret': password,
    };
    await prefs.setString(_localAccountsKey, jsonEncode(accounts));
    await _setActiveSession(
      AppUser(id: uid, name: cleanName, email: cleanEmail, isGuest: false),
      'local_jwt_$uid',
    );
    return null;
  }

  Future<String?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (!cleanEmail.contains('@') || password.isEmpty) {
      return 'Enter your email and password.';
    }

    final cloud = await backend.loginEmail(email: cleanEmail, password: password);
    if (cloud != null && cloud['token'] != null && cloud['user'] is Map) {
      final u = Map<String, dynamic>.from(cloud['user'] as Map);
      await _setActiveSession(
        AppUser(
          id: u['id'].toString(),
          name: (u['name'] ?? cleanEmail.split('@').first).toString(),
          email: cleanEmail,
          isGuest: false,
        ),
        cloud['token'].toString(),
      );
      return null;
    }

    final prefs = await SharedPreferences.getInstance();
    final accounts = _readLocalAccounts(prefs);
    final acc = accounts[cleanEmail];
    if (acc == null || acc['secret'] != password) {
      return 'Invalid email or password.';
    }
    final uid = acc['id'].toString();
    await _setActiveSession(
      AppUser(
        id: uid,
        name: (acc['name'] ?? cleanEmail.split('@').first).toString(),
        email: cleanEmail,
        isGuest: false,
      ),
      'local_jwt_$uid',
    );
    return null;
  }

  Future<String?> signInWithGoogleHandoff() async {
    final sessionId = await backend.initMobileGoogleSession();
    if (sessionId == null) {
      return 'Cloud Google Sign-In server is offline. Use Email or continue offline.';
    }
    final uri = Uri.parse('${backend.baseUrl}/auth/mobile-google?session=$sessionId');
    await launchUrl(uri, mode: LaunchMode.externalApplication);

    for (int i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      final polled = await backend.pollMobileGoogleSession(sessionId);
      if (polled != null && polled['token'] != null && polled['user'] is Map) {
        final u = Map<String, dynamic>.from(polled['user'] as Map);
        await _setActiveSession(
          AppUser(
            id: u['id'].toString(),
            name: (u['name'] ?? 'Explorer').toString(),
            email: (u['email'] ?? '').toString(),
            isGuest: false,
          ),
          polled['token'].toString(),
        );
        return null;
      }
    }
    return 'Google Sign-In timed out.';
  }

  Future<void> signOutToGuest() async {
    _currentUser = AppUser.guest;
    _sessionToken = 'local_guest_token';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionPrefsKey);
    notifyListeners();
  }

  Future<void> _setActiveSession(AppUser user, String token) async {
    _currentUser = user;
    _sessionToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionPrefsKey,
      jsonEncode({'user': user.toMap(), 'token': token}),
    );
    notifyListeners();
  }

  Map<String, dynamic> _readLocalAccounts(SharedPreferences prefs) {
    final raw = prefs.getString(_localAccountsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return {};
    }
  }
}
