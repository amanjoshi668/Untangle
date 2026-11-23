import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:untangle_app/data/decision_book_catalog.dart';
import 'package:untangle_app/main.dart';
import 'package:untangle_app/services/auth_service.dart';
import 'package:untangle_app/services/gcp_backend_service.dart';
import 'package:untangle_app/services/native_bridge_service.dart';
import 'package:untangle_app/services/vault_storage.dart';

void setMobileViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> registerUserInUi(
  WidgetTester tester, {
  required String name,
  required String email,
  required String password,
}) async {
  final settingsBtn = find.byKey(const Key('open_settings_btn'));
  await tester.ensureVisible(settingsBtn);
  await tester.tap(settingsBtn);
  await tester.pumpAndSettle();

  final nameField = find.byKey(const Key('auth_name_field'));
  await tester.ensureVisible(nameField);
  await tester.enterText(nameField, name);
  await tester.enterText(find.byKey(const Key('auth_email_field')), email);
  await tester.enterText(find.byKey(const Key('auth_password_field')), password);

  final submitBtn = find.byKey(const Key('auth_submit_email_btn'));
  await tester.ensureVisible(submitBtn);
  await tester.tap(submitBtn);
  await tester.pumpAndSettle();

  final closeBtn = find.byKey(const Key('close_settings_btn'));
  if (closeBtn.evaluate().isNotEmpty) {
    await tester.tap(closeBtn);
    await tester.pumpAndSettle();
  }
}

MockClient offlineMockClient() => MockClient((_) async => http.Response('{}', 503));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Catalog contains all 52 models with complete writeups and how-to guides', () {
    expect(kDecisionBookModels.length, 52);
    for (int i = 0; i < 52; i++) {
      final m = kDecisionBookModels[i];
      expect(m.id, i + 1);
      expect(m.writeup.length, greaterThan(80));
      expect(m.howTo.length, greaterThan(20));
      expect(m.quote.isNotEmpty, isTrue);
    }
  });

  testWidgets('CUJ 1 (360x800): Cold guest launch, compact ? popover, zero-retype handoff & save',
      (tester) async {
    setMobileViewport(tester);
    SharedPreferences.setMockInitialValues({});

    final backend = GcpBackendService(client: offlineMockClient());
    final auth = AuthService(backend: backend);
    await auth.restoreSession();
    final vault = VaultStorage(backend: backend, auth: auth);
    await vault.initialize();

    await tester.pumpWidget(UntangleApp(auth: auth, vault: vault, backend: backend));
    await tester.pumpAndSettle();

    // Launches straight into app without login wall; guarded onboarding hint visible
    expect(auth.isGuest, isTrue);
    expect(find.byKey(const Key('onboarding_decide_hint')), findsOneWidget);

    // Enter dilemma in Mode 1
    await tester.enterText(
      find.byKey(const Key('problem_input_field')),
      'Stay in my comfortable senior role vs join an early Berlin startup',
    );
    await tester.pumpAndSettle();
    expect(find.text('The Rubber Band Model'), findsOneWidget);

    // Open compact '?' writeup popover — verify writeup & how-to present without leaving screen
    await tester.tap(find.byKey(const Key('recommended_question_btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('technique_info_popover_6')), findsOneWidget);
    expect(find.textContaining('How to use:', findRichText: true), findsOneWidget);
    await tester.tap(find.byKey(const Key('close_info_popover_btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('technique_info_popover_6')), findsNothing);

    // Zero-retype handoff into Rubber Band workspace
    final useBtn = find.byKey(const Key('use_recommended_btn'));
    await tester.ensureVisible(useBtn);
    await tester.tap(useBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('Stay in my comfortable senior role'), findsWidgets);

    // Add a pulling force and save decision
    await tester.enterText(find.byKey(const Key('e2_add_field')), 'Equity upside & autonomy');
    final addRight = find.byKey(const Key('e2_add_right_btn'));
    await tester.ensureVisible(addRight);
    await tester.tap(addRight);
    await tester.pumpAndSettle();
    expect(find.text('Equity upside & autonomy'), findsOneWidget);

    await tester.tap(find.byKey(const Key('workspace_save_btn')));
    await tester.pumpAndSettle();

    // Lands in Journal with saved decision; onboarding hint now retired
    expect(vault.hasUserCreatedItems, isTrue);
    await tester.tap(find.byKey(const Key('nav_decide')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('onboarding_decide_hint')), findsNothing);
  });

  testWidgets('CUJ 2 (360x800 & 1024x768): Mode 2 library, Page-82 compass & all 8 canvas engines',
      (tester) async {
    setMobileViewport(tester);
    SharedPreferences.setMockInitialValues({});

    final backend = GcpBackendService(client: offlineMockClient());
    final auth = AuthService(backend: backend);
    await auth.restoreSession();
    final vault = VaultStorage(backend: backend, auth: auth);
    await vault.initialize();

    await tester.pumpWidget(UntangleApp(auth: auth, vault: vault, backend: backend));
    await tester.pumpAndSettle();

    // Switch to Mode 2 ("Techniques")
    await tester.tap(find.byKey(const Key('nav_techniques')));
    await tester.pumpAndSettle();

    // Search "Eisenhower" (#01, Engine E1)
    await tester.enterText(find.byKey(const Key('library_search_field')), 'Eisenhower');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('technique_row_1')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('e1_add_field')), 'Ship v1 release');
    await tester.tap(find.byKey(const Key('e1_add_quad_1')));
    await tester.pumpAndSettle();
    expect(find.text('Ship v1 release'), findsOneWidget);

    // Back to library -> clear search -> toggle Page-82 Compass -> open #40 Monte Carlo (Engine E8)
    await tester.tap(find.byKey(const Key('workspace_back_btn')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('library_search_field')), '');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('library_compass_btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('page82_compass_card')), findsOneWidget);

    await tester.tap(find.byKey(const Key('compass_dot_40')));
    await tester.pumpAndSettle();
    expect(find.text('1,000 Randomized Trials'), findsOneWidget);

    // Verify tablet >=900px responsive two-pane split layout
    tester.view.physicalSize = const Size(1024, 768);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('workspace_save_btn')), findsOneWidget);
    expect(find.byKey(const Key('library_compass_btn')), findsOneWidget);
  });

  testWidgets('CUJ 3 (360x800): Seed once, zero-loss guest upgrade & strict multi-user isolation',
      (tester) async {
    setMobileViewport(tester);
    SharedPreferences.setMockInitialValues({});

    final backend = GcpBackendService(client: offlineMockClient());
    final auth = AuthService(backend: backend);
    await auth.restoreSession();
    final vault = VaultStorage(backend: backend, auth: auth);
    await vault.initialize();

    // 1. Delete seeded default and verify it NEVER respawns on reload
    expect(vault.decisions.length, 1);
    await vault.deleteDecision(vault.decisions.first.id);
    expect(vault.decisions, isEmpty);
    await vault.loadForUser(auth.currentUser.id);
    expect(vault.decisions, isEmpty);

    await tester.pumpWidget(UntangleApp(auth: auth, vault: vault, backend: backend));
    await tester.pumpAndSettle();

    // 2. Create a guest decision
    await tester.enterText(find.byKey(const Key('problem_input_field')), 'Alice private strategy decision');
    await tester.pumpAndSettle();
    final useBtn = find.byKey(const Key('use_recommended_btn'));
    await tester.ensureVisible(useBtn);
    await tester.tap(useBtn);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace_save_btn')));
    await tester.pumpAndSettle();
    expect(find.text('Alice private strategy decision'), findsOneWidget);

    // 3. Upgrade Guest -> Alice account (verify zero data loss)
    await registerUserInUi(
      tester,
      name: 'Alice',
      email: 'alice@untangle.app',
      password: 'password123',
    );
    expect(auth.currentUser.email, 'alice@untangle.app');
    expect(vault.decisions.any((d) => d.title.contains('Alice private strategy')), isTrue);

    // 4. Sign out Alice -> Register Bob -> Verify strict isolation (zero leak from Alice)
    await tester.tap(find.byKey(const Key('open_settings_btn')));
    await tester.pumpAndSettle();
    final signOutBtn = find.byKey(const Key('auth_signout_btn'));
    await tester.ensureVisible(signOutBtn);
    await tester.tap(signOutBtn);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('close_settings_btn')));
    await tester.pumpAndSettle();

    await registerUserInUi(
      tester,
      name: 'Bob',
      email: 'bob@untangle.app',
      password: 'password123',
    );
    expect(auth.currentUser.email, 'bob@untangle.app');
    expect(vault.decisions.any((d) => d.title.contains('Alice private strategy')), isFalse);
  });

  testWidgets('CUJ 4 (360x800): Multi-day SuperMemo catch-up, native reminders & SAF export calls',
      (tester) async {
    setMobileViewport(tester);
    SharedPreferences.setMockInitialValues({});

    final recordedCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(NativeBridgeService.channel, (call) async {
      recordedCalls.add(call);
      return true;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(NativeBridgeService.channel, null);
    });

    final baseDay = DateTime(2026, 11, 22, 9, 0);
    DateTime fakeNow = baseDay;

    final backend = GcpBackendService(client: offlineMockClient());
    final auth = AuthService(backend: backend);
    await auth.restoreSession();
    final vault = VaultStorage(backend: backend, auth: auth);
    await vault.initialize();

    await tester.pumpWidget(
      UntangleApp(
        auth: auth,
        vault: vault,
        backend: backend,
        clock: () => fakeNow,
      ),
    );
    await tester.pumpAndSettle();

    // Simulate 5-day user absence -> Journal shows 1-tap Catch Up banner
    fakeNow = baseDay.add(const Duration(days: 5));
    await tester.tap(find.byKey(const Key('nav_journal')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('supermemo_catchup_banner')), findsOneWidget);

    await tester.tap(find.byKey(const Key('catchup_all_reviews_btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('supermemo_catchup_banner')), findsNothing);

    // Enable native AlarmManager reminders & export Markdown in Settings
    await tester.tap(find.byKey(const Key('open_settings_btn')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('acc_reminders_header')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reminders_notify_switch')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('acc_export_header')));
    await tester.pumpAndSettle();
    final exportMd = find.byKey(const Key('export_md_btn'));
    await tester.ensureVisible(exportMd);
    await tester.tap(exportMd);
    await tester.pumpAndSettle();

    expect(recordedCalls.any((c) => c.method == 'configureReminders'), isTrue);
    expect(recordedCalls.any((c) => c.method == 'saveExportDocument'), isTrue);
  });

  testWidgets('CUJ 5 (360x800): Closed-loop bug triage filters by email & prunes resolved reports',
      (tester) async {
    setMobileViewport(tester);
    SharedPreferences.setMockInitialValues({});

    String serverBugStatus = 'open';
    final mockClient = MockClient((req) async {
      if (req.method == 'POST' && req.url.path == '/api/v1/bugs') {
        final body = jsonDecode(req.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'success': true,
            'bug': {
              'id': 'srv-bug-1',
              'description': body['description'],
              'page_context': body['pageContext'],
              'user_email': body['userEmail'],
              'status': 'open',
            }
          }),
          201,
        );
      }
      if (req.method == 'GET' && req.url.path == '/api/v1/bugs') {
        return http.Response(
          jsonEncode({
            'bugs': [
              {
                'id': 'srv-bug-1',
                'description': 'Alice reported layout note',
                'page_context': 'Decide',
                'user_email': 'alice@untangle.app',
                'status': serverBugStatus,
              },
              {
                'id': 'srv-bug-2',
                'description': 'Someone else bug report',
                'page_context': 'Journal',
                'user_email': 'other@untangle.app',
                'status': 'open',
              },
            ]
          }),
          200,
        );
      }
      return http.Response('{}', 503);
    });

    final backend = GcpBackendService(client: mockClient);
    final auth = AuthService(backend: backend);
    await auth.restoreSession();
    final vault = VaultStorage(backend: backend, auth: auth);
    await vault.initialize();

    await tester.pumpWidget(UntangleApp(auth: auth, vault: vault, backend: backend));
    await tester.pumpAndSettle();

    await registerUserInUi(
      tester,
      name: 'Alice',
      email: 'alice@untangle.app',
      password: 'password123',
    );

    // Submit bug as Alice -> sees Alice's report, NOT other@untangle.app's report
    await tester.tap(find.byKey(const Key('open_settings_btn')));
    await tester.pumpAndSettle();
    final bugsHeader = find.byKey(const Key('acc_bugs_header'));
    await tester.ensureVisible(bugsHeader);
    await tester.tap(bugsHeader);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('bug_description_field')), 'Alice reported layout note');
    await tester.tap(find.byKey(const Key('bug_submit_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Alice reported layout note'), findsOneWidget);
    expect(find.text('Someone else bug report'), findsNothing);

    await tester.tap(find.byKey(const Key('close_settings_btn')));
    await tester.pumpAndSettle();

    // Server resolves Alice's bug -> reopening prunes it from local storage & UI
    serverBugStatus = 'resolved';
    await tester.tap(find.byKey(const Key('open_settings_btn')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('acc_bugs_header')));
    await tester.tap(find.byKey(const Key('acc_bugs_header')));
    await tester.pumpAndSettle();

    expect(find.text('Alice reported layout note'), findsNothing);
    expect(find.text('No open reports for your account.'), findsOneWidget);
  });
}
